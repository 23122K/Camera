//
//  Cameramanager.swift
//  Camera
//
//  Created by Patryk Maciąg on 24/06/2023.
//

import AVFoundation

public final class CameraManager {
    private enum CameraPosition: Int {
        case back = 1
        case front  = 2
    }
    
    private enum SessionStatus {
        case success
        case failed
        case denied
    }
    
    private var captureSessionStatus: SessionStatus = .success
    private var cameraPosition: CameraPosition = .front
    
    
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
        default: // Access is denied by user or it is restricted by parental controll
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
    
    private func addDeviceInputToCaptureSession(camera position: CameraPosition) {
        guard let device = searchForVideoCaptureDevices()?.first(where: { $0.position.rawValue == position.rawValue }) else {
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
    
    private func configureCaptureSession() {
        guard captureSessionStatus == .success else {
            captureSessionStatus = .failed
            return
        }
        
        addDeviceInputToCaptureSession(camera: .front)
        addVideoOutputToCaptureSession()
        
        captureSession.beginConfiguration()
        captureSession.sessionPreset = .high
        
        captureSession.connections.first?.videoOrientation = .portrait
        
        captureSession.commitConfiguration()
        
    }
    
    func returnCaptureSession() -> AVCaptureSession? {
        guard captureSessionStatus == .success else { return nil }
        
        return captureSession
    }
    
    private func startSession() {
        guard captureSessionStatus == .success else { return }
        captureSession.startRunning()
    }
    
    private func removeDeviceInputFromCaptureSession(){
        captureSession.beginConfiguration()
        
        guard let input = captureSession.inputs.first else {
            return
        }
        
        captureSession.removeInput(input)
        captureSession.commitConfiguration()
    }
    
    func toogleCamera() {
        switch cameraPosition {
        case .front:
            self.cameraPosition = .back
            removeDeviceInputFromCaptureSession()
            addDeviceInputToCaptureSession(camera: cameraPosition)
        case .back:
            self.cameraPosition = .front
            removeDeviceInputFromCaptureSession()
            addDeviceInputToCaptureSession(camera: cameraPosition)
        }
    }
    
    static let shared = CameraManager()
    
    private init() {
        captureSessionQueue.async {
            self.requestCameraAuthorization()
            self.configureCaptureSession()
            self.startSession()
            
        }
    }
    
    
}
