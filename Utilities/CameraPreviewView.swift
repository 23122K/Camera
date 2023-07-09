import AVFoundation
import SwiftUI

public struct CameraPreview: UIViewRepresentable {
    public class VideoPreviewView: UIView {
        public override class var layerClass: AnyClass {
            AVCaptureVideoPreviewLayer.self
        }
        
        var videoPreviewLayer: AVCaptureVideoPreviewLayer {
            return layer as! AVCaptureVideoPreviewLayer
        }
    }
    
    public let cameraManager: CameraManager
    
    private var tapIndicator: UIView?
    
    func zoomIn() {
        cameraManager.zoom(.zoomIn)
    }
    
    func zoomOut() {
        cameraManager.zoom(.zoomOut)
    }
    
    func tapToFocusAndExpose(point: CGPoint) {
        cameraManager.focusAndExposure(at: point)
        showTapIndicator(at: point)
    }
    
    public init(cameraManager: CameraManager) {
        self.cameraManager = cameraManager
    }
    
    public func makeUIView(context: Context) -> VideoPreviewView {
        let view = VideoPreviewView()
        view.backgroundColor = .black
        view.videoPreviewLayer.cornerRadius = 0
        view.videoPreviewLayer.session = cameraManager.returnCaptureSession()
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        view.videoPreviewLayer.connection?.videoOrientation = .portrait
        
        // Add pinch gesture recognizer for zooming
        let pinchGesture = UIPinchGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePinchGesture(_:)))
        view.addGestureRecognizer(pinchGesture)
        
        // Add tap gesture recognizer for tap to focus and expose
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTapGesture(_:)))
        view.addGestureRecognizer(tapGesture)
        
        return view
    }
    
    public func updateUIView(_ uiView: VideoPreviewView, context: Context) {
        
    }
    
    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    public class Coordinator: NSObject {
        let parent: CameraPreview
        
        init(_ parent: CameraPreview) {
            self.parent = parent
        }
        
        @objc func handlePinchGesture(_ gesture: UIPinchGestureRecognizer) {
            if gesture.scale < 1.0 {
                parent.zoomOut()
            } else {
                parent.zoomIn()
            }
        }
        
        @objc func handleTapGesture(_ gesture: UITapGestureRecognizer) {
            let point = gesture.location(in: gesture.view)
            parent.tapToFocusAndExpose(point: point)
        }
    }
    
    private func showTapIndicator(at point: CGPoint) {
        guard let view = UIApplication.shared.windows.first?.rootViewController?.view else {
            return
        }
        
        let indicatorSize: CGFloat = 80
        let indicatorView = UIView(frame: CGRect(x: point.x - indicatorSize/2,
                                                 y: point.y - indicatorSize/2,
                                                 width: indicatorSize,
                                                 height: indicatorSize))
        indicatorView.backgroundColor = UIColor.white
        indicatorView.layer.cornerRadius = indicatorSize/2
        indicatorView.alpha = 0
        
        view.addSubview(indicatorView)
        
        UIView.animate(withDuration: 0.3, animations: {
            indicatorView.alpha = 0.7
            indicatorView.transform = CGAffineTransform(scaleX: 1.2, y: 1.2)
        }) { (_) in
            UIView.animate(withDuration: 0.3, animations: {
                indicatorView.alpha = 0
                indicatorView.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
            }) { (_) in
                indicatorView.removeFromSuperview()
            }
        }
    }
}

extension AVCaptureVideoOrientation {
    init?(deviceOrientation: UIDeviceOrientation) {
        switch deviceOrientation {
        case .portrait: self = .portrait
        case .portraitUpsideDown: self = .portraitUpsideDown
        case .landscapeLeft: self = .landscapeRight
        case .landscapeRight: self = .landscapeLeft
        default: return nil
        }
    }
    
    init?(interfaceOrientation: UIInterfaceOrientation) {
        switch interfaceOrientation {
        case .portrait: self = .portrait
        case .portraitUpsideDown: self = .portraitUpsideDown
        case .landscapeLeft: self = .landscapeLeft
        case .landscapeRight: self = .landscapeRight
        default: return nil
        }
    }
}
