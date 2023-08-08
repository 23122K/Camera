//
//  CameraManagerTypes.swift
//  Camera
//
//  Created by Patryk Maciąg on 07/08/2023.
//

import Foundation

public enum cameraManagerError: Error {
    case noCameraFound
    case noMicrophoneFound
    case failedToOutputVideo
    case cannotSavePhotoToPhotoLibrary(error: Error)
    case cannotSaveMovieToPhotoLibrary(error: Error)
    case cannotAddVideoInputToCaptureSession
    case cannotAddAudioInputToCaptureSession
    case cannotAddOutputToCaptureSession
    case captureSessionConfigurationField(error: Error)
    case unknownCameraPosition
}

public enum SessionStatus {
    case success
    case notAuthorized
    case configurationField
}
