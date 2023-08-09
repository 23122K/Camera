//
//  Cameramanager.swift
//  Camera
//
//  Created by Patryk Maciąg on 24/06/2023.
//

import AVFoundation
import Photos
import SwiftUI

protocol CameraManagerOutputDelegate: AnyObject {
    func photoOutputDidFinish(with output: Data?)
    func movieOutputDidFinish(with output: URL?)
    func movieOutputDidStart(_ flag: Bool)
}

protocol CameraManagerControllsDelegate: AnyObject {
    func photoLibraryAccessDidChange(granted: Bool)
    func microphoneAccessDidChange(granted: Bool)
    func cameraAccessDidChange(granted: Bool)
    func torchDidChangeActivation(to active: Bool)
    func flashDidChangeActivation(to active: Bool)
    func focusStatusDidChange(isFocused: Bool)
    func zoomFactorDidChange(to factor: Double)
}

public final class CameraManager: NSObject {
    
    //MARK: Custom types
    internal enum ZoomMode {
        case zoomIn
        case zoomOut
        case resetZoom
    }
    
    //Helper type used to manage saving/cleaning captured data
    private enum CaptureMode {
        case photo
        case movie
    }
    
    private enum ConfigurationStatus {
        case success
        case failure
    }
    
    //MARK: - Properties
    
    //Initial state of captureMode does not matter, it is mutated every time when function for capturing photo/movie is called.
    private var captureMode: CaptureMode = .photo
    private var captureSessionStatus: ConfigurationStatus = .success
    
    //.unspecified case in cameraPosition is considered as .back
    private var cameraPosition: AVCaptureDevice.Position = .unspecified

    private var exposureMode: AVCaptureDevice.ExposureMode = .continuousAutoExposure
    private var focusMode: AVCaptureDevice.FocusMode = .continuousAutoFocus
    private var torchMode: AVCaptureDevice.TorchMode = .off {
        didSet {
            switch torchMode {
            case .off, .auto:
                self.controllsDelegate?.torchDidChangeActivation(to: false)
            case .on:
                self.controllsDelegate?.torchDidChangeActivation(to: true)
            @unknown default:
                self.controllsDelegate?.torchDidChangeActivation(to: false)
            }
        }
    }
    private var flashMode: AVCaptureDevice.FlashMode = .off {
        didSet {
            switch flashMode {
            case .off, .auto:
                self.controllsDelegate?.flashDidChangeActivation(to: false)
            case .on:
                self.controllsDelegate?.flashDidChangeActivation(to: true)
            @unknown default:
                self.controllsDelegate?.flashDidChangeActivation(to: false)
            }
        }
    }
    
    //These properties are also used as trigger for delegate via didSet, dunno if it is ok to do that
    private var isPhotoLibraryAccessGranted = true {
        didSet {
            self.controllsDelegate?.photoLibraryAccessDidChange(granted: isPhotoLibraryAccessGranted)
        }
    }
    private var isMicrophoneAccessGranted = true {
        didSet {
            self.controllsDelegate?.microphoneAccessDidChange(granted: isMicrophoneAccessGranted)
        }
    }
    private var isCameraAccessGranted = true {
        didSet {
            self.controllsDelegate?.cameraAccessDidChange(granted: isCameraAccessGranted)
        }
    }
    
    private var capturedPhotoData: Data?
    private var capturedVideoURL: URL?
    
    private let captureSessionQueue = DispatchQueue(label: "capture.session")
    
    //Returns URL to which captured movie is saved
    private var movieURL: URL {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsDirectory.appending(component: "tmp_movie_file.mov")
    }
    
    //MARK: - Dependencies
    private let captureSession = AVCaptureSession()
    
    private let photoOutput = AVCapturePhotoOutput()
    private let movieOutput = AVCaptureMovieFileOutput()
    
    private var videoInput: AVCaptureDeviceInput!
    private var audioInput: AVCaptureDeviceInput!
    
    //MARK: - Delegates
    weak var controllsDelegate: CameraManagerControllsDelegate?
    weak var outputDelegate: CameraManagerOutputDelegate?
    
    //MARK: - Camera, Microphone and PhotoLibrary access and authorization
    private func requestMicrophoneAuthorization() {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return
        case .notDetermined:
            requestMicrophoneAccess()
        default :
            isMicrophoneAccessGranted = false
        }
    }
    
    private func requestMicrophoneAccess() {
        AVCaptureDevice.requestAccess(for: .audio) { accesGranted in
            guard accesGranted else {
                self.isMicrophoneAccessGranted = false
                return
            }
            
        }
    }
    
    private func requestCameraAuthorization() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return
        case .notDetermined:
            requestCameraAccess()
        default: // Access has been denied by user or it is restricted by parental controll
            isCameraAccessGranted = false
        }
    }
    
    private func requestCameraAccess() {
        //Suspending capture.session queue as it wont be used if user did not grant camera usage permissions
        self.captureSessionQueue.suspend()
        
        AVCaptureDevice.requestAccess(for: .video) { accessGranted in
            guard accessGranted else {
                self.isCameraAccessGranted = false
                return
            }
            
            //capture.session queue is resumed only after camera permissions has been granted
            self.captureSessionQueue.resume()
        }
    }
    
    private func requestPhotoLibraryAuthorization() {
        switch PHPhotoLibrary.authorizationStatus(for: .addOnly) {
        case .authorized:
            return
        case .notDetermined:
            requestPhotoLibraryAccess()
        default:
            isPhotoLibraryAccessGranted = false
        }
    }
    
    private func requestPhotoLibraryAccess() {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { accessGranted in
            guard accessGranted == .authorized else {
                self.isPhotoLibraryAccessGranted = false
                return
            }
        }
    }
    
    //MARK: - Device discovery
    //Below properties returns video/audio device if permission has been granted and such device was found
    private var supportedDevices: Array<AVCaptureDevice.DeviceType> = [.builtInDualCamera, .builtInDualWideCamera, .builtInTripleCamera, .builtInWideAngleCamera, .builtInMicrophone]
    
    private var returnAvailableVideoCaptureDevices: Array<AVCaptureDevice>? {
        guard isCameraAccessGranted else { return nil }
        
        return AVCaptureDevice.DiscoverySession(deviceTypes: supportedDevices, mediaType: .video, position: cameraPosition).devices
    }
    
    private var returnAvailableAudioCaptureDevices: Array<AVCaptureDevice>? {
        guard isMicrophoneAccessGranted else { return nil }
        
        return AVCaptureDevice.DiscoverySession(deviceTypes: supportedDevices, mediaType: .audio, position: cameraPosition).devices
    }
    
    //MARK: - Input devices
    private func addVideoInputDeviceToCaptureSession(device: AVCaptureDevice) throws {
        videoInput = try? AVCaptureDeviceInput(device: device)
        guard let videoInput = videoInput else {
            throw cameraManagerError.cannotAddVideoInputToCaptureSession
        }
        
        captureSession.addInput(videoInput)
    }
    
    private func addAudioInputDeviceToCaptureSession(device: AVCaptureDevice) throws {
        audioInput = try? AVCaptureDeviceInput(device: device)
        guard let input = audioInput else {
            throw cameraManagerError.cannotAddAudioInputToCaptureSession
        }
        
        captureSession.addInput(input)
    }
    
    private func removeDeviceInputFromCaptureSession(input: AVCaptureDeviceInput) {
        captureSession.beginConfiguration()
        captureSession.removeInput(input)
        captureSession.commitConfiguration()
    }
    
    //MARK: - Output
    private func addOutputToCaptureSession(output: AVCaptureOutput) throws {
        guard captureSession.canAddOutput(output) else {
            throw cameraManagerError.cannotAddOutputToCaptureSession
        }
        
        captureSession.addOutput(output)
    }
    
    private func removeOutputFromCaptureSession(output: AVCaptureOutput) {
        captureSession.beginConfiguration()
        captureSession.removeOutput(output)
        captureSession.commitConfiguration()
    }
    
    //MARK: - Captrure session configuration
    private func configureCaptureSession() throws {
        //guard isCameraAccessGranted else { return }
        
        guard let videoDevice = returnAvailableVideoCaptureDevices?.first else {
            throw cameraManagerError.noCameraFound
        }
        
        guard let audioDevice = returnAvailableAudioCaptureDevices?.first else {
            throw cameraManagerError.noMicrophoneFound
        }
        
        captureSession.beginConfiguration()
        captureSession.sessionPreset = .high
        
        do {
            try addVideoInputDeviceToCaptureSession(device: videoDevice)
            try addAudioInputDeviceToCaptureSession(device: audioDevice)
            
            //Note, you can add more that one video ouput (movie/photo) thus crateing smooth transition between taking picture and capturing photo such us in instagram/snapchat app.
            try addOutputToCaptureSession(output: photoOutput)
            try addOutputToCaptureSession(output: movieOutput)
        } catch {
            throw cameraManagerError.captureSessionConfigurationField(error: error)
        }
        
        captureSession.commitConfiguration()
    }
    
    internal func returnCaptureSession() -> AVCaptureSession {
        return captureSession
    }
    
    func startSession() {
        //Gotta check if everything was set up correctly
        captureSessionQueue.async {
            self.captureSession.startRunning()
        }
    }
    
    func stopSession() {
        if captureSession.isRunning { captureSession.stopRunning() }
    }
    
    //MARK: - Functions to interact with CameraManager (Camera)
    func startRecording() {
        captureMode = .movie
        movieOutput.startRecording(to: movieURL, recordingDelegate: self)
    }
    
    func stopRecording() {
        movieOutput.stopRecording()
    }
    
    func capturePhoto() {
        captureMode = .photo
        photoOutput.capturePhoto(with: AVCapturePhotoSettings(), delegate: self)
    }
    
    func zoom(_ mode: ZoomMode){
        do {
            try videoInput.device.lockForConfiguration()
            
            switch mode {
            case .zoomIn:
                if videoInput.device.videoZoomFactor + 0.1 < videoInput.device.maxAvailableVideoZoomFactor { videoInput.device.videoZoomFactor += 0.1 }
            case .zoomOut:
                if videoInput.device.videoZoomFactor - 0.1 > videoInput.device.minAvailableVideoZoomFactor  { videoInput.device.videoZoomFactor -= 0.1 }
            case .resetZoom:
                videoInput.device.videoZoomFactor = 1.0
            }
            
            let zoomFactor = Double(videoInput.device.videoZoomFactor)
            controllsDelegate?.zoomFactorDidChange(to: zoomFactor)
            
            videoInput.device.unlockForConfiguration()
        } catch {
            print(error)
        }
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
                torchMode = .off
                videoInput.device.torchMode = self.torchMode
            case .off:
                torchMode = .on
                videoInput.device.torchMode = self.torchMode
            case .auto:
                torchMode = .off
                videoInput.device.torchMode = self.torchMode
            @unknown default:
                torchMode = .off
                videoInput.device.torchMode = self.torchMode
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
                flashMode = .on
            case .on:
                flashMode = .off
            case .auto:
                flashMode = .off
            @unknown default:
                flashMode = .off
            }
            
            videoInput.device.unlockForConfiguration()
        } catch {
            print(error)
        }
    }
    
    func toogleFocus() {
        do {
            try videoInput.device.lockForConfiguration()
            
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
    
    //To do
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
    
    //To Do:
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
    
    func flipCamera() throws {
        switch cameraPosition {
        case .front:
            self.cameraPosition = .back
            guard let device = returnAvailableVideoCaptureDevices?.first else {
                self.cameraPosition = .front
                throw cameraManagerError.noCameraFound
            }
            
            removeDeviceInputFromCaptureSession(input: videoInput)
            do {
                try addVideoInputDeviceToCaptureSession(device: device)
            } catch {
                print(error)
            }
        case .back, .unspecified:
            self.cameraPosition = .front
            guard let device = returnAvailableVideoCaptureDevices?.first else {
                self.cameraPosition = .back
                throw cameraManagerError.noCameraFound
            }
            
            removeDeviceInputFromCaptureSession(input: videoInput)
            do {
                try addVideoInputDeviceToCaptureSession(device: device)
            } catch {
                print(error)
            }
        @unknown default:
            throw cameraManagerError.unknownCameraPosition
        }
    }
    
    private func clean() {
        switch captureMode {
        case .photo:
            capturedPhotoData = nil
        case .movie:
            guard let path = capturedVideoURL?.absoluteString, FileManager.default.fileExists(atPath: path) else { return }
            
            try? FileManager.default.removeItem(atPath: path)
            capturedVideoURL = nil
        }
    }
    
    //MARK: - Persisting captured output depending capture mode
    public func saveCapturedResource() {
        requestPhotoLibraryAuthorization()
        
        guard isPhotoLibraryAccessGranted else { return }
        
        switch captureMode {
        case .photo:
            guard let data = capturedPhotoData else { return }
            PHPhotoLibrary.shared().performChanges({
                let options = PHAssetResourceCreationOptions()
                let creationRequest = PHAssetCreationRequest.forAsset()
                creationRequest.addResource(with: .photo, data: data, options: options)
            }, completionHandler: { success, error in
                if !success {
                    print("Could not save photo to photo library: \(String(describing: error))")
                }
            })
        case .movie:
            guard let fileURL = capturedVideoURL else { return }
            PHPhotoLibrary.shared().performChanges({
                let options = PHAssetResourceCreationOptions()
                options.shouldMoveFile = true
                let creationRequest = PHAssetCreationRequest.forAsset()
                creationRequest.addResource(with: .video, fileURL: fileURL, options: options)
            }, completionHandler: { success, error in
                if !success {
                    print("Could not save movie to photo library: \(String(describing: error))")
                }
            })
        }
        
        clean()
    }
    
    //MARK: - Init
    static let shared = CameraManager()
    
    private override init() {
        super.init()
        
        captureSessionQueue.async {
            self.requestCameraAuthorization()
            self.requestMicrophoneAuthorization()
            
            do {
                try self.configureCaptureSession()
            } catch {
                print(error)
            }
            
            self.startSession()
        }
    }
}


extension CameraManager: AVCapturePhotoCaptureDelegate, AVCaptureFileOutputRecordingDelegate{
    
    //Picture is outputed as a data
    public func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let data = photo.fileDataRepresentation() else {
            outputDelegate?.photoOutputDidFinish(with: nil)
            return
        }
        capturedPhotoData = data
        
        outputDelegate?.photoOutputDidFinish(with: data)
    }
    
    //Movie is outputed as a path to file
    public func fileOutput(_ output: AVCaptureFileOutput, didStartRecordingTo fileURL: URL, from connections: [AVCaptureConnection]) {
        outputDelegate?.movieOutputDidStart(true)
    }
    
    public func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        guard error == nil else {
            outputDelegate?.movieOutputDidFinish(with: nil)
            return
        }
        
        capturedVideoURL = outputFileURL
        outputDelegate?.movieOutputDidFinish(with: outputFileURL)
    }
}
