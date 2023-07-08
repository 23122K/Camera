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
                .ignoresSafeArea()
                .onTapGesture(count: 2) {
                    cameraManager.toogleCamera()
                }
            
            VStack{
                HStack{
                    Spacer()
                    VStack{
                        Button(action: {
                            cameraManager.toogleCamera()
                        }, label: {
                            Image("flip.camera")
                                .padding(.top)
                        })
                        
                        Button(action: {
                            cameraManager.toogleTorch()
                        }, label: {
                            Image(cameraManager.isTorchActivated ? "flash" : "flash.off")
                                .padding(.top, 5)
                        })
                    }.background{
                        RoundedRectangle(cornerRadius: 45)
                            .fill(.black)
                            .opacity(0.4)
                    }
                    .padding(.top)
                    .padding(.trailing, 5)
                    .padding(.leading, 5)
                }
                .padding()
                Spacer()
                
                Button(action: {
                    cameraManager.zoom(mode: .resetZoom)
                }, label: {
                    ZStack{
                        Circle()
                            .stroke(lineWidth: 1)
                            .fill(Color.white)
                            .frame(width: 25, height: 25)
                        Text(String(format: "%0.1f", cameraManager.zoomFactor))
                            .font(.caption2)
                            .foregroundColor(.white)
                    }
                })
                
                Button(action: {
                    // ignore
                }) {
                    Circle()
                        .stroke(lineWidth: 7)
                        .foregroundColor(cameraManager.isRecording ? Color.red.opacity(0.7) : Color.white.opacity(0.8))
                        .frame(width: 75, height: 75)
                        .padding(.bottom, 25)
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
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
