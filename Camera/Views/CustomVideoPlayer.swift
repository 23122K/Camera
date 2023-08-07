//
//  CustomVideoPlayer.swift
//  Camera
//
//  Created by Patryk Maciąg on 02/08/2023.
//

import SwiftUI
import AVKit

struct CustomVideoPlayer: UIViewControllerRepresentable {
    let player: AVPlayer
    
    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = false
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIViewControllerType, context: Context) {}
}

struct CapturedResourcePreview: View {
    let cameraManagerViewModel: CameraManagerViewModel
    
    var body: some View {
        switch cameraManagerViewModel.currentCaptureMode {
        case .photo:
            Image(uiImage: UIImage(data: CameraManager.shared.capturedPhotoData!)!)
                .resizable()
                .scaledToFit()
        case .video:
            let player = AVPlayer(url: CameraManager.shared.capturedVideoURL!)
            CustomVideoPlayer(player: player)
                .onAppear { player.play() }
        }
    }
}
