//
//  AIChatModel.swift
//  PrivateGPT
//
//  Created by chongyangming on 2024/2/21.
//

import Foundation
import SwiftUI
import os
import CoreML

@MainActor
final class AIChatModel: ObservableObject {
    @Published var messages: [Message] = []
    @Published var AI_typing = 0

    private var llamaState = LlamaState()
    private var filename: String = "tinyllama-1.1b-1t-openorca.Q4_0.gguf"
    public var chat_name = "chat1"
    
    var sdPipeline: StableDiffusionPipelineProtocol?

    private func getFileURL(filename: String) -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(filename)
    }
    
    init() {
//        Task {
////            loadLlama()
//            loadLlava()
////            loadSD()
//        }
    }
    
    public func prepare(chat_title:String/*chat_selection: Dictionary<String, String>?*/) {
//        let new_chat_name = chat_selection!["title"] ?? "none"
        let new_chat_name = chat_title
        if new_chat_name != self.chat_name {
            self.chat_name = new_chat_name
            self.messages = []
            Task {
                self.messages = load_chat_history(self.chat_name)!
                self.AI_typing = -Int.random(in: 0..<100000)
                
                self.llamaState = LlamaState() // release old one, and create new one
                if self.sdPipeline != nil {
                    Task.detached() {
                        await self.sdPipeline?.unloadResources()
                    }
                }
                
                if self.chat_name == "Chat" {
                    loadLlava()
                } else if self.chat_name == "Image Creation" {
                    loadSD()
                }
            }
        }
    }
    
    public func loadSD() {
        Task.detached() { // load on background thread, because it takes ~10 seconds
            // TODO: add task cancellation. https://stackoverflow.com/a/71876683
            do {
//                let resourceURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("sd_turbo")
                // let resourceURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("sd_turbo_8bit")
                // get main bundle's "sd_turbo" folder url
                let resourceURL = Bundle.main.url(forResource: "sd_turbo", withExtension: nil)!
                let configuration = MLModelConfiguration()
//                configuration.computeUnits = .cpuOnly
                configuration.computeUnits = .cpuAndGPU
                let sdPipeline = try StableDiffusionPipeline(resourcesAt: resourceURL,
                                                         controlNet: [],
                                                         configuration: configuration,
                                                         disableSafety: false,
                                                         reduceMemory: true)
//                sleep(6)
                try sdPipeline.loadResources()
                print("sdPipeline loaded")
                Task { @MainActor in
                    self.sdPipeline = sdPipeline // assign to main actor's variable on main thread
                }
            } catch let err {
                print("SD loading Error: \(err.localizedDescription)")
            }
        }
    }
    
    public func loadLlava() {
        do {
            try llamaState.loadModelLlava()
        } catch let err {
            print("llava loading Error: \(err.localizedDescription)")
        }
//        self.messages = load_chat_history(self.chat_name+".json")!
//        self.AI_typing = -Int.random(in: 0..<100000)
    }
        
    public func loadLlama() {
        print("Loading model \(filename)...")
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
        
//        self.messages = load_chat_history(self.chat_name+".json")!
//        self.AI_typing = -Int.random(in: 0..<100000)
    }
    /*
     tinyllama openorca q4
     <|im_start|>system\nYou are a helpful chatbot that answers questions.<|im_end|>\n<|im_start|>user\n What is the largest animal on earth?<|im_end|>\n<|im_start|>assistant

     tinyllama q8
     <|system|>\nYou are a helpful chatbot that answers questions.</s>\n<|user|>\nWhat is the largest animal on earth?</s>\n<|assistant|>
     */
    
    private func getConversationPromptLlama(messages: [Message]) -> String
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
    
    private func getConversationPromptLlava(messages: [Message]) -> String
    {
//        let message = messages[messages.count-1]
//        return message.text
        
        // generate prompt from the last n messages
        let contextLength = 2 // # rounds
        let numChats = contextLength * 2 + 1
        var prompt = "A chat between a curious human and an artificial intelligence assistant. The assistant gives helpful, detailed, and polite answers to the human's questions.\n"
        let start = max(0, messages.count - numChats)
        for i in start..<messages.count-1 {
            let message = messages[i]
            if message.sender == .user {
                prompt += "USER: " + message.text + "\n"
            } else if message.sender == .system {
                prompt += "ASSISTANT: " + message.text + "\n"
            }
        }
        let message = messages[messages.count-1]
        if message.sender == .user {
            prompt += "USER: <image> " + message.text + "\n"
        }
        prompt += "ASSISTANT: "
        return prompt
    }
    
    private func getConversationPromptSD(messages: [Message]) -> String
    {
        let message = messages[messages.count-1]
        return message.text
    }

    public func loadLlavaImage(base64: String) {
        Task {
            await llamaState.loadLlavaImage(base64: base64)
        }
    }
    
    private func sdGen(prompt: String) async -> Image? {
        var config = StableDiffusionPipeline.Configuration(prompt: prompt)
//        config.negativePrompt = negativePrompt
        config.stepCount = 2
        config.seed = UInt32.random(in: 1...UInt32.max)
//        config.guidanceScale = guidanceScale
        // config.guidanceScale = 0.1
//        config.disableSafety = disableSafety
        config.schedulerType = .dpmSolverMultistepScheduler
        // config.schedulerType =  StableDiffusionScheduler.pndmScheduler.asStableDiffusionScheduler()
        config.useDenoisedIntermediates = true
        
        var ret: Image? = nil
        do {
            // wait for the pipeline to be loaded
            while sdPipeline == nil {
                try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                print("waiting for sd pipeline to finish loading")
            }
            let images = try sdPipeline!.generateImages(configuration: config) { progress in
                return true
            }
            let image = images.compactMap({ $0 }).first
            guard let image else {
                return nil
            }
            ret = Image(uiImage: UIImage(cgImage: image))
        } catch let err {
            print("Error: \(err.localizedDescription)")
        }
        return ret
    }
    
    public func send(message in_text: String, image: Image? = nil)  {
        let requestMessage = Message(sender: .user, state: .typed, text: in_text, tok_sec: 0, image: image)
        self.messages.append(requestMessage)
        self.AI_typing += 1  
        
        Task {
            var prompt = ""
            if self.chat_name == "Chat" {
//                let prompt = getConversationPromptLlama(messages: self.messages)
                prompt = getConversationPromptLlava(messages: self.messages)
            } else if self.chat_name == "Image Creation" {
                prompt = getConversationPromptSD(messages: self.messages)
            }
            
            var message = Message(sender: .system, text: "", tok_sec: 0)
            self.messages.append(message)
            let messageIndex = self.messages.endIndex - 1
            
            
            if self.chat_name == "Chat" {
                // 1. llama
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
                
                // 2. llava
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
            } else if self.chat_name == "Image Creation" {
                let pr = prompt
//                Task.detached() {
//                    print("start sleeping 10")
//                    sleep(10)
//                    print("end sleeping 10")
                self.AI_typing += 1
                try await Task.sleep(nanoseconds: 1_000_000_00) // wait 0.1 second for UI to update
                    let image = await self.sdGen(prompt: pr)
                message.image = image
                self.AI_typing += 1
//                    DispatchQueue.main.async {
//                        var updatedMessages = self.messages
//                        let messageIndex = self.messages.endIndex - 1
//                        var m = updatedMessages[messageIndex]
//                        m.image = image
//                        updatedMessages[messageIndex] = m
//                        self.messages = updatedMessages
//                    }
//                }
            }
            
            
            // save_chat_history(self.messages, self.chat_name)
//            let answerMessage = message
//            Task.detached() {
//                await save_chat_history([requestMessage, answerMessage], self.chat_name)
//            }
            save_chat_history([requestMessage, message], self.chat_name)

            message.state = .predicted(totalSecond:0)
            self.messages[messageIndex] = message
            llamaState.answer = ""
            self.AI_typing = 0
        }
    }
}
