//
//  HMSLoadMoreButton.swift
//  HMSRoomKit
//
//  Created by Dmitry Fedoseyev on 16.08.2023.
//  Copyright © 2023 100ms. All rights reserved.
//

import SwiftUI

struct HMSLoadMoreButton: View {
    var body: some View {
        HStack(spacing: 0) {
            Image(assetName: "add-circle")
                .foreground(.onSecondaryHigh)
            Text("View More")
                .font(.captionSemibold)
                .foreground(.onSecondaryHigh)
                .padding(.horizontal, 8)
        }
        .padding(8)
        .background(.secondaryDefault, cornerRadius: 20)
    }
}

struct HMSLoadMoreButton_Previews: PreviewProvider {
    static var previews: some View {
        HMSLoadMoreButton().background(.black).environmentObject(HMSUITheme())
    }
}
