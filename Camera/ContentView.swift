//
//  ContentView.swift
//  Camera
//
//  Created by Patryk Maciąg on 24/06/2023.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var previewProvider = PreviewManager()
    var body: some View {
        VStack {
            FrameView(image: previewProvider.image)
        }
        .padding()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
