//
//  Cameramanager.swift
//  Camera
//
//  Created by Patryk Maciąg on 24/06/2023.
//

import AVFoundation
import Photos

public final class CameraManager: NSObject, ObservableObject {
    //Enums to better handle event that can occure during the configuration process
    private enum SessionStatus {
        case success
        case notAuthorized
        case configurationField
    }
    
    public enum CaptureMode: Int {
        case photo = 0
        case video = 1
    }
    
    @Published public var captureMode: CaptureMode = .video
    
    @Published public var isPhotoLibraryAccessGranted = true
    @Published public var isMicrophoneAccessGranted = true
    @Published public var isCameraAccesGranted = true
    
    @Published public var isRecording = false
    
    @Published public var isTorchActivated = false
    @Published public var isFlashActivated = false
    @Published public var isFocused = false
    @Published public var zoomFactor = 1.0
    
    private var captureSessionConfigurationStatus: SessionStatus = .success
    
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
    
    public var captureSessionPreview: AVCaptureVideoPreviewLayer!
    
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
    private var supportedDevices: Array<AVCaptureDevice.DeviceType> = [.builtInDualCamera, .builtInDualWideCamera, .builtInTripleCamera, .builtInWideAngleCamera, .builtInMicrophone]
    private var returnAvailableVideoCaptureDevices: Array<AVCaptureDevice>? {
        guard captureSessionConfigurationStatus == .success else { return nil }
        
        return AVCaptureDevice.DiscoverySession(deviceTypes: supportedDevices, mediaType: .video, position: cameraPosition).devices
    }
    
    private var returnAvailableAudioCaptureDevices: Array<AVCaptureDevice>? {
        guard captureSessionConfigurationStatus == .success else { return nil }
        
        return AVCaptureDevice.DiscoverySession(deviceTypes: supportedDevices, mediaType: .audio, position: cameraPosition).devices
    }
    
    //MARK: - Input devices
    private func addVideoInputDeviceToCaptureSession(device: AVCaptureDevice) {
        videoInput = try? AVCaptureDeviceInput(device: device)
        guard let videoInput = videoInput else {
            captureSessionConfigurationStatus = .configurationField
            return
        }
        
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
    
    private func removeOutputFromCaptureSession(output: AVCaptureOutput) {
        captureSession.beginConfiguration()
        captureSession.removeOutput(output)
        captureSession.commitConfiguration()
    }
    
    //MARK: - Captrure session configuration
    private func configureCaptureSession() {
        //Chanege in the future as mic access denial couses session to to start
        guard captureSessionConfigurationStatus == .success else {
            captureSessionConfigurationStatus = .configurationField
            return
        }
        
        guard let videoDevice = returnAvailableVideoCaptureDevices?.first(where: { $0.deviceType == .builtInDualCamera }) else {
            captureSessionConfigurationStatus = .configurationField
            return
        }
        
        guard let audioDevice = returnAvailableAudioCaptureDevices?.first else {
            captureSessionConfigurationStatus = .configurationField
            return
        }
        
        captureSession.beginConfiguration()
        captureSession.sessionPreset = .high
        
        addVideoInputDeviceToCaptureSession(device: videoDevice)
        addAudioInputDeviceToCaptureSession(device: audioDevice)
        
        addOutputToCaptureSession(output: videoOutput) //Changes camera mode 
        
        captureSession.commitConfiguration()
    }
    
    func returnCaptureSession() -> AVCaptureSession {
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
    private var documentDirectory: URL {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsDirectory
    }
    
    func startRecording() {
        if captureMode == .photo { toogleCaptureMode() }
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
        if captureMode == .video { toogleCaptureMode() }
        let photoSettings = AVCapturePhotoSettings()
        
        switch isFlashActivated {
        case true:
            photoSettings.flashMode = flashMode
        case false:
            photoSettings.flashMode = flashMode
        }
        
        photoOutput.capturePhoto(with: AVCapturePhotoSettings(), delegate: self)
    }
    
    //MARK: - Functions to interact with CameraManager (Camera)
    public enum ZoomMode {
        case zoomIn
        case zoomOut
        case resetZoom
    }
    
    func zoom(_ mode: ZoomMode){
        do {
            try videoInput.device.lockForConfiguration()
            switch mode {
            case .zoomIn:
                if videoInput.device.videoZoomFactor + 0.1 < videoInput.device.maxAvailableVideoZoomFactor {
                    videoInput.device.videoZoomFactor += 0.1
                    zoomFactor += 0.1
                }
            case .zoomOut:
                if videoInput.device.videoZoomFactor - 0.1 > videoInput.device.minAvailableVideoZoomFactor  {
                    videoInput.device.videoZoomFactor -= 0.1
                    zoomFactor -= 0.1
                }
            case .resetZoom:
                videoInput.device.videoZoomFactor = 1.0
                zoomFactor = 1.0
            }
            videoInput.device.unlockForConfiguration()
        } catch {
            print(error)
        }
    }
    
    func toogleCaptureMode() {
        captureSession.beginConfiguration()
        switch captureMode {
        case .photo:
            removeOutputFromCaptureSession(output: photoOutput)
            addOutputToCaptureSession(output: videoOutput)
            captureMode = .video
        case .video:
            removeOutputFromCaptureSession(output: videoOutput)
            addOutputToCaptureSession(output: photoOutput)
            captureMode = .photo
        }
        captureSession.commitConfiguration()
    }
    
    func toogleFlashAndTorch() {
        toogleFlash()
        toogleTorch()
    }
    
    func toogleTorch() {
        guard videoInput.device.hasTorch && videoInput.device.isTorchAvailable else { return }
        do {
            try videoInput.device.lockForConfiguration()
            
            switch torchMode {
            case .on:
                isTorchActivated = false
                torchMode = .off
                videoInput.device.torchMode = .off
            case .off:
                isTorchActivated = true
                torchMode = .on
                videoInput.device.torchMode = .on
            case .auto:
                isTorchActivated = false
                torchMode = .off
                videoInput.device.torchMode = .off
            @unknown default:
                isTorchActivated = false
                torchMode = .off
                videoInput.device.torchMode = .off
            }
            videoInput.device.unlockForConfiguration()
        } catch {
            print(error)
        }
    }
    
    func toogleFlash() {
        guard videoInput.device.hasFlash && videoInput.device.isFlashAvailable else { return }
        do {
            try videoInput.device.lockForConfiguration()
            
            switch flashMode {
            case .off:
                isFlashActivated = true
                flashMode = .on
            case .on:
                isFlashActivated = false
                flashMode = .off
            case .auto:
                isFlashActivated = false
                flashMode = .off
            @unknown default:
                isFlashActivated = false
                flashMode = .off
            }
            
            videoInput.device.unlockForConfiguration()
        } catch {
            print(error)
        }
    }
    
    func toogleFocus() {
        do { try videoInput.device.lockForConfiguration()
            isFocused = false
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
    
    //Disable it if user did not grant permissions as it can be nil
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
        isFocused = true
        exposure(at: point)
        focus(at: point)
    }
    
    func toogleCamera() {
        switch cameraPosition {
        case .front:
            self.cameraPosition = .back
            guard let device = returnAvailableVideoCaptureDevices?.first else {
                self.cameraPosition = .front
                return
            }
            
            removeDeviceInputFromCaptureSession(input: videoInput)
            addVideoInputDeviceToCaptureSession(device: device)
        case .back, .unspecified:
            self.cameraPosition = .front
            guard let device = returnAvailableVideoCaptureDevices?.first else {
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
        guard let photoData = photo.fileDataRepresentation() else { return }
        
        requestPhotoLibraryAuthorization()
        
        guard isPhotoLibraryAccessGranted else {
            return
        }
        
        PHPhotoLibrary.shared().performChanges({
            let options = PHAssetResourceCreationOptions()
            let creationRequest = PHAssetCreationRequest.forAsset()
            creationRequest.addResource(with: .photo, data: photoData, options: options)
        }, completionHandler: { success, error in
            if !success {
                print("AVCam couldn't save the movie to your photo library: \(String(describing: error))")
            }
        })
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
