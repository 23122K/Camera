//
//  CameraManagerTypes.swift
//  Camera
//
//  Created by Patryk Maciąg on 07/08/2023.
//

import Foundation

public enum CaptureMode {
    case photo
    case video
}

public enum cameraManagerError: Error {
    case noCameraFound
    case noMicrophoneFound
}

public enum SessionStatus {
    case success
    case notAuthorized
    case configurationField
}
