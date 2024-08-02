//
//  Message.swift
//  PocketGPT
//
//  Created by Limeng Ye on 2024/2/20.
//

import SwiftUI

struct Message: Identifiable {
    enum State: Equatable {
        case none
        case error
        case typed
        case predicting
        case predicted(totalSecond: Double)
    }

    enum Sender {
        case user
        case system
    }

    var id = UUID()
    var sender: Sender
    var state: State = .none
    var text: String
    var tok_sec: Double
    var header: String = ""
    var image: Image?
}
