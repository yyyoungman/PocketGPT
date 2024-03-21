//
//  MessageView.swift
//  PrivateGPT
//
//  Created by Limeng Ye on 2024/2/20.
//

import SwiftUI

struct MessageView: View {
    var message: Message

    private struct SenderView: View {
        var sender: Message.Sender
        var current_model = "PrivateGPT"
        
        var body: some View {
            switch sender {
            case .user:
                Text("You")
                    .font(.caption)
                    .foregroundColor(.accentColor)
            case .system:
                Text(current_model)
                    .font(.caption)
                    .foregroundColor(.accentColor)
            }
        }
    }

    private struct MessageContentView: View {
        var message: Message

        var body: some View {
            switch message.state {
            case .none:
                ProgressView()
            case .error:
                Text(message.text)
                    .foregroundColor(Color.red)
                    .textSelection(.enabled)
            case .typed:
                VStack(alignment: .leading) {
                    if message.header != ""{
                        Text(message.header)
                            .font(.footnote)
                            .foregroundColor(Color.gray)
                    }
                    message.image?
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 200)
                    Text(message.text)
                        .textSelection(.enabled)
                }
            case .predicting:
                HStack {
                    Text(message.text).textSelection(.enabled)
                    ProgressView()
                        .padding(.leading, 3.0)
                        .frame(maxHeight: .infinity,alignment: .bottom)
                }.textSelection(.enabled)
            case .predicted(totalSecond: let totalSecond):
                VStack(alignment: .leading) {
                    message.image?
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 200)
                    Text(message.text).textSelection(.enabled)
//                    Text(String(format: "%.2f ses, %.2f t/s", totalSecond,message.tok_sec))
//                        .font(.footnote)
//                        .foregroundColor(Color.gray)
                }.textSelection(.enabled)
            }
        }
    }
    
    private var ImageOperationView: some View {
//        var message: Message
//        var body: some View {
            VStack {
                Spacer()
                
                Button(
                    action: {
                        downloadImage()
                    },
                    label: {
                        Image(systemName: "arrow.down.circle")
                    }
                )
                .buttonStyle(.borderless)
//                Button(
//                    action: {
//                        regenerateImage()
//                    },
//                    label: {
//                        Image(systemName: "gobackward")
//                    }
//                )
//                .buttonStyle(.borderless)
//                .offset(x: 0, y: 10)

                Spacer()
            }
//        }
    }

    var body: some View {
        HStack {
            if message.sender == .user {
                Spacer()
            }

            VStack(alignment: .leading, spacing: 6.0) {
                SenderView(sender: message.sender)
                MessageContentView(message: message)
                    .padding(12.0)
                    .background(Color.secondary.opacity(0.2))
                    .cornerRadius(12.0)
            }
            
            if message.sender == .system  && message.image != nil {
                ImageOperationView
            }

            if message.sender == .system {
                Spacer()
            }
        }
    }
    
    private func downloadImage() {
        DispatchQueue.main.async {
            let uiImage = message.image!.asUIImage()
            UIImageWriteToSavedPhotosAlbum(uiImage, nil, nil, nil)
        }
    }
    
    private func regenerateImage() {
        Task {
        }
    }
}


//#Preview {
//    MessageView()
//}
