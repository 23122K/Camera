//
//  CameraManagerViewModel.swift
//  Camera
//
//  Created by Patryk Maciąg on 07/08/2023.
//

import SwiftUI

class CameraManagerViewModel: ObservableObject {
    private var cameraManager: CameraManager
    
    @Published var isPhotoLibraryAccessGranted = true
    @Published var isMicrophoneAccessGranted = true
    @Published var isCameraAccessGranted = true
    
    @Published var hasFinishedProccessingOutput = false
    @Published var isTorchActivated = false
    @Published var isFlashActivated = false
    @Published var isRecording = false
    
    @Published var zoomFactor: Double = 1.0
    @Published var currentCaptureMode: CaptureMode = .video
    
    func save() { cameraManager.persistCapturedResource() }
    func retake() { cameraManager.retake() }
    
    func zoomIn() { cameraManager.zoom(.zoomIn) }
    func zoomOut() { cameraManager.zoom(.zoomOut) }
    func resetZoom() { cameraManager.zoom(.resetZoom) }
    
    func flipCamera() {
        cameraManager.flipCamera()
        
    }
    
    func takePicture() {
        cameraManager.takePicture()
        
    }
    
    func startRecording() {
        cameraManager.startRecording()
    }
    func stopRecording() {
        cameraManager.stopRecording()
    }
    
    init(cameraManager: CameraManager = CameraManager.shared) {
        self.cameraManager = cameraManager
        self.cameraManager.delegate = self
    }
}

extension CameraManagerViewModel: CameraManagerDelegate {
    func photoLibraryAccessDidChange(granted: Bool) {
        isPhotoLibraryAccessGranted = granted
    }
    func microphoneAccessDidChange(granted: Bool) {
        isMicrophoneAccessGranted = granted
    }
    func cameraAccessDidChange(granted: Bool) {
        isCameraAccessGranted = granted
    }
    
    func captureModeDidChange(to mode: CaptureMode) {
        print(mode)
        currentCaptureMode = mode
    }
    
    func processingOutputDidFinish(success: Bool) {
        hasFinishedProccessingOutput = success
    }
    
    func torchDidChangeActivation(to active: Bool) {
        isTorchActivated = active
    }
    
    func flashDidChangeActivation(to active: Bool) {
        isFlashActivated = active
    }
    
    func recordingStatusDidChange(isRecording: Bool) {
        self.isRecording = isRecording
    }
    
    func focusStatusDidChange(isFocused: Bool) {
        
    }
    
    func zoomFactorDidChange(to factor: Double) {
        zoomFactor = factor
    }
    
    
}
