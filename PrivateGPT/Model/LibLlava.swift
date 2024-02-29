//
//  LibLlava.swift
//  PrivateGPT
//
//  Created by chongyangming on 2024/2/28.
//

import Foundation
import llamaforked

actor LlavaContext {
    private var context: OpaquePointer
    
    init(context: OpaquePointer) {
        self.context = context
    }
    
    static func create_context(model_path: String, mmproj_path: String) throws -> LlavaContext {
        var llava_cli_context = llamaforked.llava_init(mmproj_path, model_path, "", 0)
        guard let llava_cli_context else {
            print("Could not load context!")
            throw LlamaError.couldNotInitializeContext
        }
        return LlavaContext(context: llava_cli_context)
    }
    
    func set_image(img_path: String) {
        llamaforked.load_image(context, img_path)
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
        llamaforked.llava_free(context)
    }
}
