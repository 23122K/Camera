//
//  ContentView.swift
//  Camera
//
//  Created by Patryk Maciąg on 24/06/2023.
//

import SwiftUI

struct ContentView: View {
    @ObservedObject var cameraManagerViewModel: CameraManagerViewModel
    @State private var isIndicatorVisible = false
    @State private var currentScale: CGFloat = 0.0
    @State private var indicatorPoint: CGPoint = .zero {
        didSet {
            print(indicatorPoint.x)
            print(indicatorPoint.y)
            isIndicatorVisible = true
            DispatchQueue.main.asyncAfter(deadline: .now()+0.3, execute: {
                isIndicatorVisible = false
            })
        }
    }
    @State private var test: Bool = false
    
    var body: some View {
        switch cameraManagerViewModel.preview {
        case .movie, .photo:
            ZStack{
                if let url = cameraManagerViewModel.capturedMovieURL, cameraManagerViewModel.preview == .movie {
                    CustomVideoPlayer(movie: url)
                } else if let data = cameraManagerViewModel.capturedPhotoData, let uiImage = UIImage(data: data), cameraManagerViewModel.preview == .photo {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                } else {
                    EmptyView() //Something went wrong
                }
            }
            .overlay(content: {
                VStack{
                    Spacer()
                    HStack{
                        Spacer()
                        Button("Save") {
                            cameraManagerViewModel.save()
                            cameraManagerViewModel.discard()
                        }
                        Spacer()
                        Button("Retake") {
                            cameraManagerViewModel.discard()
                        }
                        Spacer()
                    }
                }
            })
        case .undefined:
            ZStack{
                GeometryReader { g in
                    CameraPreview()
                        .gesture(
                            MagnificationGesture()
                                .onChanged{ scale in
                                    if scale >= 1.0 { cameraManagerViewModel.zoomIn() }
                                    if scale < 1.0 { cameraManagerViewModel.zoomOut() }
                                }
                        )
                        .onTapGesture { l in
                            let point = CGPoint(x: l.x / g.size.width, y: l.y / g.size.height)
                            indicatorPoint = point
                            cameraManagerViewModel.focusAndExpose(at: point)
                        }
                        .cornerRadius(30)
                        .onTapGesture(count: 2) {
                            cameraManagerViewModel.flipCamera()
                        }
                        /*.overlay(content: {
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
                        })*/
                        .overlay(content: {
                            CameraOveraly(vm: cameraManagerViewModel)
                        })
                }
                //Tap indicator
                Circle()
                    .position(indicatorPoint)
                    .frame(width: 40, height: 40)
                    .opacity(isIndicatorVisible ? 1 : 0)
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(cameraManagerViewModel: CameraManagerViewModel())
    }
}
