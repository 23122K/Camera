//
//  ContentView.swift
//  Camera
//
//  Created by Patryk Maciąg on 24/06/2023.
//

import SwiftUI

struct ContentView: View {
    @State var cricleLocation = CGPoint()
    var body: some View {
        ZStack{
            GeometryReader { g in
                CameraPreviewHolder()
                    .ignoresSafeArea()
                    .onTapGesture { location in
                        let point = CGPoint(x: location.x / g.size.width, y: location.y / g.size.height)
                        cricleLocation = location
                        CameraManager.shared.focusAndExposure(at: point)
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
                            CameraManager.shared.toogleFlash()
                        }
                    Image(systemName: "plus")
                        .font(.system(size: 30))
                        .onTapGesture {
                            CameraManager.shared.zoomIn()
                        }
                    Image(systemName: "circle")
                        .font(.system(size: 30))
                        .onTapGesture {
                            CameraManager.shared.toogleFocus()
                        }
                }
                .padding()
                Spacer()
                
                
        
                Button(action: {
                    switch(CameraManager.shared.isRecording) {
                    case true:
                        CameraManager.shared.stopRecording()
                    case false:
                        CameraManager.shared.startRecording()
                    }
                }, label: {
                    ZStack{
                        Circle()
                            .fill(CameraManager.shared.isRecording ? .red : .white)
                            .frame(width: 65, height: 65)
                        Circle()
                            .stroke(Color.white, lineWidth: 2)
                            .frame(width: 75, height: 75)
                    }
                })
            }
            .padding()
        }
        .simultaneousGesture(TapGesture(count: 2).onEnded {
            CameraManager.shared.toogleCamera()
        })
        
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
