//
//  ContentView.swift
//  Camera
//
//  Created by Patryk Maciąg on 24/06/2023.
//

import SwiftUI

struct ContentView: View {
    @ObservedObject private var cameraManager = CameraManager.shared
    
    var body: some View {
        ZStack{
            CameraPreview(cameraManager: cameraManager)
                .cornerRadius(30)
                .onTapGesture(count: 2) {
                    cameraManager.toogleCamera()
                }
            
            VStack{
                Spacer()
                Button(action: {
                    cameraManager.zoom(.resetZoom)
                }, label: {
                    ZStack{
                        Circle()
                            .stroke(lineWidth: 1)
                            .fill(Color.white)
                            .frame(width: 35, height: 35)
                        Text(String(format: "%0.1f", cameraManager.zoomFactor))
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                    }
                })
                .padding(.bottom)
                ZStack{
                    VStack{
                        HStack{
                            Spacer()
                            Button(action: {
                                cameraManager.toogleFlashAndTorch()
                            }, label: {
                                Image(cameraManager.isTorchActivated ? "flash" : "flash.off")
                                    .padding(.top, 5)
                            })
                            Spacer()
                            Button(action: {
                                // ignore
                            }) {
                                Circle()
                                    .stroke(lineWidth: 7)
                                    .foregroundColor(cameraManager.isRecording ? Color.red.opacity(0.7) : Color.white.opacity(0.8))
                                    .frame(width: 75, height: 75)
                            }
                            .simultaneousGesture(
                                LongPressGesture()
                                    .onEnded { _ in
                                        print("Recording")
                                        cameraManager.startRecording()
                                    }
                            )
                            .simultaneousGesture(TapGesture().onEnded {
                                switch cameraManager.isRecording {
                                case true:
                                    cameraManager.stopRecording()
                                case false:
                                    cameraManager.takePicture()
                                }
                            })
                            Spacer()
                            Button(action: {
                                cameraManager.toogleCamera()
                            }, label: {
                                Image("flip.camera")
                            })
                            Spacer()
                        }
                    }
                    .padding(.vertical)
                    .background(.ultraThinMaterial)
                    .cornerRadius(30)
                }
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
