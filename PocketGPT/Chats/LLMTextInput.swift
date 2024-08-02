//
//  LLMTextInput.swift
//  PocketGPT
//
//

import SwiftUI
import PhotosUI

public struct MessageInputViewHeightKey: PreferenceKey {
    /// Default height of 0.
    ///
    public static var defaultValue: CGFloat = 0
    

    
    /// Writes the received value to the `PreferenceKey`.
    public static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}


/// View modifier to write the height of a `View` to the ``MessageInputViewHeightKey`` SwiftUI `PreferenceKey`.
extension View {
    func messageInputViewHeight(_ value: CGFloat) -> some View {
        self.preference(key: MessageInputViewHeightKey.self, value: value)
    }
}

extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

public struct LLMTextInput: View {

    private let messagePlaceholder: String
    @EnvironmentObject var aiChatModel: AIChatModel
    @State public var input_text: String = ""
    @State private var messageViewHeight: CGFloat = 0

    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImage: Image?
    
//    @State private var voiceIcon: Image = Image(systemName: "mic")
//    @State private var isRecording: Bool = false
    @StateObject var whisperState = WhisperState()
    
    @State private var sendIcon = "headphones"
    @State private var showVoiceView = false
    
    
    
    public var body: some View {
        HStack(alignment: .bottom) {
            PhotosPicker(selection: $selectedItem,
                         matching: .images) {
                Image(systemName: "photo")
//                    .font(.system(size: 30))
                        .offset(x: 0, y: -10)
            }

            VStack {
                selectedImage?
                    .resizable()
                    .scaledToFit()
                    .frame(width: 60, height: 60)
                
                TextField(messagePlaceholder, text: $input_text, axis: .vertical)
                    .textFieldStyle(.plain)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background {
                        RoundedRectangle(cornerRadius: 20)
#if os(macOS)
                            .stroke(Color(NSColor.systemGray), lineWidth: 0.2)
#else
                            .stroke(Color(UIColor.systemGray2), lineWidth: 0.2)
#endif
                            .background {
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(.white.opacity(0.1))
                            }
                            .padding(.trailing, -42)
                    }
                    .lineLimit(1...5)
            }
            
            voiceButton
            
            Group {
                    sendButton
//                        .disabled(input_text.isEmpty/* && !aiChatModel.predicting*/)
            }
                .frame(minWidth: 33)
        }
            .padding(.horizontal, 16)
#if os(macOS)
            .padding(.top, 2)
#else
            .padding(.top, 6)
#endif
            .padding(.bottom, 10)
            .background(.thinMaterial)
            .background {
                GeometryReader { proxy in
                    Color.clear
                        .onAppear {
                            messageViewHeight = proxy.size.height
                        }
                        .onChange(of: input_text) { msg in
                            messageViewHeight = proxy.size.height
                        }
                }
            }
            .messageInputViewHeight(messageViewHeight)
            .onChange(of: selectedItem) {
                Task {
                    if let data = try? await selectedItem?.loadTransferable(type: Data.self) {
                        if let uiImage = UIImage(data: data) {
                            let base64 = uiImage.jpegData(compressionQuality: 1)?.base64EncodedString() ?? ""
                            selectedImage = Image(uiImage: uiImage)
                            aiChatModel.loadLlavaImage(base64: base64)
                        }
                    }
                }
            }
//            .sheet(isPresented: $showVoiceView) {
            .fullScreenCover(isPresented: $showVoiceView) {
                VoiceView(showModal: self.$showVoiceView) // present full screen modal
//                        .presentationDetents([.fraction(0.1), .large])
                .environmentObject(aiChatModel)
            }
    }
    
    private var voiceButton: some View {
        Button(
            action: {
                voiceButtonPressed()
            },
            label: {
                whisperState.isRecording ? Image(systemName: "stop.circle.fill") : Image(systemName: "mic")
            }
        )
        .buttonStyle(.borderless)
            .offset(x: 0, y: -10)
    }
    
    private func voiceButtonPressed() {
        Task {
            await whisperState.toggleRecord()
            input_text += whisperState.messageLog
        }
    }
    
    private var sendButton: some View {
        Button(
            action: {
                sendMessageButtonPressed()
                hideKeyboard()
            },
            label: {
                Label("", systemImage: input_text.isEmpty ? "headphones" : "paperplane")
//                Image(systemName: aiChatModel.action_button_icon)
////                    .accessibilityLabel(String(localized: "SEND_MESSAGE", bundle: .module))
//                    .font(.title2)
//#if os(macOS)
//                    .foregroundColor(input_text.isEmpty && !aiChatModel.predicting ? Color(.systemGray) : .accentColor)
//#else
//                    .foregroundColor(input_text.isEmpty && !aiChatModel.predicting ? Color(.systemGray5) : .accentColor)
//#endif
            }
        )
        .buttonStyle(.borderless)
            .offset(x: 15, y: -10)
    }
    
    /// - Parameters:
    ///   - chat: The chat that should be appended to.
    ///   - messagePlaceholder: Placeholder text that should be added in the input field
    public init(
//        _ chat: Binding<Chat>,
        messagePlaceholder: String? = nil
    ) {
//        self._chat = chat
        self.messagePlaceholder = messagePlaceholder ?? "Message"
    }
    
    
    private func sendMessageButtonPressed() {
        Task {
//            if (aiChatModel.predicting){
//                aiChatModel.stop_predict()
//            }else
//            {
//                Task {

            if !input_text.isEmpty {
                      /*await */aiChatModel.send(message: input_text, image: selectedImage)
                      input_text = ""
                      selectedImage = nil
//                }
//            }
            } else {
                // open a voice chat view
                showVoiceView = true
            }
        }
        
    }
    

}

#Preview {
    LLMTextInput()
}
