//
//  ContentView.swift
//  Camera
//
//  Created by Patryk Maciąg on 24/06/2023.
//

import SwiftUI

struct ContentView: View {
    @ObservedObject var cameraManagerViewModel: CameraManagerViewModel
    @State private var test: Bool = false
    
    var body: some View {
        switch cameraManagerViewModel.hasFinishedProccessingOutput {
            case true:
            CapturedResourcePreview(cameraManagerViewModel: cameraManagerViewModel)
                .overlay(content: {
                    VStack{
                        Spacer()
                        HStack{
                            Spacer()
                            Button("Save") {
                                cameraManagerViewModel.save()
                                cameraManagerViewModel.retake()
                            }
                            Spacer()
                            Button("Retake") {
                                cameraManagerViewModel.retake()
                            }
                            Spacer()
                        }
                    }
                })
            case false:
            CameraPreview()
                .cornerRadius(30)
                .onTapGesture(count: 2) {
                    cameraManagerViewModel.flipCamera()
                }
                .overlay(content: {
                    VStack{
                        Spacer()
                        Button(action: {
                            cameraManagerViewModel.resetZoom()
                        }, label: {
                            ZStack{
                                Circle()
                                    .stroke(lineWidth: 1)
                                    .fill(Color.white)
                                    .frame(width: 35, height: 35)
                                Text(String(format: "%0.1f", cameraManagerViewModel.zoomFactor))
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
//                                        cameraManager.toogleFlashAndTorch()
                                    }, label: {
                                        Image("flash.off") //cameraManager.isTorchActivated ? "flash" :
                                            .padding(.top, 5)
                                    })
                                    Spacer()
                                    Button(action: {
                                        // ignore
                                    }) {
                                        Circle()
                                            .stroke(lineWidth: 7)
                                            .frame(width: 75, height: 75)
                                    }
                                    .simultaneousGesture(
                                        LongPressGesture()
                                            .onEnded { _ in
                                                print("Recording")
                                                cameraManagerViewModel.startRecording()
                                            }
                                    )
                                    .simultaneousGesture(TapGesture().onEnded {
                                        switch cameraManagerViewModel.isRecording {
                                        case true:
                                            cameraManagerViewModel.stopRecording()
                                        case false:
                                            cameraManagerViewModel.takePicture()
                                        }
                                    })
                                    Spacer()
                                    Button(action: {
                                        cameraManagerViewModel.flipCamera()
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
                })
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(cameraManagerViewModel: CameraManagerViewModel())
    }
}
