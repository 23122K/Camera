//
//  ContentView.swift
//  Camera
//
//  Created by Patryk Maciąg on 24/06/2023.
//

import SwiftUI

struct ContentView: View {
    @State var cricleLocation = CGPoint()
    @ObservedObject private var cameraManager = CameraManager.shared
    
    var body: some View {
        ZStack{
            GeometryReader { g in
                CameraPreview(session: cameraManager.returnCaptureSession())
                    .ignoresSafeArea()
                    .onTapGesture { location in
                        let point = CGPoint(x: location.x / g.size.width, y: location.y / g.size.height)
                        cricleLocation = location
                        cameraManager.focusAndExposure(at: point)
                    }
            }
            Circle()
                .frame(width: 20, height: 20)
                .position(cricleLocation)
            
            VStack{
                HStack{
                    Spacer()
                    Image(systemName: "bolt")
                        .font(.system(size: 30))
                        .onTapGesture {
                            cameraManager.toogleTorch()
                        }
                    Image(systemName: "plus")
                        .font(.system(size: 30))
                        .onTapGesture {
                            cameraManager.zoomIn()
                        }
                    Image(systemName: "circle")
                        .font(.system(size: 30))
                        .onTapGesture {
                            cameraManager.toogleFocus()
                        }
                }
                .padding()
                Spacer()
                
                Button(action: {
                    // ignore
                }) {
                    Circle()
                        .stroke(lineWidth: 5)
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
                
//                Button(action: {
//                    switch(cameraManager.isRecording){
//                    case false:
//                        cameraManager.startRecording()
//                    case true:
//                        cameraManager.stopRecording()
//                    }
//                }, label: {
//                    ZStack{
//                        Circle()
//                            .stroke(lineWidth: 5)
//                            .fill(.white)
//                            .frame(width: 75, height: 75)
//                    }
//                })
            }
            .simultaneousGesture(TapGesture(count: 2).onEnded {
                cameraManager.toogleCamera()
            })
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
