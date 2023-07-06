//
//  Cameramanager.swift
//  Camera
//
//  Created by Patryk Maciąg on 24/06/2023.
//

import AVFoundation
import Photos
import SwiftUI

public final class CameraManager: NSObject {
    
    //Enums to better handle event that can occure during the configuration process
    private enum SessionStatus {
        case success
        case notAuthorized
        case configurationField
    }
    
    private enum CaptureMode: Int8 {
        case photo = 0
        case video = 1
    }
    
    @Published public var isPhotoLibraryAccessGranted = true
    @Published public var isMicrophoneAccessGranted = true
    @Published public var isCameraAccesGranted = true
    
    private var captureSessionConfigurationStatus: SessionStatus = .success
    private var captureMode: CaptureMode = .photo
    
    private var cameraPosition: AVCaptureDevice.Position = .unspecified
    private var exposureMode: AVCaptureDevice.ExposureMode = .continuousAutoExposure
    private var focusMode: AVCaptureDevice.FocusMode = .continuousAutoFocus
    private var torchMode: AVCaptureDevice.TorchMode = .off
    private var flashMode: AVCaptureDevice.FlashMode = .off
    
    //MARK: Dependencies
    private let captureSession = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private let videoOutput = AVCaptureMovieFileOutput()
    private let videoDataOutput = AVCaptureVideoDataOutput()
    
    private var videoInput: AVCaptureDeviceInput!
    private var audioInput: AVCaptureDeviceInput!
    
    //MARK: Dispatch queues
    private let captureSessionQueue = DispatchQueue(label: "capture.session")
    private let outputQueue = DispatchQueue(label: "output")
    
    //MARK: Microphone access authorization
    private func requestMicrophoneAuthorization() {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return
        case .notDetermined:
            requestMicrophoneAccess()
        default :
            isMicrophoneAccessGranted = false
            self.captureSessionConfigurationStatus = .configurationField
            //Should promt user a notification that it is rquierd with deep link into settings
        }
    }
    
    private func requestMicrophoneAccess() {
        AVCaptureDevice.requestAccess(for: .audio) { accesGranted in
            guard accesGranted else {
                self.isMicrophoneAccessGranted = false
                self.captureSessionConfigurationStatus = .notAuthorized
                return
            }
            
            self.isMicrophoneAccessGranted = true
        }
    }
    
    //MARK: Camera access authorization
    private func requestCameraAuthorization() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return
        case .notDetermined:
            requestCameraAccess()
        default: // Access has been denied by user or it is restricted by parental controll
            isCameraAccesGranted = false
            self.captureSessionConfigurationStatus = .configurationField
        }
    }
    
    private func requestCameraAccess() {
        self.captureSessionQueue.suspend() //Suspending capture.session queue as it wont be used if user did not grant us camera access
        
        AVCaptureDevice.requestAccess(for: .video) { accessGranted in
            guard accessGranted else {
                self.isCameraAccesGranted = false
                self.captureSessionConfigurationStatus = .notAuthorized
                return
            }
            
            self.isCameraAccesGranted = true
            self.captureSessionQueue.resume() // capture.session queue is resumed as user granted camera access
        }
    }
    
    //MARK: User album access authorization
    private func requestPhotoLibraryAuthorization() {
        switch PHPhotoLibrary.authorizationStatus(for: .addOnly) {
        case .authorized:
            return
        case .notDetermined:
            requestPhotoLibraryAccess()
        default:
            isPhotoLibraryAccessGranted = false
            captureSessionConfigurationStatus = .notAuthorized
        }
    }
    
    private func requestPhotoLibraryAccess() {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { accessGranted in
            guard accessGranted == .authorized else {
                self.isPhotoLibraryAccessGranted = false
                self.captureSessionConfigurationStatus = .notAuthorized
                return
            }
            
            self.isPhotoLibraryAccessGranted = true
        }
    }
    
    //MARK: - Input devices available on user device
    private func returnAvailableVideoCaptureDevices(position: AVCaptureDevice.Position) -> Array<AVCaptureDevice>? {
        guard captureSessionConfigurationStatus == .success else { return nil }
        
        let deviceDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInDualCamera, .builtInDualWideCamera, .builtInTripleCamera, .builtInUltraWideCamera, .builtInWideAngleCamera], mediaType: .video, position: position)
        
        return deviceDiscoverySession.devices
    }
    
    private func returnAvailableAudioCaptureDevices(position: AVCaptureDevice.Position) -> Array<AVCaptureDevice>? {
        guard captureSessionConfigurationStatus == .success else { return nil }
        
        let deviceDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInMicrophone], mediaType: .audio, position: .unspecified)
        
        return deviceDiscoverySession.devices
    }
    
    //MARK: - Input devices
    private func addVideoInputDeviceToCaptureSession(device: AVCaptureDevice) {
        videoInput = try? AVCaptureDeviceInput(device: device)
        guard let videoInput = videoInput else {
            captureSessionConfigurationStatus = .configurationField
            return
        }
        
        print(videoInput.device.deviceType)
        captureSession.addInput(videoInput)
    }
    
    private func addAudioInputDeviceToCaptureSession(device: AVCaptureDevice) {
        audioInput = try? AVCaptureDeviceInput(device: device)
        guard let input = audioInput else {
            captureSessionConfigurationStatus = .configurationField
            return
        }
        
        captureSession.addInput(input)
    }
    
    private func removeDeviceInputFromCaptureSession(input: AVCaptureDeviceInput) {
        captureSession.beginConfiguration()
        captureSession.removeInput(input)
        captureSession.commitConfiguration()
    }
    
    //MARK: - Output
    private func addOutputToCaptureSession(output: AVCaptureOutput){
        guard captureSession.canAddOutput(output) else {
            captureSessionConfigurationStatus = .configurationField
            return
        }
        
        captureSession.addOutput(output)
    }
    
    //MARK: - Captrure session configuration
    private func configureCaptureSession() {
        //Chanege in the future as mic access denial couses session to to start 
        guard captureSessionConfigurationStatus == .success else {
            captureSessionConfigurationStatus = .configurationField
            return
        }
        
        guard let videoDevice = returnAvailableVideoCaptureDevices(position: cameraPosition)?.first else {
            captureSessionConfigurationStatus = .configurationField
            return
        }
        
        guard let audioDevice = returnAvailableAudioCaptureDevices(position: cameraPosition)?.first else {
            captureSessionConfigurationStatus = .configurationField
            return
        }
        
        captureSession.beginConfiguration()
        captureSession.sessionPreset = .high
        
        addVideoInputDeviceToCaptureSession(device: videoDevice)
        addAudioInputDeviceToCaptureSession(device: audioDevice)
        
        addOutputToCaptureSession(output: videoOutput)
        
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
    
    private func stopSession() {
        if captureSession.isRunning { captureSession.stopRunning() }
    }
    
    //MARK: - Video
    @Published var isRecording: Bool = false
    
    private var documentDirectory: URL {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsDirectory
    }
    
    func startRecording() {
        let url = documentDirectory.appending(component: "tmp.mov")
        isRecording.toggle()
        videoOutput.startRecording(to: url, recordingDelegate: self)
    }
    
    func stopRecording() {
        isRecording.toggle()
        videoOutput.stopRecording()
    }
    
    //MARK: - Picture
    func takePicture() {
        let photoSettings = AVCapturePhotoSettings()
        self.photoOutput.capturePhoto(with: photoSettings, delegate: self)
    }
    
    
    //MARK: - Functions to interact with CameraManager (Camera)
    func zoomIn(){
        do {
            try videoInput.device.lockForConfiguration()
            if videoInput.device.videoZoomFactor < videoInput.device.maxAvailableVideoZoomFactor  { videoInput.device.videoZoomFactor += 0.5 }
            videoInput.device.unlockForConfiguration()
        } catch {
            print(error)
        }
    }
    
    //Sets camera zoom factor into entry one (1.0)
    func resetZoom() {
        do {
            try videoInput.device.lockForConfiguration()
            videoInput.device.videoZoomFactor = 1.0
            videoInput.device.unlockForConfiguration()
        } catch {
            print(error)
        }
    }
    
    func toogleFlash() {
        guard videoInput.device.hasTorch else { return }
        do {
            try videoInput.device.lockForConfiguration()
            
            switch(videoInput.device.isTorchActive) {
            case true:
                videoInput.device.torchMode = .off
            case false:
                videoInput.device.torchMode = .on
            }
        
            videoInput.device.unlockForConfiguration()
        } catch {
            print(error)
        }
    }
    
    func toogleFocus() {
        do { try videoInput.device.lockForConfiguration()
            switch(cameraPosition) {
            case .front:
                videoInput.device.exposureMode = .continuousAutoExposure
            case .back, .unspecified:
                videoInput.device.exposureMode = .continuousAutoExposure
                videoInput.device.focusMode = .continuousAutoFocus
            @unknown default:
                videoInput.device.exposureMode = .continuousAutoExposure
            }
        } catch {
            print("Could not lock device from configuration ")
        }
    }
    
    func exposure(at point: CGPoint) {
        guard videoInput.device.isExposurePointOfInterestSupported && videoInput.device.isExposureModeSupported(exposureMode) else {
            print("Exposure mode is not avialable on current device")
            return
        }
        
        do { try videoInput.device.lockForConfiguration()
            exposureMode = .autoExpose
            videoInput.device.exposureMode = exposureMode
            videoInput.device.exposurePointOfInterest = point
            videoInput.device.unlockForConfiguration()
        } catch {
            print("Could not lock device from configuration ")
        }
    }
    
    func focus(at point: CGPoint) {
        guard videoInput.device.isFocusPointOfInterestSupported && videoInput.device.isFocusModeSupported(focusMode) else {
            print("Focus mode is not avialable on current device")
            return
        }
        
        do { try videoInput.device.lockForConfiguration()
            focusMode = .autoFocus
            videoInput.device.focusMode = focusMode
            videoInput.device.focusPointOfInterest = point
            videoInput.device.unlockForConfiguration()
        } catch {
            print("Could not lock device for configuration ")
        }
    }
    
    func focusAndExposure(at point: CGPoint) {
        exposure(at: point)
        focus(at: point)
    }
    
    func toogleCamera() {
        switch cameraPosition {
        case .front:
            self.cameraPosition = .back
            guard let device = returnAvailableVideoCaptureDevices(position: cameraPosition)?.first else {
                self.cameraPosition = .front
                return
            }
            
            removeDeviceInputFromCaptureSession(input: videoInput)
            addVideoInputDeviceToCaptureSession(device: device)
        case .back, .unspecified:
            self.cameraPosition = .front
            guard let device = returnAvailableVideoCaptureDevices(position: cameraPosition)?.first else {
                self.cameraPosition = .back
                return
            }
            
            removeDeviceInputFromCaptureSession(input: videoInput)
            addVideoInputDeviceToCaptureSession(device: device)
        @unknown default:
            print("Unknown capture position")
        }
    }
    
    //MARK: - Delegate to recive sample buffer
    func setVideoDataOutputDelegate(with delegate: AVCaptureVideoDataOutputSampleBufferDelegate) {
        videoDataOutput.setSampleBufferDelegate(delegate, queue: outputQueue)
    }
    
    static let shared = CameraManager()
    
    private override init() {
        super.init()
        
        captureSessionQueue.async {
            self.requestCameraAuthorization()
            self.requestMicrophoneAuthorization()
            self.configureCaptureSession()
            self.startSession()
            
            print(self.captureSessionConfigurationStatus)
        }
    }
}

extension CameraManager: AVCapturePhotoCaptureDelegate {
    public func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let imageData = photo.fileDataRepresentation() else { return }
        if let image = UIImage(data: imageData) {
            UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        }
    }
}

extension CameraManager: AVCaptureFileOutputRecordingDelegate {
    private func clean(movie path: String) {
        guard FileManager.default.fileExists(atPath: path) else {
            return
        }
        
        try? FileManager.default.removeItem(atPath: path)
    }
    
    public func fileOutput(_ output: AVCaptureFileOutput, didStartRecordingTo fileURL: URL, from connections: [AVCaptureConnection]) {
        print("Started recording")
    }
    
    public func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        guard error == nil else {
            print("Movie file finishing error: \(String(describing: error))")
            return
        }
        
        requestPhotoLibraryAuthorization()
        guard isPhotoLibraryAccessGranted else {
            clean(movie: outputFileURL.absoluteString)
            return
        }
        
        PHPhotoLibrary.shared().performChanges({
            let options = PHAssetResourceCreationOptions()
            options.shouldMoveFile = true
            let creationRequest = PHAssetCreationRequest.forAsset()
            creationRequest.addResource(with: .video, fileURL: outputFileURL, options: options)
        }, completionHandler: { success, error in
            if !success {
                print("AVCam couldn't save the movie to your photo library: \(String(describing: error))")
            }
            self.clean(movie: outputFileURL.absoluteString)
        })
        
    }
}
