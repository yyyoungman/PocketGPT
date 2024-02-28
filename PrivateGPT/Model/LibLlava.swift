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
    private var llava_image_embed: OpaquePointer
    
    init(context: OpaquePointer) {
        self.context = context
        self.llava_image_embed = context
    }
    
    static func create_context(model_path: String, mmproj_path: String) throws -> LlavaContext {
        var llava_context = llava_init(mmproj_path, model_path, "", 0)
        guard let llava_context else {
            print("Could not load context!")
            throw LlamaError.couldNotInitializeContext
        }
        return LlavaContext(context: llava_context)
    }
    
    func set_image(img_path: String) {
        llava_image_embed = load_image(context, img_path)
    }
    
    func completion_loop(prompt: String) -> String {
        process_prompt(context, llava_image_embed, prompt)
        llava_free(context, llava_image_embed)
        return "finished"
    }
        
}
