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
    @Published var AI_typing = 0

    private var llamaState = LlamaState()
    private var filename: String = "tinyllama-1.1b-1t-openorca.Q4_0.gguf"
    public var chat_name = "chat1"

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
        do {
            try llamaState.loadModelLlava()
        } catch let err {
            print("llava loading Error")
        }
        return
        
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
        
        self.messages = load_chat_history(self.chat_name+".json")!
        self.AI_typing = -Int.random(in: 0..<100000)
    }
    /*
     tinyllama openorca q4
     <|im_start|>system\nYou are a helpful chatbot that answers questions.<|im_end|>\n<|im_start|>user\n What is the largest animal on earth?<|im_end|>\n<|im_start|>assistant

     tinyllama q8
     <|system|>\nYou are a helpful chatbot that answers questions.</s>\n<|user|>\nWhat is the largest animal on earth?</s>\n<|assistant|>
     */
    
    private func getConversationPrompt(messages: [Message]) -> String
    {
        // generate prompt from the last n messages
        let contextLength = 2
        let numChats = contextLength * 2 + 1
        var prompt = "<|im_start|>system\nThe following is a friendly conversation between a human and an AI. You are a helpful chatbot that answers questions. Chat history:\n"
        let start = max(0, messages.count - numChats)
        for i in start..<messages.count-1 {
            let message = messages[i]
            if message.sender == .user {
                prompt += "user: " + message.text + "\n"
            } else if message.sender == .system {
                prompt += "assistant:" + message.text + "\n"
            }
        }
        prompt += "<|im_end|>\n"
        let message = messages[messages.count-1]
        if message.sender == .user {
            prompt += "<|im_start|>user\n" + message.text + "<|im_end|>\n"
        }
        prompt += "<|im_start|>assistant\n"
        return prompt
    }
    
    public func send(message in_text: String)  {
        let requestMessage = Message(sender: .user, state: .typed, text: in_text, tok_sec: 0)
        self.messages.append(requestMessage)
        self.AI_typing += 1  
        
        Task {
            let prompt = getConversationPrompt(messages: self.messages)
            
            var message = Message(sender: .system, text: "", tok_sec: 0)
            self.messages.append(message)
            let messageIndex = self.messages.endIndex - 1
            
            await llamaState.loadLlavaImage()
            await llamaState.completeLlava(
                text: prompt,
                { str in
                    message.state = .predicting
                    message.text += str
                    
                    var updatedMessages = self.messages
                    updatedMessages[messageIndex] = message
                    self.messages = updatedMessages
                    self.AI_typing += 1
                }
            )
            
//            await llamaState.complete(
//                text: prompt,
//                { str in
//                    message.state = .predicting
//                    message.text += str
//                    
//                    var updatedMessages = self.messages
//                    updatedMessages[messageIndex] = message
//                    self.messages = updatedMessages
//                    self.AI_typing += 1
//                }
//            )
//            save_chat_history(self.messages, self.chat_name+".json")
            
            message.state = .predicted(totalSecond:0)
            self.messages[messageIndex] = message
            llamaState.answer = ""
            self.AI_typing = 0
        }
    }
}
