//
//  LibLlama.swift
//  PocketGPT
//
//

import Foundation
import llama

enum LlamaError: Error {
    case couldNotInitializeContext
}

func llama_batch_clear(_ batch: inout llama_batch) {
    batch.n_tokens = 0
}

// Wrapper that calls the C API's llama_batch_add to avoid touching internals
func llama_batch_add_swift(_ batch: inout llama_batch, _ id: llama_token, _ pos: llama_pos, _ seq_ids: [llama_seq_id], _ logits: Bool) {
    let idx = Int(batch.n_tokens)
    // token
    if let tokenPtr = batch.token {
        tokenPtr[idx] = id
    }
    // pos (optional; if NULL, llama will track automatically)
    if let posPtr = batch.pos {
        posPtr[idx] = pos
    }
    // set sequence ids explicitly to 0 for single-sequence use
    if let nSeqPtr = batch.n_seq_id, let seqIdPtrs = batch.seq_id {
        nSeqPtr[idx] = max(1, Int32(seq_ids.count))
        let ptr = seqIdPtrs[idx]!
        if seq_ids.isEmpty {
            ptr[0] = 0
        } else {
            for i in 0..<seq_ids.count { ptr[i] = seq_ids[i] }
        }
    }
    // logits flag if available
    if let logitsPtr = batch.logits {
        logitsPtr[idx] = logits ? 1 : 0
    }
    batch.n_tokens += 1
}

actor LlamaContext {
    private var model: OpaquePointer
    private var context: OpaquePointer
    private var vocab: OpaquePointer
    private var sampling: UnsafeMutablePointer<llama_sampler>
    private var batch: llama_batch
    private var tokens_list: [llama_token]

    /// This variable is used to store temporarily invalid cchars
    private var temporary_invalid_cchars: [CChar]
    private var stopRequested: Bool = false

    var n_len: Int32 = 2048
    var n_cur: Int32 = 0

    var n_decode: Int32 = 0

    init(model: OpaquePointer, context: OpaquePointer) {
        self.model = model
        self.context = context
        self.tokens_list = []
        self.batch = llama_batch_init(512, 0, 1)
        self.temporary_invalid_cchars = []
        let sparams = llama_sampler_chain_default_params()
        self.sampling = llama_sampler_chain_init(sparams)
        // reasonable defaults
        llama_sampler_chain_add(self.sampling, llama_sampler_init_top_k(40))
        llama_sampler_chain_add(self.sampling, llama_sampler_init_top_p(0.9, 1))
        llama_sampler_chain_add(self.sampling, llama_sampler_init_temp(0.8))
        llama_sampler_chain_add(self.sampling, llama_sampler_init_dist(1234))
        self.vocab = llama_model_get_vocab(model)
    }

    deinit {
        llama_sampler_free(sampling)
        llama_batch_free(batch)
        llama_model_free(model)
        llama_free(context)
        llama_backend_free()
    }

    static func create_context(path: String) throws -> LlamaContext {
        llama_backend_init()
        let model_params = llama_model_default_params()

#if targetEnvironment(simulator)
        // Note: model_params is now a value type, not a reference
        // We need to create a mutable copy to modify it
        var mutable_model_params = model_params
        mutable_model_params.n_gpu_layers = 0
        print("Running on simulator, force use n_gpu_layers = 0")
        let model = llama_model_load_from_file(path, mutable_model_params)
#else
        let model = llama_model_load_from_file(path, model_params)
#endif
        
        guard let model else {
            print("Could not load model at \(path)")
            throw LlamaError.couldNotInitializeContext
        }

        let n_threads = max(1, min(8, ProcessInfo.processInfo.processorCount - 2))
        print("Using \(n_threads) threads")

        let ctx_params = llama_context_default_params()
        // Note: ctx_params is now a value type, not a reference
        // We need to create a mutable copy to modify it
        var mutable_ctx_params = ctx_params
        mutable_ctx_params.n_ctx = 4096
        mutable_ctx_params.n_threads       = Int32(n_threads)
        mutable_ctx_params.n_threads_batch = Int32(n_threads)

        let context = llama_init_from_model(model, mutable_ctx_params)
        guard let context else {
            print("Could not load context!")
            throw LlamaError.couldNotInitializeContext
        }

        return LlamaContext(model: model, context: context)
    }

    func model_info() -> String {
        let result = UnsafeMutablePointer<Int8>.allocate(capacity: 256)
        result.initialize(repeating: Int8(0), count: 256)
        defer {
            result.deallocate()
        }

        // TODO: this is probably very stupid way to get the string from C

        let nChars = llama_model_desc(model, result, 256)
        let bufferPointer = UnsafeBufferPointer(start: result, count: Int(nChars))

        var SwiftString = ""
        for char in bufferPointer {
            SwiftString.append(Character(UnicodeScalar(UInt8(char))))
        }

        return SwiftString
    }

    func get_n_tokens() -> Int32 {
        return batch.n_tokens;
    }

    func completion_init(text: String) {
        print("attempting to complete \"\(text)\"")

        tokens_list = tokenize(text: text, add_bos: true)
        temporary_invalid_cchars = []
        stopRequested = false

        let n_ctx = llama_n_ctx(context)
        // Clamp generation to fit available KV cache: prompt tokens + gen tokens <= n_ctx
        let available = max(0, Int(n_ctx) - tokens_list.count)
        if available <= 0 {
            print("warning: no KV space left; clamping generation to 1 token")
            n_len = 1
        } else if Int(n_len) > available {
            print("info: clamping n_len from \(n_len) to available \(available) for KV cache")
            n_len = Int32(available)
        }
        let n_kv_req = tokens_list.count + Int(n_len)

        print("\n n_len = \(n_len), n_ctx = \(n_ctx), n_kv_req = \(n_kv_req)")

        if n_kv_req > n_ctx {
            print("error: n_kv_req > n_ctx, the required KV cache size is not big enough")
        }

        for id in tokens_list {
            print(String(cString: token_to_piece(token: id) + [0]))
        }

        // ensure batch capacity is sufficient for the entire prompt
        if tokens_list.count > 0 {
            llama_batch_free(batch)
            batch = llama_batch_init(Int32(tokens_list.count), 0, 1)
        } else {
            llama_batch_clear(&batch)
        }

        for i1 in 0..<tokens_list.count {
            let i = Int(i1)
            llama_batch_add_swift(&batch, tokens_list[i], Int32(i), [0], false)
        }
        batch.logits[Int(batch.n_tokens) - 1] = 1 // true

        if llama_decode(context, batch) != 0 {
            print("llama_decode() failed")
        }

        n_cur = batch.n_tokens
    }

    func completion_loop() -> String {
        let new_token_id = llama_sampler_sample(sampling, context, batch.n_tokens - 1)

        if llama_vocab_is_eog(vocab, new_token_id) || n_cur == n_len {
            print("\n[DEBUG] Stopping generation: EOG=\(llama_vocab_is_eog(vocab, new_token_id)), n_cur=\(n_cur), n_len=\(n_len)")
            let new_token_str = String(cString: temporary_invalid_cchars + [0])
            temporary_invalid_cchars.removeAll()
            stopRequested = true
            return new_token_str
        }

        let new_token_cchars = token_to_piece(token: new_token_id)
        temporary_invalid_cchars.append(contentsOf: new_token_cchars)

        // Emit only the longest valid UTF-8 prefix; keep incomplete bytes buffered to avoid replacement chars
        let bytes = temporary_invalid_cchars.map { UInt8(bitPattern: $0) }
        var emitCount = bytes.count
        var emitted = ""
        while emitCount > 0 {
            if let s = String(bytes: bytes.prefix(emitCount), encoding: .utf8) {
                emitted = s
                // remove consumed bytes from buffer
                temporary_invalid_cchars.removeFirst(emitCount)
                break
            }
            emitCount -= 1
        }

        // If nothing decodable yet, proceed with model step but emit nothing this round
        // (caller should continue on empty chunks)
        // Also strip ChatML closing tag if present in the emitted chunk
        if let range = emitted.range(of: "<|im_end|>") {
            emitted = String(emitted[..<range.lowerBound])
            stopRequested = true
        }
        
        if !emitted.isEmpty {
            print(emitted)
        }

        llama_batch_clear(&batch)
        llama_batch_add_swift(&batch, new_token_id, n_cur, [0], true)

        n_decode += 1
        n_cur    += 1

        if llama_decode(context, batch) != 0 {
            print("failed to evaluate llama!")
        }

        return emitted
    }

    func should_stop() -> Bool { stopRequested }

    func bench(pp: Int, tg: Int, pl: Int, nr: Int = 1) -> String {
        var pp_avg: Double = 0
        var tg_avg: Double = 0

        var pp_std: Double = 0
        var tg_std: Double = 0

        for _ in 0..<nr {
            // bench prompt processing

            llama_batch_clear(&batch)

            let n_tokens = pp

            for i in 0..<n_tokens {
                llama_batch_add_swift(&batch, 0, Int32(i), [0], false)
            }
            batch.logits[Int(batch.n_tokens) - 1] = 1 // true

            llama_memory_clear(llama_get_memory(context), false)

            let t_pp_start = llama_time_us()

            if llama_decode(context, batch) != 0 {
                print("llama_decode() failed during prompt")
            }

            let t_pp_end = llama_time_us()

            // bench text generation

            llama_memory_clear(llama_get_memory(context), false)

            let t_tg_start = llama_time_us()

            for i in 0..<tg {
                llama_batch_clear(&batch)

                for j in 0..<pl {
                    llama_batch_add_swift(&batch, 0, Int32(i), [Int32(j)], true)
                }

                if llama_decode(context, batch) != 0 {
                    print("llama_decode() failed during text generation")
                }
            }

            let t_tg_end = llama_time_us()

            llama_memory_clear(llama_get_memory(context), true)

            let t_pp = Double(t_pp_end - t_pp_start) / 1000000.0
            let t_tg = Double(t_tg_end - t_tg_start) / 1000000.0

            let speed_pp = Double(pp)    / t_pp
            let speed_tg = Double(pl*tg) / t_tg

            pp_avg += speed_pp
            tg_avg += speed_tg

            pp_std += speed_pp * speed_pp
            tg_std += speed_tg * speed_tg

            print("pp \(speed_pp) t/s, tg \(speed_tg) t/s")
        }

        pp_avg /= Double(nr)
        tg_avg /= Double(nr)

        if nr > 1 {
            pp_std = sqrt(pp_std / Double(nr - 1) - pp_avg * pp_avg * Double(nr) / Double(nr - 1))
            tg_std = sqrt(tg_std / Double(nr - 1) - tg_avg * tg_avg * Double(nr) / Double(nr - 1))
        } else {
            pp_std = 0
            tg_std = 0
        }

        let model_desc     = model_info();
        let model_size     = String(format: "%.2f GiB", Double(llama_model_size(model)) / 1024.0 / 1024.0 / 1024.0);
        let model_n_params = String(format: "%.2f B", Double(llama_model_n_params(model)) / 1e9);
        let backend        = "Metal";
        let pp_avg_str     = String(format: "%.2f", pp_avg);
        let tg_avg_str     = String(format: "%.2f", tg_avg);
        let pp_std_str     = String(format: "%.2f", pp_std);
        let tg_std_str     = String(format: "%.2f", tg_std);

        var result = ""

        result += String("| model | size | params | backend | test | t/s |\n")
        result += String("| --- | --- | --- | --- | --- | --- |\n")
        result += String("| \(model_desc) | \(model_size) | \(model_n_params) | \(backend) | pp \(pp) | \(pp_avg_str) ± \(pp_std_str) |\n")
        result += String("| \(model_desc) | \(model_size) | \(model_n_params) | \(backend) | tg \(tg) | \(tg_avg_str) ± \(tg_std_str) |\n")

        return result;
    }

    func clear() {
        tokens_list.removeAll()
        temporary_invalid_cchars.removeAll()
        llama_memory_clear(llama_get_memory(context), true)
    }

    private func tokenize(text: String, add_bos: Bool) -> [llama_token] {
        let utf8Count = text.utf8.count
        let n_tokens = utf8Count + (add_bos ? 1 : 0)
        let tokens = UnsafeMutablePointer<llama_token>.allocate(capacity: n_tokens)
        let tokenCount = llama_tokenize(vocab, text, Int32(utf8Count), tokens, Int32(n_tokens), add_bos, false)

        var swiftTokens: [llama_token] = []
        for i in 0..<tokenCount {
            swiftTokens.append(tokens[Int(i)])
        }

        tokens.deallocate()

        return swiftTokens
    }

    /// - note: The result does not contain null-terminator
    private func token_to_piece(token: llama_token) -> [CChar] {
        let initialCapacity = 8
        var result = [CChar](repeating: 0, count: initialCapacity)
        let nTokens = llama_token_to_piece(vocab, token, &result, Int32(result.count), 0, false)

        if nTokens < 0 {
            let actualCount = Int(-nTokens)
            result = [CChar](repeating: 0, count: actualCount)
            let check = llama_token_to_piece(vocab, token, &result, Int32(result.count), 0, false)
            assert(check == nTokens * -1)
        } else {
            result.removeLast(result.count - Int(nTokens))
        }
        return result
    }
}
