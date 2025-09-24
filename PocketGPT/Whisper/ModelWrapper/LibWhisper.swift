import Foundation

enum WhisperError: Error {
    case couldNotInitializeContext
}

// Stubbed WhisperContext to keep voice UI compiling; no-ops for chat-only mode
actor WhisperContext {
    init() {}

    func fullTranscribe(samples: [Float]) {
        // no-op
    }

    func getTranscription() -> String {
        return ""
    }

    static func createContext(path: String) throws -> WhisperContext {
        return WhisperContext()
    }

    static func vad(samples: [Float]) -> Bool {
        // treat as silence so recording stops quickly in stubs
        return true
    }
}
