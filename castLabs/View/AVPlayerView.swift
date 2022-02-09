//
//  AVPlayerView.swift
//  castLabs
//
//  Created by Taewoo Kim on 08.02.22.
//

import UIKit
import AVFoundation

class AVPlayerView: UIView {
    override class var layerClass: AnyClass {
        return AVPlayerLayer.self
    }
}
