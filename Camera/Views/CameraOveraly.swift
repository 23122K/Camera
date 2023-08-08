//
//  CameraOveraly.swift
//  Camera
//
//  Created by Patryk Maciąg on 07/08/2023.
//

import SwiftUI

struct CameraOveraly: View {
    @ObservedObject var vm: CameraManagerViewModel
    var body: some View {
        VStack(content: {
            HStack{
                Spacer()
                VStack{
                    Image("flash")
                        .scaleEffect(0.6)
                        .padding(.top)
                        .padding(.bottom)
                    Image("flip.camera")
                        .scaleEffect(0.6)
                        .padding(.bottom)
                }
                .padding(10)
                .background(.ultraThinMaterial)
                .cornerRadius(15)
            }
            .padding()
            Spacer()
            HStack{
                Button(action: {
                    // ignore
                }) {
                    Circle()
                        .stroke(lineWidth: 7)
                        .frame(width: 75, height: 75)
                }
                .simultaneousGesture(
                    DragGesture()
                        .onChanged { scale in
                            print(scale.)
                        }
                )
                .simultaneousGesture(
                    LongPressGesture()
                        .onEnded { _ in
                            vm.startRecording()
                        }
                )
                .simultaneousGesture(TapGesture().onEnded {
                    switch vm.isRecording {
                    case true: vm.stopRecording()
                    case false: vm.capturePhoto()
                    }
                })
            }
        })
        .padding(.bottom, 50)
    }
}

struct CameraOveraly_Previews: PreviewProvider {
    static var previews: some View {
        CameraOveraly(vm: CameraManagerViewModel())
    }
}
