//
//  HMSParticipantsListView.swift
//  HMSRoomKit
//
//  Created by Pawan Dixit on 07/06/2023.
//  Copyright © 2023 100ms. All rights reserved.
//

import SwiftUI

import HMSSDK
import Combine
import HMSRoomModels

@MainActor
class PeerSectionViewModel: ObservableObject, Identifiable {
    static let initialFetchLimit = 5
    static let viewAllFetchLimit = 40
    
    private var iterator: HMSObservablePeerListIterator?
    private var cancallables: Set<AnyCancellable> = []
    var isOnDemand: Bool {
        iterator != nil
    }
     
    typealias ID = String
    nonisolated var id: String {
        name
    }
    
    let name: String
    var count: Int {
        iterator?.totalCount ?? peers.count
    }
    
    var shouldShowViewAll: Bool {
        count > PeerSectionViewModel.initialFetchLimit && isOnDemand && !isInfiniteScrollEnabled
    }
    
    @Published var peers: [PeerViewModel]
    @Published private(set) var hasNext: Bool = false
    @Published private(set) var isLoading: Bool = false
    
    let isInfiniteScrollEnabled: Bool
    
    internal init(name: String) {
        self.name = name
        self.peers = []
        self.isInfiniteScrollEnabled = false
    }
    
    internal init(name: String, iterator: HMSObservablePeerListIterator, isInfiniteScrollEnabled: Bool = false) {
        self.name = name
        self.iterator = iterator
        self.hasNext = true
        self.peers = []
        self.isInfiniteScrollEnabled = isInfiniteScrollEnabled
        
        iterator.$hasNext.assign(to: \.hasNext, on: self).store(in: &cancallables)
        iterator.$isLoading.assign(to: \.isLoading, on: self).store(in: &cancallables)
        
        iterator.$peers.sink { newValue in
            self.peers = newValue.map { PeerViewModel(peerModel: $0, onDemandEntry: true) }
            if !self.shouldShowViewAll {
                self.peers.last?.isLast = true
            }
        }.store(in: &cancallables)
    }
    
    func loadNext() async throws {
        guard isLoading == false && hasNext else { return }
        try await iterator?.loadNext()
    }

}

class PeerViewModel: ObservableObject, Identifiable {
    internal init(peerModel: HMSPeerModel, onDemandEntry: Bool = false) {
        self.peerModel = peerModel
    }
    
    typealias ID = String
    var id: String {
        peerModel.id + (raisedHandEntry ? "raised" : "") + (onDemandEntry ? "onDemand" : "")
    }
    
    var raisedHandEntry = false
    var onDemandEntry = false
    var peerModel: HMSPeerModel
    var isLast = false
    var justJoined = false
}

@MainActor
class HMSParticipantListViewModel {
    static let commonSortOrderMap = [handRaisedSectionName.lowercased(), "host", "guest", "teacher", "student", "viewer"].enumerated().reduce(into: [String: Int]()) {
        $0[$1.1] = $1.0
    }
    
    static let handRaisedSectionName = "Hand Raised"
    
    static func makeDynamicSectionedPeers(from peers: [HMSPeerModel], searchQuery: String) -> [PeerSectionViewModel] {

        let handRaisedSection = PeerSectionViewModel(name: handRaisedSectionName)
        let roleSectionMap = [handRaisedSectionName: handRaisedSection]
        
        var peerMap = [handRaisedSectionName : [PeerViewModel]()]
        
        peers.forEach { peer in
            if !searchQuery.isEmpty, !peer.name.lowercased().contains(searchQuery.lowercased()) {
                return
            }
                
            if peer.status == .handRaised {
                let model = PeerViewModel(peerModel: peer)
                model.raisedHandEntry = true
                peerMap[handRaisedSectionName]?.append(model)
            }
        }
        
        roleSectionMap.forEach { (key: String, value: PeerSectionViewModel) in
            value.peers = peerMap[value.name] ?? []
            value.peers.last?.isLast = true
        }
        
        return Array(roleSectionMap.values).filter { $0.count > 0 }
    }
    
    static func makeSectionedPeers(from peers: [HMSPeerModel], roles: [RoleType], offStageRoles: [String], searchQuery: String) -> [PeerSectionViewModel] {
        
        let roleSectionMap = roles.reduce(into: [String: PeerSectionViewModel]()) {
            let newSection = PeerSectionViewModel(name: $1.name)
            $0[$1.name] = newSection
        }
        
        var peerMap = roles.reduce(into: [String: [PeerViewModel]]()) {
            $0[$1.name] = [PeerViewModel]()
        }
        
        peers.forEach { peer in
            if !searchQuery.isEmpty, !peer.name.lowercased().contains(searchQuery.lowercased()) {
                return
            }
            
            guard let roleName = peer.role?.name else { return }
            peerMap[roleName]?.append(PeerViewModel(peerModel: peer))
        }
        
        roleSectionMap.forEach { (key: String, value: PeerSectionViewModel) in
            value.peers = peerMap[value.name] ?? []
            value.peers.last?.isLast = true
        }
        
        return Array(roleSectionMap.values).filter { $0.count > 0 && !offStageRoles.contains($0.name) }
            .sorted {
                let firstOrder = commonSortOrderMap[$0.name.lowercased()] ?? Int.max
                let secondOrder = commonSortOrderMap[$1.name.lowercased()] ?? Int.max
                if firstOrder != secondOrder {
                    return firstOrder < secondOrder
                } else {
                    return $0.name < $1.name
                }
            }
    }
}

struct HMSParticipantRoleListView: View {
    @EnvironmentObject var roomModel: HMSRoomModel
    @EnvironmentObject var roomInfoModel: HMSRoomInfoModel
    @Environment(\.dismiss) var dismiss
    var roleName: String
    
    @State var iterator: HMSObservablePeerListIterator
     
    
    var body: some View {
        VStack(spacing: 16) {
            HMSOptionsHeaderView(title: "Participant List", showsBackButton: true, onClose: {
                dismiss()
            }, onBack: {
                dismiss()
            })
            ScrollView {
                LazyVStack(spacing: 0) {
                    let roleName = iterator.options.filterByRoleName ?? ""
                    let model = PeerSectionViewModel(name: roleName, iterator: iterator, isInfiniteScrollEnabled: true)
                    ParticipantSectionView(model: model, isExpanded: true) {}
                    Spacer().frame(height: 16)
                }
            }
        }
        .padding(.horizontal, 16)
        .background(.surfaceDim, cornerRadius: 0, ignoringEdges: .all)
        .navigationBarHidden(true)
        .onAppear() {
            Task {
                try await iterator.loadNext()
            }
        }
    }
    

}

struct HMSParticipantListView: View {
    @EnvironmentObject var roomModel: HMSRoomModel
    @EnvironmentObject var roomInfoModel: HMSRoomInfoModel
    @State private var searchText: String = ""
    @State private var iterators = [HMSObservablePeerListIterator]()
    @State private var expandedRoleName = ""
    
    private let timer = Timer.publish(every: 5, on: .main, in: .common).autoconnect()
    
    private func refreshIterators() async throws {
        guard roomModel.isLarge else { return }
        let newIterators = roomInfoModel.offStageRoles.map { roomModel.getIterator(for: $0, limit: PeerSectionViewModel.initialFetchLimit) }
        await withThrowingTaskGroup(of: Void.self) { group in
            for iterator in newIterators {
                group.addTask { try await iterator.loadNext() }
            }
        }
             
        iterators = newIterators.filter { !$0.peers.isEmpty }
    }
    
    private func toggleExpanded(_ name: String) {
        expandedRoleName = expandedRoleName == name ? "" : name
    }
    
    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 8) {
                HMSSearchField(searchText: $searchText, placeholder: "Search for participants")
            }
            ScrollView {
                LazyVStack(spacing: 0) {
                    let dynamicSections = HMSParticipantListViewModel.makeDynamicSectionedPeers(from: roomModel.remotePeersWithRaisedHand, searchQuery: searchText)
                    ForEach(dynamicSections) { peerSectionModel in
                        ParticipantSectionView(model: peerSectionModel, isExpanded: expandedRoleName == peerSectionModel.name) {
                            toggleExpanded(peerSectionModel.name)
                        }
                        Spacer().frame(height: 16)
                    }
                    
                    let sections = HMSParticipantListViewModel.makeSectionedPeers(from: roomModel.peerModels, roles: roomModel.roles, offStageRoles: roomModel.isLarge ? roomInfoModel.offStageRoles : [], searchQuery: searchText)
                    ForEach(sections) { peerSectionModel in
                        ParticipantSectionView(model: peerSectionModel, isExpanded: expandedRoleName == peerSectionModel.name) {
                            toggleExpanded(peerSectionModel.name)
                        }
                        Spacer().frame(height: 16)
                    }
                    
                    if searchText.isEmpty {
                        ForEach(iterators, id: \.options.filterByRoleName) { iterator in
                            let roleName = iterator.options.filterByRoleName ?? ""
                            let model = PeerSectionViewModel(name: roleName, iterator: iterator)
                            ParticipantSectionView(model: model,isExpanded: expandedRoleName == roleName) {
                                toggleExpanded(roleName)
                            }
                            Spacer().frame(height: 16)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .background(.surfaceDim, cornerRadius: 0, ignoringEdges: .all)
        .onReceive(timer) { timer in
            Task {
                try await refreshIterators()
            }
        }
        .onAppear() {
            Task {
                try await refreshIterators()
            }
        }
    }
}

struct ParticipantSectionView: View {
    @ObservedObject var model: PeerSectionViewModel
    @EnvironmentObject var currentTheme: HMSUITheme
    @EnvironmentObject var roomModel: HMSRoomModel
    
    var isExpanded: Bool
    var toggleExpanded: (()->Void)
    
    var body: some View {
        ParticipantItemHeader(name: "\(model.name.capitalized) (\(model.count))", isExpanded: isExpanded, toggleExpanded: toggleExpanded, isExpandEnabled: !model.isInfiniteScrollEnabled)
        if isExpanded {
            ForEach(model.peers) { peer in
                ParticipantItem(model: peer, wrappedModel: peer.peerModel, isLast: peer.isLast && !model.hasNext).onAppear {
                    guard peer.isLast && model.isInfiniteScrollEnabled else { return }
                    Task {
                        try await model.loadNext()
                    }
                }
            }
            if model.shouldShowViewAll {
                HMSDivider(color: currentTheme.colorTheme.borderDefault)
                HStack {
                    Spacer()
                    NavigationLink {
                        HMSParticipantRoleListView(roleName: model.name, iterator: roomModel.getIterator(for: model.name, limit: PeerSectionViewModel.viewAllFetchLimit))
                    } label: {
                        HStack {
                            Text("View All").font(.body2Regular14).foreground(.onSurfaceHigh)
                            Image(assetName: "back").foreground(.onSurfaceHigh)
                                .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                        }
                    }
                }.padding(EdgeInsets(top: 17, leading: 16, bottom: 17, trailing: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(currentTheme.colorTheme.borderBright, lineWidth: 1).padding(EdgeInsets(top: -8, leading: 0, bottom: 0, trailing: 0))
                    ).clipped()
            } else if model.hasNext {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }.padding(EdgeInsets(top: 17, leading: 16, bottom: 17, trailing: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(currentTheme.colorTheme.borderBright, lineWidth: 1).padding(EdgeInsets(top: -8, leading: 0, bottom: 0, trailing: 0))
                    ).clipped()
            }
        }
            
    }
}

struct ParticipantItemHeader: View {
    @EnvironmentObject var currentTheme: HMSUITheme
    var name: String
    var isExpanded: Bool
    var toggleExpanded: (()->Void)
    var isExpandEnabled: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                Text(name).font(.subtitle2Semibold14).foreground(.onSurfaceMedium).padding(.vertical, 14)
                Spacer()
                if isExpandEnabled {
                    Image(assetName: "chevron-up")
                        .foreground(.onSurfaceHigh)
                        .rotation3DEffect(.degrees(180), axis: (x: !isExpanded ? 1 : 0, y: 0, z: 0))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 8)
                }
            }
            .padding(.horizontal, 16)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(currentTheme.colorTheme.borderBright, lineWidth: 1).padding(EdgeInsets(top: 0, leading: 0, bottom: isExpanded ? -8 : 0, trailing: 0))
            )
            HMSDivider(color: currentTheme.colorTheme.borderDefault).opacity(isExpanded ? 1 : 0)
        }.clipped().onTapGesture {
            guard isExpandEnabled else { return }
            toggleExpanded()
        }
    }
}


struct ParticipantItem: View {
    @EnvironmentObject var currentTheme: HMSUITheme
    @EnvironmentObject var roomModel: HMSRoomModel
    @ObservedObject var model: PeerViewModel
    @ObservedObject var wrappedModel: HMSPeerModel
    
    var isLast: Bool
    
    @State var isPresented = false
    @State var menuAction: HMSPeerOptionsViewContext.Action = .none
    
    var body: some View {
        HStack(spacing: 16) {
            HStack(spacing: 0) {
                Text(model.peerModel.name).font(.subtitle2Semibold14).lineLimit(1)
                    .truncationMode(.tail).foreground(.onSurfaceHigh)
            }
            Spacer()
           
            HStack(spacing: 16) {
                if wrappedModel.status == .handRaised {
                    Circle()
                        .foreground(.secondaryDim)
                        .overlay {
                            Image(assetName: "hand-raise-icon").renderingMode(.original).resizable().aspectRatio(contentMode: .fit).frame(width: 18, height: 18)}.frame(width: 24, height: 24)
                }
                if let model = wrappedModel.regularAudioTrackModel {
                    HMSAudioTrackView(trackModel: model, style: .list)
                        .environmentObject(self.model.peerModel)
                }
                HMSWifiSignalView(level: wrappedModel.displayQuality, style: .list)
                
                HMSPeerOptionsButtonView(peerModel: model.peerModel) {
                    Image(assetName: "vertical-ellipsis")
                        .foreground(.onSurfaceHigh)
                        .padding(EdgeInsets(top: 3, leading: 10, bottom: 3, trailing: 10))
                }
            }
        }
        .padding(EdgeInsets(top: 17, leading: 16, bottom: 17, trailing: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(currentTheme.colorTheme.borderBright, lineWidth: 1).padding(EdgeInsets(top: -8, leading: 0, bottom: isLast ? 0 : -8, trailing: 0))
        ).clipped()
    }
}

struct HMSSearchField: View {
    enum Style {
    case light
    case dark
    }
    
    @EnvironmentObject var currentTheme: HMSUITheme
    @Binding var searchText: String
    var placeholder: String
    var style: Style = .light
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foreground(.onSurfaceMedium)
            TextField("", text: $searchText, prompt: Text(placeholder))
                .foreground(.onSurfaceMedium)
                .font(.body2Regular14)
        }
        .padding(.horizontal, 16)
        .frame(height: 40)
        .background(style == .light ? .surfaceDefault : .surfaceDim, cornerRadius: 8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(style == .light ? currentTheme.colorTheme.borderDefault : currentTheme.colorTheme.borderBright, lineWidth: 1)
        );
    }
}

struct HMSParticipantListView_Previews: PreviewProvider {
    static var previews: some View {
#if Preview
        HMSParticipantListView()
            .environmentObject(HMSUITheme())
            .environmentObject(HMSRoomModel.dummyRoom(5))
            .environmentObject(HMSRoomInfoModel())
#endif
    }
}

extension HMSPeerModel {
    func popoverContext(roomModel: HMSRoomModel, conferenceParams: HMSConferenceScreen.DefaultType, isPresented: Binding<Bool>, menuAction: Binding<HMSPeerOptionsViewContext.Action>) -> HMSPeerOptionsViewContext? {
        let audioTrackModel = regularAudioTrackModel
        let regularVideoTrackModel = regularVideoTrackModel
        let isLocal = isLocal
        guard let permissions = roomModel.localPeerModel?.role?.permissions else {
            return nil
        }
        
        let currentRole = role?.name ?? ""
        
        let onStageExperience = conferenceParams.onStageExperience
        let onStageRoleName = onStageExperience?.onStageRoleName ?? ""
        let rolesWhoCanComeOnStage = onStageExperience?.rolesWhoCanComeOnStage ?? []
        let bringToStageLabel = onStageExperience?.bringToStageLabel ?? ""
        let removeFromStageLabel = onStageExperience?.removeFromStageLabel ?? ""
        
        let isOnStage = onStageRoleName == currentRole
        let isOffStage = rolesWhoCanComeOnStage.contains(currentRole)
        
        var actions = [HMSPeerOptionsViewContext.Action]()
        
        if !isLocal {
            if isOffStage && onStageExperience != nil {
                actions.append(.bringOnStage(bringToStageLabel))
            } else if onStageExperience != nil && isOnStage {
                actions.append(.removeFromStage(removeFromStageLabel))
            }
        }
        
        let hasAudioTrack = audioTrackModel != nil
        let hasVideoTrack = regularVideoTrackModel != nil
        
        if hasVideoTrack || hasAudioTrack {
            actions.append(.pin(self))
            actions.append(.spotlight(self))
        }
        
        if isLocal {
            actions.append(.changeName)
            actions.append(.minimizeTile)
        } else {
            let canMute = permissions.mute == true
            if canMute {
                if hasAudioTrack {
                    let isAudioMute = audioTrackModel?.isMute == true
                    actions.append(.audioMuteToggle(isAudioMute))
                }
                
                if hasVideoTrack {
                    let isVideoMute = regularVideoTrackModel?.isMute == true
                    actions.append(.videoMuteToggle(isVideoMute))
                }
            }
            
            if hasAudioTrack {
                actions.append(.volume)
            }
            
            let canRemoveOthers = permissions.removeOthers == true
            if canRemoveOthers {
                actions.append(.removeParticipant)
            }
        }
        
        return HMSPeerOptionsViewContext(isPresented: isPresented, action: menuAction, name: name + (isLocal ? " (You)" : ""), role: role?.name.capitalized ?? "", actions: actions)
    }
}
