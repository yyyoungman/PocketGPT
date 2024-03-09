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
    
//    @State var add_chat_dialog = false
//    @State var edit_chat_dialog = false
//    @State var current_detail_view_name:String? = "Chat"
//    @State var model_name = ""
//    @State var title = "Chat"
//    @StateObject var aiChatModel = AIChatModel()
//    @StateObject var fineTuneModel = FineTuneModel()
//    @StateObject var orientationInfo = OrientationInfo()
    @State var isLandscape:Bool = false
    @State private var chat_selection: Dictionary<String, String>? //= ["title":"Chat","icon":"", "message":"", "time": "10:30 AM","model":"","chat":""]
    @State var renew_chat_list: () -> Void = {}
    @State var tabIndex: Int = 0
    
    @State private var preferredColumn = NavigationSplitViewColumn.sidebar
    @State private var columnVisibility = NavigationSplitViewVisibility.detailOnly
    
    @State var chat_titles: [String] = ["Chat", "Image Creation"]
    @State var chat_title: String?// = "Chat"

    
//    func close_chat() -> Void{
//        aiChatModel.stop_predict()
//    }
    
    var body: some Scene {
        WindowGroup {
//            ChatView(model_name: .constant(""), chat_selection:.constant(Dictionary<String, String>()), title: .constant("Title"),close_chat: {},add_chat_dialog:.constant(false),edit_chat_dialog:.constant(false))
//                .environmentObject(aiChatModel)
            
            NavigationSplitView(/*preferredCompactColumn: $preferredColumn*/ columnVisibility:$columnVisibility)  {
                ChatListView(
//                    tabSelection: .constant(0),
//                    model_name:$model_name,
//                    title: $title,
//                    add_chat_dialog:$add_chat_dialog,
//                    close_chat:{},
//                    edit_chat_dialog:$edit_chat_dialog,
//                    chat_selection:$chat_selection
                    chat_titles:$chat_titles,
                    chat_title:$chat_title
//                    renew_chat_list: $renew_chat_list
                )
//                    .environmentObject(fineTuneModel)
                    .environmentObject(aiChatModel)
//                        .disabled(edit_chat_dialog)
                .frame(minWidth: 250, maxHeight: .infinity)
            }
            detail:{
                ChatView(
//                    model_name: $model_name,
//                    chat_selection: $chat_selection
                      chat_title:$chat_title
//                    title: $title,
//                    close_chat:{},
//                    add_chat_dialog:$add_chat_dialog,
//                    edit_chat_dialog:$edit_chat_dialog
                )
                .environmentObject(aiChatModel)
//                .environmentObject(orientationInfo)
                    .frame(maxWidth: .infinity,maxHeight: .infinity)
            }
//            .onAppear() {
//                chat_title = "Chat"
//            }
//            .navigationSplitViewStyle(.balanced)
            .background(.ultraThinMaterial)
        }
    }
}
