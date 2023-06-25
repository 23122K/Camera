//
//  Cameramanager.swift
//  Camera
//
//  Created by Patryk Maciąg on 24/06/2023.
//

import AVFoundation

public final class CameraManager {
    private enum SessionStatus {
        case success
        case failed
        case denied
    }
    
    private var captureSessionStatus: SessionStatus = .success
    
    //MARK: Dependencies
    private let captureSession = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    
    //MARK: Dispatch queues
    
    private let captureSessionQueue = DispatchQueue(label: "capture.session")
    private let videoOutputQueue = DispatchQueue(label: "video.output", attributes: .initiallyInactive)
    
    private func requestCameraAuthorization() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
           return
        case .notDetermined:
            requestCameraAccess()
        default: // Access is denied by user or is restricted by parental controll
            self.captureSessionStatus = .denied
        }
    }
    
    private func requestCameraAccess() {
        self.captureSessionQueue.suspend() //Suspending capture.session queue as it wont be used if user did not grant us camera access
        
        AVCaptureDevice.requestAccess(for: .video) { granted in
            guard granted else {
                self.captureSessionStatus = .denied
                return
            }
            
            self.captureSessionQueue.resume() // capture.session queue is resumed as user granted camera access
        }
    }
    
    private func searchForVideoCaptureDevices() -> Array<AVCaptureDevice>? {
        guard captureSessionStatus == .success else { return nil }
        
        let deviceDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInDualCamera, .builtInDualWideCamera, .builtInTripleCamera, .builtInUltraWideCamera, .builtInWideAngleCamera], mediaType: .video, position: .unspecified)
        
        
        return deviceDiscoverySession.devices
    }
    
    private func addDeviceInputToCaptureSession() {
        guard let device = searchForVideoCaptureDevices()?.first(where: { $0.position.rawValue == 1 }) else {
            captureSessionStatus = .failed
            return
        }
        
        let deviceInput = try? AVCaptureDeviceInput(device: device)
        guard let input = deviceInput else {
            captureSessionStatus = .failed
            return
        }
        
        captureSession.addInput(input)
    }
    
    private func addVideoOutputToCaptureSession() {
        guard captureSession.canAddOutput(videoOutput) else {
            captureSessionStatus = .failed
            return
        }
        
        captureSession.addOutput(videoOutput)
    }
    
    func setSampleBufferDelegate(sampleBufferDelegate: AVCaptureVideoDataOutputSampleBufferDelegate, queue: DispatchQueue) {
        videoOutput.setSampleBufferDelegate(sampleBufferDelegate, queue: queue)
    }
    
    private func configureCaptureSession() {
        guard captureSessionStatus == .success else {
            captureSessionStatus = .failed
            return
        }
        
        addDeviceInputToCaptureSession()
        addVideoOutputToCaptureSession()
        
        captureSession.beginConfiguration()
        captureSession.sessionPreset = .iFrame1280x720
        
        captureSession.connections.first?.videoOrientation = .portrait
        
        captureSession.commitConfiguration()
        
    }
    
    private func startSession() {
        guard captureSessionStatus == .success else { return }
        captureSession.startRunning()
    }
    
    init() {
        captureSessionQueue.async {
            self.requestCameraAuthorization()
            self.configureCaptureSession()
            self.startSession()
            
        }
    }
    
    
}
