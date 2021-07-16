//
//  RoomManager.swift
//  LiveKtv
//
//  Created by XC on 2021/6/8.
//

import Core
import Foundation
import RxSwift

class RoomManager: NSObject {
    fileprivate static var instance: RoomManager?
    private static var lock = os_unfair_lock()
    static func shared() -> IRoomManager {
        os_unfair_lock_lock(&RoomManager.lock)
        if instance == nil {
            instance = RoomManager()
        }
        os_unfair_lock_unlock(&RoomManager.lock)
        return instance!
    }

    var account: User?
    var member: LiveKtvMember?
    var setting: LocalSetting = AppDataManager.getSetting() ?? LocalSetting()
    var room: LiveKtvRoom?
    private var rtcServer = RtcServer()
    private var scheduler = SerialDispatchQueueScheduler(internalSerialQueueName: "rtc")
}

extension RoomManager: IRoomManager {
    var playingMusic: LocalMusic? {
        return rtcServer.playingMusic
    }

    func destory() {
        RoomManager.instance = nil
    }

    func updateSetting() {
        if rtcServer.isJoinChannel {
            rtcServer.setClientRole(rtcServer.role!, setting.audienceLatency)
        }
    }

    func getAccount() -> Observable<Result<User>> {
        if account == nil {
            let user = AppDataManager.getAccount()
            if user != nil {
                return User.getUser(by: user!.id).map { result in
                    if result.success {
                        self.account = result.data!
                    }
                    return result
                }
            } else {
                return User.randomUser().flatMap { result in
                    result.onSuccess {
                        self.account = result.data!
                        return AppDataManager.saveAccount(user: result.data!)
                    }
                }
            }
        } else {
            return Observable.just(Result(success: true, data: account))
        }
    }

    func getRooms() -> Observable<Result<[LiveKtvRoom]>> {
        return LiveKtvRoom.getRooms()
    }

    func create(room: LiveKtvRoom) -> Observable<Result<LiveKtvRoom>> {
        if let user = account {
            room.userId = user.id
            return LiveKtvRoom.create(room: room)
                .map { result in
                    if result.success {
                        room.id = result.data!
                        room.createdAt = Date()
                        return Result(success: true, data: room)
                    } else {
                        return Result(success: false, message: result.message)
                    }
                }
        } else {
            return Observable.just(Result(success: false, message: "account is nil!"))
        }
    }

    func join(room: LiveKtvRoom) -> Observable<Result<LiveKtvRoom>> {
        if let user = account {
            if member == nil {
                member = LiveKtvMember(id: "", isMuted: false, isSelfMuted: false, role: LiveKtvRoomRole.listener.rawValue, roomId: room.id, streamId: 0, userId: user.id)
            }
            guard let member = member else {
                return Observable.just(Result(success: false, message: "member is nil!"))
            }
            if rtcServer.channel == room.id {
                return Observable.just(Result(success: true, data: room))
            } else {
                return Observable.just(rtcServer.isJoinChannel)
                    .concatMap { joining -> Observable<Result<Void>> in
                        if joining {
                            return self.leave()
                        } else {
                            return Observable.just(Result(success: true))
                        }
                    }
                    .concatMap { result -> Observable<Result<Void>> in
                        result.onSuccess {
                            // set default status when join room
                            member.isMuted = false
                            member.role = room.userId == user.id ? LiveKtvRoomRole.manager.rawValue : LiveKtvRoomRole.listener.rawValue
                            member.isManager = room.userId == user.id
                            member.isSelfMuted = false
                            // member.room = room
                            member.userId = user.id
                            return Observable.just(result)
                        }
                    }
                    .concatMap { result -> Observable<Result<LiveKtvRoom>> in
                        result.onSuccess { LiveKtvRoom.getRoom(by: room.id) }
                    }
                    .concatMap { result -> Observable<Result<Void>> in
                        result.onSuccess { member.join(room: room) }
                    }
                    .concatMap { result -> Observable<Result<Void>> in
                        result.onSuccess { self.rtcServer.joinChannel(member: member, channel: room.id, setting: self.setting) }
                    }
                    .concatMap { result -> Observable<Result<Void>> in
                        result.onSuccess { member.update(streamId: self.rtcServer.uid) }
                    }
                    .concatMap { result -> Observable<Result<LiveKtvRoom>> in
                        if result.success {
                            self.room = room
                            return Observable.just(Result(success: true, data: room))
                        } else {
                            self.member = nil
                            self.room = nil
                            if self.rtcServer.isJoinChannel {
                                return self.rtcServer.leaveChannel().map { _ in
                                    Result(success: false, message: result.message)
                                }
                            }
                            return Observable.just(Result(success: false, message: result.message))
                        }
                    }
            }
        } else {
            return Observable.just(Result(success: false, message: "account is nil!"))
        }
    }

    func leave() -> Observable<Result<Void>> {
        Logger.log(self, message: "leave", level: .info)
        if let member = member {
            if rtcServer.isJoinChannel {
                return Observable.zip(
                    rtcServer.releaseMusicPlayer(),
                    rtcServer.leaveChannel(),
                    member.leave()
                ).map { result0, result1, result2 in
                    if !result0.success || !result1.success || !result2.success {
                        Logger.log(self, message: "leaveRoom error: \(result0.message ?? "") \(result1.message ?? "") \(result2.message ?? "")", level: .error)
                    }
                    // self.member = nil
                    // self.room = nil
                    return Result(success: true)
                }
            } else {
                return Observable.just(Result(success: true))
            }
        } else {
            return Observable.just(Result(success: true))
        }
    }

    func changeRoomMV(mv: String) -> Observable<Result<Void>> {
        guard let room = room else {
            return Observable.just(Result(success: false, message: "room is nil!"))
        }
        return room.changeMV(localMV: mv)
    }

    func subscribeRoom() -> Observable<Result<LiveKtvRoom>> {
        guard let room = room else {
            return Observable.just(Result(success: false, message: "room is nil!"))
        }
        return Observable.merge([room.subscribe(), room.timeUp()])
    }

    func subscribeMembers() -> Observable<Result<[LiveKtvMember]>> {
        guard let room = room else {
            return Observable.just(Result(success: false, message: "room is nil!"))
        }
        return Observable.combineLatest(
            room.subscribeMembers(),
            rtcServer.onSpeakersChanged()
        )
        .filter { [unowned self] _ in
            self.rtcServer.isJoinChannel
        }
        .throttle(RxTimeInterval.milliseconds(20), latest: true, scheduler: scheduler)
        .map { [unowned self] args -> Result<[LiveKtvMember]> in
            let (result, _) = args
            if result.success {
                if let list = result.data {
                    // order members list
                    let managers = list.filter { member in
                        member.isManager
                    }
                    let others = list.filter { member in
                        !member.isManager
                    }
                    let list = managers + others
                    let speakers = list.filter { member in
                        member.isSpeaker()
                    }
                    if speakers.count > 8 {
                        for index in 8 ..< speakers.count {
                            speakers[index].role = LiveKtvRoomRole.listener.rawValue
                        }
                    }
                    // sync local user status
                    let findCurrentUser = list.first { member in
                        member.id == self.member?.id
                    }
                    if let me = findCurrentUser, let old = member {
                        old.isSelfMuted = me.isSelfMuted
                        old.isMuted = me.isMuted
                        old.role = me.role
                        if me.toLiveKtvRoomRole() == .listener {
                            rtcServer.stopMusic()
                        }
                        self.rtcServer.setClientRole(me.role != LiveKtvRoomRole.listener.rawValue ? .broadcaster : .audience, self.setting.audienceLatency)
                        self.rtcServer.muteLocalMicrophone(mute: me.isMuted || me.isSelfMuted)
                    }
                    return Result(success: true, data: list)
                }
            }
            return result
        }
    }

    func subscribeMusicList() -> Observable<Result<[LiveKtvMusic]>> {
        guard let room = room else {
            return Observable.just(Result(success: false, message: "room is nil!"))
        }
        return room.subscribeMusicList()
            .filter { [unowned self] _ in
                self.rtcServer.isJoinChannel
            }
            .throttle(RxTimeInterval.milliseconds(20), latest: true, scheduler: scheduler)
    }

    func play(music: LocalMusic) -> Observable<Result<Void>> {
        if rtcServer.isJoinChannel {
            return rtcServer.play(music: music)
        } else {
            return Observable.just(Result(success: true))
        }
    }

    func seekMusic(position: TimeInterval) {
        if rtcServer.isJoinChannel {
            rtcServer.seekMusic(position: position)
        }
    }

    func pauseMusic() {
        if rtcServer.isJoinChannel {
            rtcServer.pauseMusic()
        }
    }

    func resumeMusic() {
        if rtcServer.isJoinChannel {
            rtcServer.resumeMusic()
        }
    }

    func getRecordingSignalVolume() -> Float {
        return rtcServer.getRecordingSignalVolume()
    }

    func setRecordingSignalVolume(value: Float) {
        rtcServer.setRecordingSignalVolume(value: value)
    }

    func getPlayoutVolume() -> Float {
        return rtcServer.getPlayoutVolume()
    }

    func setPlayoutVolume(value: Float) {
        rtcServer.setPlayoutVolume(value: value)
    }

    func isSupportSwitchOriginMusic() -> Bool {
        return rtcServer.isSupportSwitchOriginMusic()
    }

    func originMusic(enable: Bool) {
        rtcServer.originMusic(enable: enable)
    }

    func stop(music: LiveKtvMusic) -> Observable<Result<Void>> {
        if rtcServer.isJoinChannel /* , playingMusic?.id == music.musicId */ {
            rtcServer.stopMusic()
            return music.delete()
        } else {
            return Observable.just(Result(success: true))
        }
    }

    func enable(earloop: Bool) {
        if rtcServer.isJoinChannel {
            rtcServer.enable(earloop: earloop)
        }
    }

    func isEnableEarloop() -> Bool {
        return rtcServer.isEnableEarloop
    }

    func subscribeRtcMusicState() -> Observable<Result<RtcMusicState>> {
        if rtcServer.isJoinChannel {
            return rtcServer.onRtcMusicStateChanged()
        } else {
            return Observable.just(Result(success: true))
        }
    }

    func order(musicId: String, name: String) -> Observable<Result<Void>> {
        if let member = member {
            if rtcServer.isJoinChannel {
                return member.orderMusic(id: musicId, name: name)
            }
        }
        return Observable.just(Result(success: true))
    }

    func handsUp() -> Observable<Result<Void>> {
        if let member = member, !member.isSpeaker() {
            if rtcServer.isJoinChannel {
                return member.asSpeaker()
            }
        }
        return Observable.just(Result(success: true))
    }

    func kickSpeaker(member: LiveKtvMember) -> Observable<Result<Void>> {
        if let user = self.member {
            if rtcServer.isJoinChannel, user.isManager {
                return Observable.zip(
                    member.asListener(),
                    LiveKtvMusic.delete(roomId: member.roomId, userId: member.userId)
                ).map { args in
                    let (result0, result1) = args
                    if result0.success, result1.success {
                        return result0
                    } else {
                        return result0.success ? result1 : result0
                    }
                }
            }
        }
        return Observable.just(Result(success: true))
    }

    func closeMicrophone(close: Bool) -> Observable<Result<Void>> {
        if let member = member {
            member.isSelfMuted = close
            if rtcServer.isJoinChannel {
                rtcServer.muteLocalMicrophone(mute: close)
                return member.selfMute(mute: close)
            } else {
                return Observable.just(Result(success: true))
            }
        } else {
            return Observable.just(Result(success: true))
        }
    }

    func isMicrophoneClose() -> Bool {
        return rtcServer.muted
    }
}
