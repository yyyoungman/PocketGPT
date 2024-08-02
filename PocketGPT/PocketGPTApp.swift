//
//  PocketGPTApp.swift
//  PocketGPT
//
//

import SwiftUI
import StoreKit

let udkey_activeCount = "activeCount"

@main
struct PocketGPTApp: App {
    @StateObject var aiChatModel = AIChatModel()
   
    @State var isLandscape:Bool = false
    @State private var chat_selection: Dictionary<String, String>? //= ["title":"Chat","icon":"", "message":"", "time": "10:30 AM","model":"","chat":""]
    @State var renew_chat_list: () -> Void = {}
    @State var tabIndex: Int = 0
    
    @State private var columnVisibility = NavigationSplitViewVisibility.detailOnly
    
    @State var chat_titles: [String] = ["Chat", "Image Creation"]
    @State var chat_title: String?// = "Chat"

    @Environment(\.scenePhase) var scenePhase

    
    
    var body: some Scene {
        WindowGroup {

            
            NavigationSplitView(columnVisibility:$columnVisibility)  {
                ChatListView(
                    chat_titles:$chat_titles,
                    chat_title:$chat_title
                )
                    .environmentObject(aiChatModel)
                .frame(minWidth: 250, maxHeight: .infinity)
            }
            detail:{
                ChatView(
                      chat_title:$chat_title
                )
                .environmentObject(aiChatModel)
                    .frame(maxWidth: .infinity,maxHeight: .infinity)
            }
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
                }
            }
        }
    }
}
