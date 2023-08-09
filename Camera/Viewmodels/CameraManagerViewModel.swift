//
//  CameraManagerViewModel.swift
//  Camera
//
//  Created by Patryk Maciąg on 07/08/2023.
//

import SwiftUI

class CameraManagerViewModel: ObservableObject {
    private var cameraManager: CameraManager
    
    public enum AppState {
        case captureMode
        case photoPreviewMode
        case moviePreviewMode
    }
    
    @Published var appState: AppState = .captureMode
    @Published var isPhotoLibraryAccessGranted = true
    @Published var isMicrophoneAccessGranted = true
    @Published var isCameraAccessGranted = true
    @Published var isRecording = false
    
    @Published var capturedPhotoData: Data?
    @Published var capturedMovieURL: URL?
    
    @Published var hasFinishedProccessingOutput = false
    @Published var isTorchActivated = false
    @Published var isFlashActivated = false
    
    @Published var zoomFactor: Double = 1.0
    
    //Saves captured resource to user photo library
    func save() {
        cameraManager.saveCapturedResource()
    }
    
    //After photo/movie has been taken session is stopped, thus below function resumes it and changed appState back to capture
    func discard() {
        appState = .captureMode
        cameraManager.startSession()
    }
    
    
    func zoomIn() { cameraManager.zoom(.zoomIn) }
    func zoomOut() { cameraManager.zoom(.zoomOut) }
    func resetZoom() { cameraManager.zoom(.resetZoom) }
    
    func focusAndExpose(at point: CGPoint) {
        cameraManager.focusAndExposure(at: point)
    }
    
    func toogleTorch() {
        cameraManager.toogleFlashAndTorch()
    }
    
    func flipCamera() {
        do {
            try cameraManager.flipCamera()
        } catch {
            print(error)
        }
        
    }
    
    func capturePhoto() {
        cameraManager.capturePhoto()
    }
    
    func startRecording() {
        cameraManager.startRecording()
    }
    func stopRecording() {
        cameraManager.stopRecording()
    }
    
    init(cameraManager: CameraManager = CameraManager.shared) {
        self.cameraManager = cameraManager
        self.cameraManager.controllsDelegate = self
        self.cameraManager.outputDelegate = self
    }
}

extension CameraManagerViewModel: CameraManagerControllsDelegate, CameraManagerOutputDelegate {
    func photoOutputDidFinish(with output: Data?) {
        guard let data = output else {
            return
        }
        
        appState = .photoPreviewMode
        capturedPhotoData = data
        cameraManager.stopSession()
    }
    
    func movieOutputDidFinish(with output: URL?) {
        isRecording = false
        
        guard let url = output else {
            return
        }
        
        appState = .moviePreviewMode
        capturedMovieURL = url
        cameraManager.stopSession()
    }
    
    func movieOutputDidStart(_ flag: Bool) {
        isRecording = flag
    }
    
    func photoLibraryAccessDidChange(granted: Bool) {
        isPhotoLibraryAccessGranted = granted
    }
    
    func microphoneAccessDidChange(granted: Bool) {
        DispatchQueue.main.async {
            self.isMicrophoneAccessGranted = granted
        }
    }
    
    
    func cameraAccessDidChange(granted: Bool) {
        DispatchQueue.main.async {
            self.isCameraAccessGranted = granted
        }
    }
    
    func torchDidChangeActivation(to active: Bool) {
        isTorchActivated = active
    }
    
    func flashDidChangeActivation(to active: Bool) {
        isFlashActivated = active
    }
    
    func focusStatusDidChange(isFocused: Bool) {
        
    }
    
    func zoomFactorDidChange(to factor: Double) {
        zoomFactor = factor
    }
    
    
}
