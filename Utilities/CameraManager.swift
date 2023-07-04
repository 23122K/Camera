//
//  Cameramanager.swift
//  Camera
//
//  Created by Patryk Maciąg on 24/06/2023.
//

import AVFoundation

public final class CameraManager {

    //Enums to better handle event that can occure during the configuration process
    private enum SessionStatus {
        case success
        case notAuthorized
        case configurationField
    }

    private var captureSessionConfigurationStatus: SessionStatus = .success
    private var cameraPosition: AVCaptureDevice.Position = .unspecified
    private var torchMode: AVCaptureDevice.TorchMode = .off
    private var flashMode: AVCaptureDevice.FlashMode = .off
    private var focusMode: AVCaptureDevice.FocusMode = .locked
    private var exposureMode: AVCaptureDevice.ExposureMode = .locked
    
    //MARK: Dependencies
    private let captureSession = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private var input: AVCaptureDeviceInput!
    
    //MARK: Dispatch queues
    private let captureSessionQueue = DispatchQueue(label: "capture.session")
    private let videoOutputQueue = DispatchQueue(label: "video.output", attributes: .initiallyInactive)
    
    private func requestCameraAuthorization() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return
        case .notDetermined:
            requestCameraAccess()
        default: // Access has been denied by user or it is restricted by parental controll
            self.captureSessionConfigurationStatus = .configurationField
        }
    }

    private func requestCameraAccess() {
        self.captureSessionQueue.suspend() //Suspending capture.session queue as it wont be used if user did not grant us camera access
        
        AVCaptureDevice.requestAccess(for: .video) { authorizationGranted in
            guard authorizationGranted else {
                self.captureSessionConfigurationStatus = .notAuthorized
                return
            }
            
            self.captureSessionQueue.resume() // capture.session queue is resumed as user granted camera access
        }
    }
    
    private func returnAvailableVideoCaptureDevices(position: AVCaptureDevice.Position) -> Array<AVCaptureDevice>? {
        guard captureSessionConfigurationStatus == .success else { return nil }
        
        let deviceDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInDualCamera, .builtInDualWideCamera, .builtInTripleCamera, .builtInUltraWideCamera, .builtInWideAngleCamera], mediaType: .video, position: position)
        
        return deviceDiscoverySession.devices
    }
    
    private func addDeviceInputToCaptureSession(device: AVCaptureDevice) {
        input = try? AVCaptureDeviceInput(device: device)
        guard let input = input else {
            captureSessionConfigurationStatus = .configurationField
            return
        }
        
        captureSession.addInput(input)
    }
    
    private func addVideoOutputToCaptureSession(output: AVCaptureOutput){
        guard captureSession.canAddOutput(output) else {
            captureSessionConfigurationStatus = .configurationField
            return
        }
        
        captureSession.addOutput(videoOutput)
    }
    
    private func configureCaptureSession() {
        guard captureSessionConfigurationStatus == .success else {
            captureSessionConfigurationStatus = .configurationField
            return
        }
        
        guard let device = returnAvailableVideoCaptureDevices(position: cameraPosition)?.first else {
            return
        }
        
        addDeviceInputToCaptureSession(device: device)
        addVideoOutputToCaptureSession(output: videoOutput)
        
        
        captureSession.beginConfiguration()
        captureSession.sessionPreset = .high
        captureSession.connections.first?.videoOrientation = .portrait
        
        captureSession.commitConfiguration()
        
    }
    
    func returnCaptureSession() -> AVCaptureSession? {
        guard captureSessionConfigurationStatus == .success else { return nil }
        
        return captureSession
    }
    
    private func startSession() {
        guard captureSessionConfigurationStatus == .success else { return }
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
    
    func toogleFlash() {
        captureSessionQueue.async {
            guard self.input.device.hasTorch else { return }
            do {
                try self.input.device.lockForConfiguration()
                if self.input.device.isTorchActive {
                    self.input.device.torchMode = .off
                } else {
                    self.input.device.torchMode = .on
                }
                self.input.device.unlockForConfiguration()
            } catch {
                print(error)
            }
        }
    }
    
    //MARK: - Functions to interact with CameraManager (Camera)
    func setZoom(){
        do {
            try input.device.lockForConfiguration()
            input.device.videoZoomFactor += 1
            print(input.device.deviceType)
            if input.device.videoZoomFactor >= input.device.maxAvailableVideoZoomFactor {
                input.device.videoZoomFactor = 1.0
            }
            
            input.device.unlockForConfiguration()
        } catch {
            print(error)
        }
    }
    
    func toogleFocus() {
        captureSessionQueue.async { [self] in
            print(input.device.focusMode.rawValue)
            do { try input.device.lockForConfiguration()
                input.device.focusMode = .autoFocus
                input.device.unlockForConfiguration()
            } catch {
                print("error")
            }
        }
    }
    
    func focus(at devicePoint: CGPoint) {
        captureSessionQueue.async { [self] in
            do { try input.device.lockForConfiguration()
                guard input.device.isFocusPointOfInterestSupported && input.device.isFocusModeSupported(focusMode) else { print("XD1"); return }
                guard input.device.isExposurePointOfInterestSupported && input.device.isExposureModeSupported(exposureMode) else { print("XD2"); return }
                
                input.device.focusPointOfInterest = devicePoint
                input.device.exposurePointOfInterest = devicePoint
                print(devicePoint)
                
                input.device.focusMode = focusMode
                input.device.exposureMode = exposureMode
                
                input.device.unlockForConfiguration()
            } catch {
                print("Could not lock device for configuration ")
            }
        }
    }
    
    
    
    func toogleCamera() {
        switch cameraPosition {
        case .front:
            self.cameraPosition = .back
            removeDeviceInputFromCaptureSession()
            
            guard let device = returnAvailableVideoCaptureDevices(position: cameraPosition)?.first else {
                return
            }
            
            addDeviceInputToCaptureSession(device: device)
        case .back, .unspecified:
            self.cameraPosition = .front
            removeDeviceInputFromCaptureSession()
            
            guard let device = returnAvailableVideoCaptureDevices(position: cameraPosition)?.first else {
                return
            }
            
            addDeviceInputToCaptureSession(device: device)
        @unknown default:
            print("Unknown capture position")
        }
    }
    
    //MARK: - Delegate to recive sample buffer
    func setVideoOutputDelegate(with delegate: AVCaptureVideoDataOutputSampleBufferDelegate) {
        videoOutput.setSampleBufferDelegate(delegate, queue: videoOutputQueue)
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
