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
            VStack(alignment: .leading) {
                Text("Tomoki")
                    .font(.title)
                HStack {
                    Text("App Engineer / Flutter & Swift")
                        .font(.subheadline)
                    Spacer()
                    Text("Japan").font(.subheadline)
                }
            }
            .padding()
            
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
