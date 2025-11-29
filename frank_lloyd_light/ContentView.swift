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
            Text(String(number))
            Button("Plus"){
                number = number + 1;
            }
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
