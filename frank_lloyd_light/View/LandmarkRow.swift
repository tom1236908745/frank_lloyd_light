//
//  LandmarkRow.swift
//  frank_lloyd_light
//
//  Created by 中山智輝 on 2025/11/29.
//

import SwiftUI

struct LandmarkRow: View {
    
    var landmark: Landmark
    
    
    var body: some View {
        HStack {
            Text(landmark.name)
        }
    }
}

#Preview {
    LandmarkRow(landmark: landmarks[0])
}
