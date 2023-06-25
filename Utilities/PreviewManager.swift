import AVFoundation
import CoreImage


class PreviewManager: NSObject, ObservableObject {
    @Published var image: CGImage?
    private var camera: CameraManager
    private let context = CIContext()
    
    
    override init() {
        self.camera = CameraManager()
        super.init()
        self.camera.setSampleBufferDelegate(sampleBufferDelegate: self, queue: DispatchQueue(label: "buffer.delegate"))
    }
    
}

extension PreviewManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let cgImage = imageFromSampleBuffer(sampleBuffer: sampleBuffer) else { return }
        
        // All UI updates should be/ must be performed on the main queue.
        DispatchQueue.main.async { [unowned self] in
            self.image = cgImage
        }
    }
    
    private func imageFromSampleBuffer(sampleBuffer: CMSampleBuffer) -> CGImage? {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return nil }
        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return nil }
        
        return cgImage
    }
    
}
