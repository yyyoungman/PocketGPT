//
//  AIChatModel.swift
//  PrivateGPT
//
//  Created by chongyangming on 2024/2/21.
//

import Foundation
import SwiftUI
import os

@MainActor
final class AIChatModel: ObservableObject {
    @Published var messages: [Message] = []
    private var llamaState = LlamaState()
    private var filename: String = "tinyllama-1.1b-1t-openorca.Q4_0.gguf"

    private func getFileURL(filename: String) -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(filename)
    }
    
    init() {
        Task {
            print("Loading model \(filename)...")
            load()
        }
    }
    
    public func load() {
        let fileURL = getFileURL(filename: filename)
        if !FileManager.default.fileExists(atPath: fileURL.path) {
            print("Error: \(fileURL.path) does not exist!")
            return
        }
        do {
            try llamaState.loadModel(modelUrl: fileURL)
            print("model loaded from \(fileURL.path)")
        } catch let err {
            print("Error: \(err.localizedDescription)")
        }
    }
    /*
     tinyllama openorca q4
     <|im_start|>system\nYou are a helpful chatbot that answers questions.<|im_end|>\n<|im_start|>user\n What is the largest animal on earth?<|im_end|>\n<|im_start|>assistant

     tinyllama q8
     <|system|>\nYou are a helpful chatbot that answers questions.</s>\n<|user|>\nWhat is the largest animal on earth?</s>\n<|assistant|>
     */
    
    public func send(message in_text: String)  {
        Task {
            var message = Message(sender: .system, text: "", tok_sec: 0)
            self.messages.append(message)
            let messageIndex = self.messages.endIndex - 1
            
            let prompt = "<|im_start|>system\nYou are a helpful chatbot that answers questions.<|im_end|>\n<|im_start|>user\n" + in_text + "<|im_end|>\n<|im_start|>assistant\n"
            await llamaState.complete(
                text: prompt,
                { str in
                    message.state = .predicting
                    message.text += str
                    
                    var updatedMessages = self.messages
                    updatedMessages[messageIndex] = message
                    self.messages = updatedMessages
//                    self.messages[messageIndex] = message
                }
            )
            
//            var answer = llamaState.answer
//            if answer.hasPrefix(": ") {
//                answer = String(answer.dropFirst(2))
//            }
//            let resultMessage = Message(sender: .system, state: .predicted(totalSecond:1), text: answer, tok_sec: 0)
//            self.messages.append(resultMessage)
            message.state = .predicted(totalSecond:0)
            self.messages[messageIndex] = message
            llamaState.answer = ""
        }
        
        let requestMessage = Message(sender: .user, state: .typed, text: in_text, tok_sec: 0)
        self.messages.append(requestMessage)
    }
}
