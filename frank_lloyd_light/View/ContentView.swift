//
//  ContentView.swift
//  frank_lloyd_light
//
//  Created by 中山智輝 on 2025/11/20.
//

import SwiftUI

struct ContentView: View {
    @State var number = 0
    var body: some View {
        VStack {
            MapView()
                .frame(height: 300)
            CircleImage()
                .offset(y: -130)
                .padding(.bottom, -130)
             
                VStack(alignment: .leading) {
                    Text("Flrank Loyd Light")
                        .font(.title)
                    HStack {
                        Text("Well Known Architecture")
                            .font(.subheadline)
                        Spacer()
                        Text("U.S.A").font(.subheadline)
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    
                    Divider()
                    
                    Text("About Flrank Loyd Light")
                        .font(.title2)
                    Text("He built lots of beatiful building all over the world.")
                }
                .padding()
                Spacer()
        }
    }
}

#Preview {
    ContentView()
}
