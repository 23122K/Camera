//
//  ContentView.swift
//  Camera
//
//  Created by Patryk Maciąg on 24/06/2023.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        ZStack{
            CameraPreviewHolder()
                .ignoresSafeArea()
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
