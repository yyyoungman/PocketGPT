import Foundation
import SwiftUI
import AVFoundation

@MainActor
class WhisperState: NSObject, ObservableObject, AVAudioRecorderDelegate {
    @Published var isModelLoaded = false
    @Published var messageLog = ""
    @Published var canTranscribe = false
    @Published var isRecording = false
    
    private var whisperContext: WhisperContext?
    private let recorder = Recorder()
    private var recordedFile: URL? = nil
    private var audioPlayer: AVAudioPlayer?
    
    private var modelUrl: URL? {
//        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("whisper").appendingPathComponent("ggml-base.en-q5_0.bin")
        Bundle.main.url(forResource: "ggml-base.en-q5_0", withExtension: "bin", subdirectory: "whisper")
    }
    
    private var sampleUrl: URL? {
        Bundle.main.url(forResource: "mm0", withExtension: "wav", subdirectory: "samples")
    }
    
    private enum LoadError: Error {
        case couldNotLocateModel
    }
    
    override init() {
        super.init()
        do {
            canTranscribe = true
        } catch {
            print(error.localizedDescription)
//            messageLog += "\(error.localizedDescription)\n"
        }
    }
    
    private func loadModel() throws {
//        messageLog += "Loading model...\n"
        if (whisperContext == nil) {
            if let modelUrl {
                whisperContext = try WhisperContext.createContext(path: modelUrl.path())
                //            messageLog += "Loaded model \(modelUrl.lastPathComponent)\n"
            } else {
                //            messageLog += "Could not locate model\n"
            }
        }
    }
    
    func transcribeSample() async {
        if let sampleUrl {
            await transcribeAudio(sampleUrl)
        } else {
//            messageLog += "Could not locate sample\n"
        }
    }
    
    private func transcribeAudio(_ url: URL) async {
        if (!canTranscribe) {
            return
        }
        guard let whisperContext else {
            return
        }
        
        do {
            canTranscribe = false
//            messageLog += "Reading wave samples...\n"
            let data = try readAudioSamples(url)
//            messageLog += "Transcribing data...\n"
            await whisperContext.fullTranscribe(samples: data)
            let text = await whisperContext.getTranscription()
//            messageLog += "Done: \(text)\n"
            messageLog = text
        } catch {
            print(error.localizedDescription)
//            messageLog += "\(error.localizedDescription)\n"
        }
        
        canTranscribe = true
    }
    
    private func readAudioSamples(_ url: URL) throws -> [Float] {
//        stopPlayback()
//        try startPlayback(url)
        return try decodeWaveFile(url)
    }
    
    func toggleRecord() async {
        if isRecording {
            await recorder.stopRecording()
            isRecording = false
            if let recordedFile {
                await transcribeAudio(recordedFile)
            }
            whisperContext = nil // release model every time to free memory (~300MB)
        } else {
            messageLog = ""
            
            requestRecordPermission { granted in
                if granted {
                    Task {
                        do {
                            self.stopPlayback()
//                            let file = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                            let file = FileManager.default.temporaryDirectory
                                .appending(path: "output.wav")
                            try await self.recorder.startRecording(toOutputFile: file, delegate: self)
                            self.isRecording = true
                            self.recordedFile = file
                        } catch {
                            print(error.localizedDescription)
//                            self.messageLog += "\(error.localizedDescription)\n"
                            self.isRecording = false
                        }
                    }
                    
                    // Load model while user is speaking
                    Task {
                        do {
                            try self.loadModel()
                        } catch {
                            print(error.localizedDescription)
                        }
                    }
                }
            }
        }
    }
    
    private func requestRecordPermission(response: @escaping (Bool) -> Void) {
#if os(macOS)
        response(true)
#else
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            response(granted)
        }
#endif
    }
    
    private func startPlayback(_ url: URL) throws {
        audioPlayer = try AVAudioPlayer(contentsOf: url)
        audioPlayer?.play()
    }
    
    private func stopPlayback() {
        audioPlayer?.stop()
        audioPlayer = nil
    }
    
    // MARK: AVAudioRecorderDelegate
    
    nonisolated func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        if let error {
            Task {
                await handleRecError(error)
            }
        }
    }
    
    private func handleRecError(_ error: Error) {
        print(error.localizedDescription)
//        messageLog += "\(error.localizedDescription)\n"
        isRecording = false
    }
    
    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        Task {
            await onDidFinishRecording()
        }
    }
    
    private func onDidFinishRecording() {
        isRecording = false
    }
}
