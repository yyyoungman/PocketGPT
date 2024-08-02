//
//  LibLlava.swift
//  PocketGPT
//
//

import Foundation
import llamaforked

actor LlavaContext {
    private var context: OpaquePointer
    private var mmproj_path: String
    
    init(context: OpaquePointer, mmproj_path: String) {
        self.context = context
        self.mmproj_path = mmproj_path
    }
    
    static func create_context(model_path: String, mmproj_path: String) throws -> LlavaContext {
        var llava_cli_context = llamaforked.llava_init(mmproj_path, model_path, "", 0)
        guard let llava_cli_context else {
            print("Could not load context!")
            throw LlamaError.couldNotInitializeContext
        }
        return LlavaContext(context: llava_cli_context, mmproj_path: mmproj_path)
    }
    
    func set_image(base64: String) {
        let img_prompt = "<img src=\"data:image/jpeg;base64," + base64 + "\">"
        llamaforked.load_image(self.mmproj_path, context, img_prompt)
    }
    
    func completion_init(text: String) {
        llamaforked.completion_init(context, text);
    }
    
    func completion_loop(prompt: String) -> String {
        let result = llamaforked.completion_loop(context)
        guard let result else {
            return ""
        }
        return String(cString: result)
    }
    
    func clear() {
        llamaforked.llava_free(context, false)
    }
    
    deinit {
        llamaforked.llava_free(context, true)
    }
}
