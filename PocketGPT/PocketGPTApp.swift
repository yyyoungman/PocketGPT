//
//  PocketGPTApp.swift
//  PocketGPT
//
//  Created by Limeng Ye on 2024/2/20.
//

import SwiftUI
import StoreKit

let udkey_activeCount = "activeCount"

@main
struct PocketGPTApp: App {
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
    
//    @State private var preferredColumn = NavigationSplitViewColumn.sidebar
    @State private var columnVisibility = NavigationSplitViewVisibility.detailOnly
    
    @State var chat_titles: [String] = ["Chat", "Image Creation"]
    @State var chat_title: String?// = "Chat"

    @Environment(\.scenePhase) var scenePhase

    
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
//                print("app appeared")
//            }
//            .navigationSplitViewStyle(.balanced)
            .background(.ultraThinMaterial)
            .onChange(of: scenePhase) { oldPhase, newPhase in
                if newPhase == .active {
                    // get activeCount from UserDefaults, if not exist, set to 0
                    var activeCount = UserDefaults.standard.integer(forKey: udkey_activeCount)
                    activeCount += 1
                    UserDefaults.standard.set(activeCount, forKey: udkey_activeCount)
                    print("activeCount: \(activeCount)")
                    if activeCount == 15 {
                        // show review request when the user opens the app 15 times
                        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                            SKStoreReviewController.requestReview(in: windowScene)
//                            UserDefaults.standard.set(0, forKey: udkey_activeCount)
                        }
                    }
                } /*else if newPhase == .inactive {
                    print("Inactive")
                } else if newPhase == .background {
                    print("Background")
                }*/
            }
        }
    }
}
