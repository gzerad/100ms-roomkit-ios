//
//  HMSPrebuiltConferenceView.swift
//  HMSRoomKitPreview
//
//  Created by Pawan Dixit on 11/1/23.
//

import SwiftUI
import HMSRoomModels
import HMSSDK

extension [PollVoteViewModel]: Identifiable {
    public var id: Int {
        self.count
    }
}

struct HMSPrebuiltConferenceView: View {
    
    @Environment(\.pollsOptionAppearance) var pollsOptionAppearance
    
    @EnvironmentObject var roomModel: HMSRoomModel
    @EnvironmentObject var roomInfoModel: HMSRoomInfoModel
    @StateObject var roomKitModel = HMSRoomKitModel()
    
    @EnvironmentObject var pollModel: HMSRoomKitPollModel
    
    @State var pollVoteViewModel: PollVoteViewModel? = nil
    @State var pollCreateModel: PollCreateModel? = nil
    
    @State var pollVoteViewModels: [PollVoteViewModel]? = nil
    
    var body: some View {
        ZStack {
            HMSConferenceScreen {
                switch roomInfoModel.conferencingType {
                case .default:
                    return .default { screen in
                        if let defaultScreen = roomInfoModel.defaultConferencingScreen {
                            
                            if let chat = defaultScreen.elements?.chat {
                                screen.chat = .init(initialState: chat.initial_state == .CHAT_STATE_OPEN ? .open : .close, isOverlay: chat.is_overlay , allowsPinningMessages: chat.allow_pinning_messages )
                            }
                            else {
                                screen.chat = nil
                            }
                            
                            if let tileLayout = defaultScreen.elements?.video_tile_layout?.grid {
                                screen.tileLayout = .init(grid: .init(isLocalTileInsetEnabled: tileLayout.enable_local_tile_inset , prominentRoles: tileLayout.prominent_roles , canSpotlightParticipant: tileLayout.enable_spotlighting_peer ))
                            }
                            else {
                                screen.tileLayout = nil
                            }
                            
                            if let on_stage_exp = defaultScreen.elements?.on_stage_exp {
                                screen.onStageExperience = .init(onStageRoleName: on_stage_exp.on_stage_role, rolesWhoCanComeOnStage: on_stage_exp.off_stage_roles, bringToStageLabel: on_stage_exp.bring_to_stage_label, removeFromStageLabel: on_stage_exp.remove_from_stage_label)
                            }
                            else {
                                screen.onStageExperience = nil
                            }
                            
                            if (defaultScreen.elements?.brb) != nil {
                                screen.brb = .init()
                            }
                            else {
                                screen.brb = nil
                            }
                            
                            if (defaultScreen.elements?.participant_list) != nil {
                                screen.participantList = .init()
                            }
                            else {
                                screen.participantList = nil
                            }
                        }
                    }
                case .liveStreaming:
                    return .liveStreaming { screen in
                        if let defaultScreen = roomInfoModel.liveStreamingConferencingScreen {
                            
                            if let chat = defaultScreen.elements?.chat {
                                screen.chat = .init(initialState: chat.initial_state == .CHAT_STATE_OPEN ? .open : .close, isOverlay: chat.is_overlay , allowsPinningMessages: chat.allow_pinning_messages )
                            }
                            else {
                                screen.chat = nil
                            }
                            
                            if let tileLayout = defaultScreen.elements?.video_tile_layout?.grid {
                                screen.tileLayout = .init(grid: .init(isLocalTileInsetEnabled: tileLayout.enable_local_tile_inset , prominentRoles: tileLayout.prominent_roles , canSpotlightParticipant: tileLayout.enable_spotlighting_peer ))
                            }
                            else {
                                screen.tileLayout = nil
                            }
                            
                            if let on_stage_exp = defaultScreen.elements?.on_stage_exp {
                                screen.onStageExperience = .init(onStageRoleName: on_stage_exp.on_stage_role, rolesWhoCanComeOnStage: on_stage_exp.off_stage_roles, bringToStageLabel: on_stage_exp.bring_to_stage_label, removeFromStageLabel: on_stage_exp.remove_from_stage_label)
                            }
                            else {
                                screen.onStageExperience = nil
                            }
                            
                            if (defaultScreen.elements?.brb) != nil {
                                screen.brb = .init()
                            }
                            else {
                                screen.brb = nil
                            }
                            
                            if (defaultScreen.elements?.participant_list) != nil {
                                screen.participantList = .init()
                            }
                            else {
                                screen.participantList = nil
                            }
                        }
                    }
                }
            }
            .environmentObject(roomKitModel)
            .onAppear() {
                UIApplication.shared.isIdleTimerDisabled = true
            }
#if !Preview
            .onChange(of: pollModel.currentPolls) { currentPolls in
                
                let existingPollNotificationIds = roomKitModel.notifications.filter {
                    if case .poll(_) = $0.type {
                        return true
                    }
                    else {
                        return false
                    }
                }.map{$0.id}
                
                let newPolls = currentPolls.filter{!existingPollNotificationIds.contains($0.pollID)}
                let pollsThatAreStopped = existingPollNotificationIds.filter{!currentPolls.map{$0.pollID}.contains($0)}
                
                // Remove notification for peers who have lowered their hands
                roomKitModel.removeNotification(for: pollsThatAreStopped)
                
                guard (roomModel.userRole?.permissions.pollRead ?? false) || (roomModel.userRole?.permissions.pollWrite ?? false) else { return }
                
                pollsOptionAppearance.containsItems.wrappedValue = currentPolls.count > 0
                
                // add notification for each new peer
                for newPoll in newPolls {
                    let notification = HMSRoomKitNotification(id: newPoll.pollID, type: .poll(type: newPoll.category), actor: newPoll.createdBy?.name ?? "", isDismissible: true, title: "\(newPoll.createdBy?.name ?? "") started a new \(newPoll.category == .poll ? "poll": "quiz")")
                    roomKitModel.addNotification(notification)
                    
                    pollsOptionAppearance.badgeState.wrappedValue = .badged
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .init(rawValue: "poll-vote"))) { notification in
                let center = roomModel.interactivityCenter
                guard let pollIdOfInterest: String = notification.object as? String else { return }
                if let poll = center.polls.first(where: { $0.pollID == pollIdOfInterest }), let role = roomModel.localPeerModel?.peer.role {
                    
                    pollVoteViewModel = PollVoteViewModel(poll: poll, interactivityCenter: center, currentRole: role, peerList: roomModel.room?.peers ?? [])
                    
                    roomKitModel.dismissNotification(for: pollIdOfInterest)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .init(rawValue: "poll-create"))) { _ in
                let center = roomModel.interactivityCenter
                if let role = roomModel.localPeerModel?.role {
                    pollCreateModel = PollCreateModel(interactivityCenter: center, limitViewResultsToRoles: [role], currentRole: role)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .init(rawValue: "poll-view"))) { _ in
                let center = roomModel.interactivityCenter
//                guard let pollIdOfInterest: String = pollModel.currentPolls as? String else { return }
                if let role = roomModel.localPeerModel?.peer.role {
                    
                    pollVoteViewModels = nil
                    
                    pollVoteViewModels = pollModel.currentPolls.map { poll in
                        PollVoteViewModel(poll: poll, interactivityCenter: center, currentRole: role, peerList: roomModel.room?.peers ?? [])
                    }
                }
            }
            .sheet(item: $pollVoteViewModel, content: { model in
                PollVoteView(model: model)
            })
            .sheet(item: $pollCreateModel, content: { model in
                PollCreateView(model: model)
            })
            .sheet(item: $pollVoteViewModels, content: { models in
                ScrollView {
                    ForEach(models) { model in
                        PollVoteView(model: model)
                    }
                    .padding(.bottom, 30)
                }
                .background(HMSUIColorTheme().surfaceDefault)
                .ignoresSafeArea()
            })
#endif
            if !roomModel.roleChangeRequests.isEmpty {
                HMSPreviewRoleScreen()
            }
        }
    }
}

struct HMSPrebuiltConferenceView_Previews: PreviewProvider {
    static var previews: some View {
#if Preview
        HMSPrebuiltConferenceView()
            .environmentObject(HMSRoomModel.dummyRoom(3))
#endif
    }
}
