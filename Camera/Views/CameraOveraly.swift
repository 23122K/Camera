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
                    Button(action: {
                        vm.toogleTorch()
                    }, label: {
                        Image("flash")
                            .scaleEffect(0.9)
                            .padding(.bottom)
                    })
                    Button(action: {
                        vm.flipCamera()
                    }, label: {
                        Image("flip.camera")
                            .scaleEffect(0.9)
                            .padding(.bottom)
                    })
                }
                .padding(10)
                .shadow(radius: 2)
                .cornerRadius(15)
            }
            .padding()
            Spacer()
            Button(action: {
                vm.resetZoom()
            }, label: {
                ZStack{
                    Circle()
                        .stroke(lineWidth: 1)
                        .fill(Color.white)
                        .frame(width: 35, height: 35)
                    Text(String(format: "%.1f", vm.zoomFactor))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                }
            })
            .padding(.bottom)
            
            HStack{
                Button(action: {
                    // ignore
                }) {
                    Circle()
                        .stroke((vm.isRecording ? .red.opacity(0.5) : .white), lineWidth: 7)
                        .shadow(radius: 2)
                        .frame(width: 75, height: 75)
                }
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
