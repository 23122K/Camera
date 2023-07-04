//
//  AVVideoPlayerView.swift
//  SwiftUICameraView
//
//  Created by Sajjad Sarkoobi on 14.01.2023.
//

import SwiftUI
import AVKit

class CameraPreviewView: UIView {
    init() { super.init(frame: .zero) }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }
    
    var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        return layer as! AVCaptureVideoPreviewLayer
    }
    
    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        
        if nil != self.superview {
            guard let captureSession = CameraManager.shared.returnCaptureSession() else { return }
            self.videoPreviewLayer.session = captureSession
            self.videoPreviewLayer.videoGravity = .resizeAspectFill
            //Setting the videoOrientation if needed
            //self.videoPreviewLayer.connection?.videoOrientation = .landscapeRight
        } else {
            self.videoPreviewLayer.session = nil
            self.videoPreviewLayer.removeFromSuperlayer()
        }
    }
}


//Swift wrapper
struct CameraPreviewHolder: UIViewRepresentable {
    func makeUIView(context: UIViewRepresentableContext<CameraPreviewHolder>) -> CameraPreviewView { CameraPreviewView() }
    func updateUIView(_ uiView: UIViewType, context: UIViewRepresentableContext<CameraPreviewHolder>) {}
}
