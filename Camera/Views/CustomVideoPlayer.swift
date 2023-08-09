//
//  CustomVideoPlayer.swift
//  Camera
//
//  Created by Patryk Maciąg on 02/08/2023.
//

import SwiftUI
import AVKit

struct CustomVideoPlayer: UIViewControllerRepresentable {
    private let player: AVPlayer
    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.videoGravity = .resizeAspectFill
        controller.showsPlaybackControls = false
        player.play()
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIViewControllerType, context: Context) {}
    
    init(movie url: URL) {
        self.player = AVPlayer(url: url)
    }
}

