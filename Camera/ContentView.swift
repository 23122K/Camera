//
//  ContentView.swift
//  Camera
//
//  Created by Patryk Maciąg on 24/06/2023.
//

import SwiftUI

struct ContentView: View {
    @State var location = CGPoint()
    var body: some View {
        ZStack{
            CameraPreviewHolder()
                .ignoresSafeArea()
                .onTapGesture { location in
                    self.location = location
                    CameraManager.shared.focus(at: location)
                }
            Circle()
                .frame(width: 20, height: 20)
                .position(location)
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
                            CameraManager.shared.setZoom()
                        }
                    Image(systemName: "circle")
                        .font(.system(size: 30))
                        .onTapGesture {
                            CameraManager.shared.toogleFocus()
                        }
                }
                .padding()
                Spacer()
            }
            .padding()
        }
        .onTapGesture(count: 2) {
            CameraManager.shared.toogleCamera()
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
