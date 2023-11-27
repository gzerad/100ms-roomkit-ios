//
//  HMSChatView.swift
//  HMSRoomKit
//
//  Created by Pawan Dixit on 07/06/2023.
//  Copyright © 2023 100ms. All rights reserved.
//

import SwiftUI
import HMSSDK
import HMSRoomModels

struct HMSChatScreen: View {
    
    @Environment(\.conferenceParams) var conferenceParams
    
    @EnvironmentObject var currentTheme: HMSUITheme
    @EnvironmentObject var roomModel: HMSRoomModel
    
    @State var recipient: HMSRecipient?
    var isTransparentMode: Bool = false
    
    var body: some View {
        
        if isTransparentMode {
            chatView
        }
        else {
            chatView
                .padding(.horizontal, 16)
                .background(.surfaceDim, cornerRadius: 0, ignoringEdges: .all)
        }
    }
    
    var chatView: some View {
        
        let chatScopes = conferenceParams.chat?.chatScopes
        
        var allowedRoles: [HMSRole] {
            
            if let chatScopes = chatScopes {
                if let roleScope = chatScopes.first(where: { scope in
                    switch scope {
                    case .roles(_):
                        return true
                    default:
                        return false
                    }
                }) {
                    if case let .roles(whiteList: whiteListedRoles) = roleScope {
                        return roomModel.roles.filter{whiteListedRoles.contains($0.name)}
                    }
                }
            }
            
            // by default no roles are allowed
            return []
        }
        
        return VStack(alignment: .leading, spacing: 16) {
            
            chatListView
            
            if let chatScopes {
                sendMessageView
                    .onAppear() {
                        if chatScopes.contains(.public) {
                            recipient = .everyone
                        }
                        else if let firstWhiteListedRole = allowedRoles.first {
                            recipient = .role(firstWhiteListedRole)
                        }
                        else {
                            recipient = .peer(nil)
                        }
                    }
            }
        }
    }
    
    var chatListView: some View {
        
        let messages =  roomModel.messages
        
        return ZStack {
            if messages.isEmpty {
                HMSChatPlaceholderView()
            }
            HMSChatListView(recipient: $recipient, isTransparentMode: isTransparentMode)
        }
    }
    
    var sendMessageView: some View {
        VStack {
            if let recipient {
                
                VStack(alignment: .leading, spacing: 8) {
                    
                    HStack {
                        Text("To")
                            .foreground(.onSurfaceMedium)
                            .font(.captionRegular12)
                        HMSRolePicker(recipient: Binding(get: {
                            recipient
                        }, set: {
                            self.recipient = $0
                        }))
                    }
                    
                    HMSSendChatField(recipient: recipient)
                        .background(.surfaceDefault, cornerRadius: 8)
                }
                .padding(.bottom, 16)
            }
        }
    }
}

struct HMSChatView_Previews: PreviewProvider {
    static var previews: some View {
#if Preview
        VStack {
            HMSChatScreen()
                .environmentObject(HMSUITheme())
                .environmentObject(HMSRoomModel.dummyRoom(3))
            
            HMSChatScreen(isTransparentMode: true)
                .environmentObject(HMSUITheme())
                .environmentObject(HMSRoomModel.dummyRoom(3))
            
        }
#endif
    }
}
