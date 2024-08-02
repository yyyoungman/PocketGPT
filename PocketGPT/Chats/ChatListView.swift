//
//  ChatListView.swift
//  PocketGPT
//
//

import SwiftUI



struct ChatListView: View {
    @EnvironmentObject var aiChatModel: AIChatModel
    
    @State var searchText: String = ""
    @Binding var chat_titles: [String]
    @Binding var chat_title: String?
    @State var chats_previews:[Dictionary<String, String>] = []
    @State var current_detail_view_name:String? = "Chat"
    @State private var toggleSettings = false
    @State private var toggleAddChat = false
    
    @State private var onStartup = true
    
    func get_chat_mode_list() -> [Dictionary<String, String>]?{
        var res: [Dictionary<String, String>] = []
        res.append(["title":"Chat","icon":"", "message":"", "time": "10:30 AM","model":"","chat":""])
        res.append(["title":"Image Creation","icon":"", "message":"", "time": "10:30 AM","model":"","chat":""])
        return res
    }
    
    func refresh_chat_list(){
        self.chats_previews = get_chat_mode_list()!
    }
    
    func delete(at offsets: IndexSet) {
        let chatsToDelete = offsets.map { self.chats_previews[$0] }
        _ = delete_chats(chatsToDelete)
        refresh_chat_list()
    }
    
    func delete(at elem:Dictionary<String, String>){
        _ = delete_chats([elem])
        self.chats_previews.removeAll(where: { $0 == elem })
        refresh_chat_list()
    }

    func duplicate(at elem:Dictionary<String, String>){
        _ = duplicate_chat(elem)
        refresh_chat_list()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 5){
            
            
            VStack(){
                List(chat_titles, id: \.self, selection: $chat_title){
                    title in
                    NavigationLink(value: title){
                        Text(title)
                            .listRowInsets(.init())
                    }
                }
                .frame(maxHeight: .infinity)
                #if os(macOS)
                .listStyle(.sidebar)
                #else
                .listStyle(InsetListStyle())
                #endif
            }
            .background(.opacity(0))
            
        }.task {
            refresh_chat_list()
        }
        .navigationTitle("Select Mode")
        .onAppear() {
            if onStartup {
                chat_title = "Chat"
                onStartup = false
            }
        }
    }
}
