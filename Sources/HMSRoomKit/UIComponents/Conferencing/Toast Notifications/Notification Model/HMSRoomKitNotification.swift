//
//  HMSRoomKitNotification.swift
//  HMSSDK
//
//  Created by Pawan Dixit on 28/08/2023.
//  Copyright © 2023 100ms. All rights reserved.
//

import Foundation
import HMSSDK

struct HMSRoomKitNotification: Identifiable, Hashable {

    let id: String
    let type: `Type`
    let actor: String
    let isDismissible: Bool
    var title: String
    var isDismissed = false
    
    var action: Action {
        switch type {
        case .handRaised(let canBringOnStage):
            return canBringOnStage ? Action.bringOnStage : Action.none
        case .declineRoleChange:
            return  Action.none
        case .handRaisedGrouped(_):
            return  Action.viewBringOnStageParticipants
        case .error(icon: _, retry: let retry, isTerminal: let isTerminal):
            return isTerminal ? .endCall : retry ? Action.retry : Action.none
        case .info(icon: _):
            return .none
        case .screenShare:
            return .stopScreenShare
        case .groupedDeclineRoleChange(_):
            return .none
        case .poll(type: let type):
            return .vote(type: type)
        case .warning:
            return Action.none
        case .closedCaptionStatus:
            return Action.none
        }
    }
    
    enum `Type`: Hashable, Equatable {
        
        // Hand Raised
        case handRaised(canBringOnStage: Bool)
        case handRaisedGrouped(ids: [String])
        
        // Role change declined
        case declineRoleChange
        case groupedDeclineRoleChange(ids: [String])
        
        // Errors
        case error(icon: String, retry: Bool, isTerminal: Bool)
        case info(icon: String)
        case warning(icon: String)
        
        // Screen share
        case screenShare
        
        // Poll, quiz
        case poll(type: HMSPollCategory)
        
        // Closed caption
        case closedCaptionStatus(icon: String)
    }
    
    enum Action: Hashable {
        case none
        case bringOnStage
        case viewBringOnStageParticipants
        case retry
        case endCall
        case stopScreenShare
        case vote(type: HMSPollCategory)
    }
}
