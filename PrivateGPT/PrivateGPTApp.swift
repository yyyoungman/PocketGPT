//
//  PrivateGPTApp.swift
//  PrivateGPT
//
//  Created by Limeng Ye on 2024/2/20.
//

import SwiftUI

@main
struct PrivateGPTApp: App {
    @StateObject var aiChatModel = AIChatModel()
    
    var body: some Scene {
        WindowGroup {
            ChatView(model_name: .constant(""), chat_selection:.constant(Dictionary<String, String>()), title: .constant("Title"),close_chat: {},add_chat_dialog:.constant(false),edit_chat_dialog:.constant(false))
                .environmentObject(aiChatModel)
        }
    }
}
