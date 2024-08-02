//
//  VoiceView.swift
//  PocketGPT
//
//  Created by chongyangming on 2024/3/23.
//

import SwiftUI
import AVFoundation

// defined three modes
enum Mode {
    case Listening
    case Thinking
    case Speaking
}

struct VoiceView: View {
    @Binding var showModal: Bool
    @EnvironmentObject var aiChatModel: AIChatModel
    @State private var mode: Mode = .Listening
    @StateObject var whisperState = WhisperState()
    // Create a speech synthesizer.
    let synthesizer = AVSpeechSynthesizer()
    @State var lastUtterance = AVSpeechUtterance(string: "")
//    @Binding var speechEnded: Bool
//    var synDel: SynthesizerDelegate
    var synDel = SynthesizerDelegate()//(speechEnded: Binding.constant(false))
    @State var llamaFinished = false
    @State var messages: [Message] = []

    
    init(showModal: Binding<Bool>) {
        self._showModal = showModal
//        self._speechEnded = Binding.constant(false)
        synthesizer.delegate = synDel

//    override init() {
//        super.init()
        //SynthesizerDelegate(callback: {
        //     print("mode = Listening")
        //     self.mode = .Listening
        // })
    }

    var body: some View {
        VStack {
            Spacer()
            
            Section {
                WaveView()
                    .frame(width: 200, height: 150)
                //                    ProgressView()
                //                        .progressViewStyle(CircularProgressViewStyle())
                //                        .scaleEffect(2)
                
                if mode == .Listening {
                    Text("Listening")
//                        .offset(y:30)
                        .font(.title)
                } else if mode == .Thinking {
                    Text("Thinking")
//                        .offset(y:30)
                        .font(.title)
                } else if mode == .Speaking {
                    // a button showing "Tap to interrupt", with rounded rectangle border
                    Button(action: {
                        interrupt()
                    }) {
                        Text("Tap to interrupt")
                            .padding()
                            .font(.title)
                            .background(Color.gray)
                            .foregroundColor(.white)
                            .cornerRadius(20)
                    }
//                    .offset(y:30)

                    
                }
            }
            .onAppear {
                self.chat()
                //                tts(string:"The Speech Synthesis framework manages voice and speech synthesis, and requires two primary tasks:")
            }
            
            Spacer()

            // a round button showing "X", with red background
            Button(action: {
                interrupt()
                self.showModal = false
            }) {
                Text("X")
                    .padding()
                    .font(.title2)
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(40)
            }
        }
        // .onTapGesture {
        //     print("tapped")
        //     self.interrupt()
        // }
    }

//    init(showModal: Binding<Bool>) {
//        self._showModal = showModal
//        Task {
//            chat()
//        }
//    }

    private func chat() {
//        return
        // var synDel = SynthesizerDelegate(speechEnded: self.$speechEnded)
        // synthesizer.delegate = synDel
//        synDel.bindSpeechEnded(speechEnded: self.$speechEnded)
        synDel.setSpeechEndedCallback(callback: speechEndedCallback)
        
        AVAudioSession.sharedInstance().requestRecordPermission { [self] granted in
            if granted {
                Task {
                    var message = ""
                    while self.showModal {
                        if mode == .Listening {
                            print("[mode] =", mode)
                            message = await whisperState.getSentence()
                            mode = .Thinking
                        } else if mode == .Thinking {
                            // call llama
                            print("[mode] =", mode)
                            // await aiChatModel.getSingleAnswer(message: message, ttsEnqueue)
                            var updatedMessages = await aiChatModel.getVoiceAnswer(text_in: message, messages: self.messages, ttsEnqueue)
                            self.messages = updatedMessages
                            llamaFinished = true
                            print("[answer complete]")
                        } else if mode == .Speaking {
                            // sleep for 0.1 second
                            await Task.sleep(100_000_000) // 100ms
//                            if speechEnded {
//                                mode = .Listening
//                                speechEnded = false
//                            }
                            
                            
                            // if !synthesizer.isSpeaking {
                            //     mode = .Listening
                            // }
                        }
                    }
                }
            }
        }
    }

    private func ttsEnqueue(string: String) {
        print("[TTS enqueue]: \(string)")
        mode = .Speaking
        lastUtterance = AVSpeechUtterance(string: string)

        // Configure the utterance.
//        utterance.rate = 0.57
        lastUtterance.pitchMultiplier = 1
//        utterance.postUtteranceDelay = 0.2
        lastUtterance.volume = 3
        lastUtterance.voice = AVSpeechSynthesisVoice(language: "en-US")

        // Add to the synthesizer's queue.
        synthesizer.speak(lastUtterance)
    }

    private func interrupt() {
        print("[interrupt]")
        if mode == .Speaking {
            synthesizer.stopSpeaking(at: .immediate)
            aiChatModel.stopPredicting()
            startListening()
        }
    }

    public func speechEndedCallback(utterance: AVSpeechUtterance) {
        print("[speechEndedCallback]")
        if llamaFinished && utterance.speechString == lastUtterance.speechString {
            startListening()
        }
//        self.mode = .Listening
    }
    
    private func startListening() {
        mode = .Listening
        llamaFinished = false
    }
}

class SynthesizerDelegate: NSObject, AVSpeechSynthesizerDelegate {
//    @Binding var speechEnded: Bool
    var speechEndedCallback: ((AVSpeechUtterance) -> Void)?

//    init(speechEnded: Binding<Bool>) {
//        self._speechEnded = speechEnded
//    }
//    
//    func bindSpeechEnded(speechEnded: Binding<Bool>) {
//        self._speechEnded = speechEnded
//    }

    func setSpeechEndedCallback(callback: @escaping (AVSpeechUtterance) -> Void) {
        self.speechEndedCallback = callback
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
//        print("[SynthesizerDelegate called]")
//        speechEnded = true
        if let callback = speechEndedCallback {
            callback(utterance)
        }
    }
}

struct WaveView: View {
    var body: some View {
        TimelineView(.animation) { timeline in // Mark 1
            Canvas { context, size in // Mark 2
                let angle = Angle.degrees(timeline.date.timeIntervalSinceReferenceDate.remainder(dividingBy: 4) * 180) // Mark 3 // related to speed of movement
                let cos = (cos(angle.radians)) * 11*2 // Mark 3 // magnitude of movement
                let sin = (sin(angle.radians)) * 9*2 // Mark 3
                
                let width = size.width
                let height = size.height
                
//                context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.white)) // Mark 4
                
                let path = Path { path in // Mark 5
                    path.move(to: CGPoint(x: 0 , y: size.height/2 )) // position the line: y/2
                    
                    path.addCurve(to: CGPoint(x: width, y: size.height/2),
                                  control1: CGPoint(x: width * 0.4 , y: height * 0.2 - cos), // left high point
                                  control2: CGPoint(x: width * 0.6 , y: height * 0.8 + sin)) // right low point
                }
                
                context.stroke( // Mark 7
                    path,
                    with: .linearGradient(Gradient(colors: [.pink, .blue]),
                                          startPoint: .zero ,
                                          endPoint: CGPoint(x: size.width, y: size.height)
                                         ), lineWidth: 4
                )
            }
        }
    }
}


//#Preview {
//    VoiceView()
//}
