//
//  CameraApp.swift
//  Camera
//
//  Created by Patryk Maciąg on 24/06/2023.
//

import SwiftUI

@main
struct CameraApp: App {
    @StateObject private var cameraManagerViewModel = CameraManagerViewModel()
    var body: some Scene {
        WindowGroup {
            ContentView(cameraManagerViewModel: cameraManagerViewModel)
        }
    }
}
