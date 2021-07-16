//
//  Service.swift
//  LiveKtv
//
//  Created by XC on 2021/6/8.
//

import Core
import Foundation
import RxSwift

protocol IRoomManager {
    var account: User? { get set }
    var member: LiveKtvMember? { get set }
    var room: LiveKtvRoom? { get set }
    var setting: LocalSetting { get set }
    var playingMusic: LocalMusic? { get }
    func updateSetting()

    func getAccount() -> Observable<Result<User>>
    func getRooms() -> Observable<Result<[LiveKtvRoom]>>
    func create(room: LiveKtvRoom) -> Observable<Result<LiveKtvRoom>>
    func join(room: LiveKtvRoom) -> Observable<Result<LiveKtvRoom>>
    func leave() -> Observable<Result<Void>>

    func closeMicrophone(close: Bool) -> Observable<Result<Void>>
    func isMicrophoneClose() -> Bool

    func changeRoomMV(mv: String) -> Observable<Result<Void>>
    func subscribeRoom() -> Observable<Result<LiveKtvRoom>>
    func subscribeMembers() -> Observable<Result<[LiveKtvMember]>>

    func play(music: LocalMusic) -> Observable<Result<Void>>
    func seekMusic(position: TimeInterval)
    func pauseMusic()
    func resumeMusic()
    func stop(music: LiveKtvMusic) -> Observable<Result<Void>>

    func enable(earloop: Bool)
    func isEnableEarloop() -> Bool

    func getRecordingSignalVolume() -> Float
    func setRecordingSignalVolume(value: Float)
    func getPlayoutVolume() -> Float
    func setPlayoutVolume(value: Float)
    func isSupportSwitchOriginMusic() -> Bool
    func originMusic(enable: Bool)

    func subscribeMusicList() -> Observable<Result<[LiveKtvMusic]>>
    func subscribeRtcMusicState() -> Observable<Result<RtcMusicState>>

    func order(musicId: String, name: String) -> Observable<Result<Void>>
    func handsUp() -> Observable<Result<Void>>
    func kickSpeaker(member: LiveKtvMember) -> Observable<Result<Void>>

    func destory()
}

protocol ErrorDescription {
    associatedtype Item
    static func toErrorString(type: Item, code: Int32) -> String
}
