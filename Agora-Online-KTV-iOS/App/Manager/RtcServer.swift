//
//  RtcServer.swift
//  LiveKtv
//
//  Created by XC on 2021/6/8.
//

import AgoraRtcKit
import Core
import Foundation
import RxRelay
import RxSwift

enum RtcServerStateType {
    case join
    case error
    case members
}

class RtcMusicState {
    let uid: UInt
    let streamId: Int
    let position: Int
    let duration: Int
    let state: AgoraMediaPlayerState?

    init(uid: UInt, streamId: Int, position: Int, duration: Int, state: AgoraMediaPlayerState?) {
        self.uid = uid
        self.streamId = streamId
        self.position = position
        self.duration = duration
        self.state = state
    }
}

private struct RtcMusicLrcMessage: Encodable, Decodable {
    let msgId: Int
    let peerUid: UInt
    let cmd: String
    let lrcId: String
    let duration: Int
    let time: Int
}

private class RtcMusicPlayer: NSObject, AgoraRtcMediaPlayerAudioFrameDelegate {
    static var msgId: Int = 0
    private weak var rtcServer: RtcServer!
    var player: AgoraRtcMediaPlayerProtocol!
    var streamId: Int = -1
    var uid: UInt = 0
    var music: LocalMusic?
    var position: Int = 0
    var duration: Int = 0
    var isPlaying: Bool = false
    var state: AgoraMediaPlayerState?
    var isPause: Bool = false
    var monoChannel: Bool = false

    init(rtcServer: RtcServer) {
        self.rtcServer = rtcServer
        super.init()
        player = self.rtcServer.rtcEngine!.createMediaPlayer(with: rtcServer)!
        // player.setAudioFrameDelegate(self, mode: .readWrite)
    }

    func agoraMediaPlayer(_: AgoraRtcMediaPlayerProtocol, audioFrame: AgoraAudioPcmFrame) -> AgoraAudioPcmFrame {
        if monoChannel, audioFrame.channelNumbers == 2 {
            let cpBytes = audioFrame.bytesPerSample.rawValue
            for index in 0 ..< audioFrame.samplesPerChannel {
                let leftStart = index * 2 * cpBytes
                let rightStart = leftStart + cpBytes
                let tempBuf = audioFrame.pcmBuffer.subdata(in: leftStart ..< leftStart + cpBytes)
                audioFrame.pcmBuffer.replaceSubrange(rightStart ..< rightStart + cpBytes, with: tempBuf)
            }
        } else if audioFrame.channelNumbers == 2 {
//            let cpBytes = audioFrame.bytesPerSample.rawValue
//            for index in 0 ..< audioFrame.samplesPerChannel {
//                let leftStart = index * 2 * cpBytes
//                let rightStart = leftStart + cpBytes
//                var leftBuf = audioFrame.pcmBuffer.subdata(in: leftStart ..< leftStart + cpBytes)
//                let rightBuf = audioFrame.pcmBuffer.subdata(in: rightStart ..< rightStart + cpBytes)
//                for bufIndex in 0 ..< cpBytes / 2 {
//                    var left = UInt16(leftBuf[bufIndex * 2] << 8) + UInt16(leftBuf[bufIndex * 2 + 1])
//                    let right = UInt16(rightBuf[bufIndex * 2] << 8) + UInt16(rightBuf[bufIndex * 2 + 1])
//                    if left > UInt16.max - right {
//                        left = UInt16.max
//                    } else {
//                        left = left + right
//                    }
//                    leftBuf[bufIndex * 2] = UInt8(left >> 8)
//                    leftBuf[bufIndex * 2 + 1] = UInt8(left & 0x00FF)
//                }
//                audioFrame.pcmBuffer.replaceSubrange(leftStart ..< leftStart + cpBytes, with: leftBuf)
//                audioFrame.pcmBuffer.replaceSubrange(rightStart ..< rightStart + cpBytes, with: leftBuf)
//            }
            let cpBytes = audioFrame.bytesPerSample.rawValue
            for index in 0 ..< audioFrame.samplesPerChannel {
                let leftStart = index * 2 * cpBytes
                let rightStart = leftStart + cpBytes
                let tempBuf = audioFrame.pcmBuffer.subdata(in: rightStart ..< rightStart + cpBytes)
                audioFrame.pcmBuffer.replaceSubrange(leftStart ..< leftStart + cpBytes, with: tempBuf)
            }
        }
        return audioFrame
    }

    func play(music: LocalMusic) -> Bool {
        if let player = player, let rtc = rtcServer.rtcEngine {
            self.music = music
            if player.getPlayerState() == .playing {
                player.stop()
            }
            originMusic(enable: false)
            let option = AgoraRtcChannelMediaOptions()
            option.publishMediaPlayerId = AgoraRtcIntOptional.of(player.getMediaPlayerId())
            option.clientRoleType = AgoraRtcIntOptional.of(Int32(AgoraClientRole.broadcaster.rawValue))
            option.publishCameraTrack = AgoraRtcBoolOptional.of(false)
            option.autoSubscribeVideo = AgoraRtcBoolOptional.of(false)
            option.autoSubscribeAudio = AgoraRtcBoolOptional.of(true)
            option.publishMediaPlayerVideoTrack = AgoraRtcBoolOptional.of(false)
            option.publishCustomAudioTrack = AgoraRtcBoolOptional.of(false)
            option.publishAudioTrack = AgoraRtcBoolOptional.of(true)
            option.enableAudioRecordingOrPlayout = AgoraRtcBoolOptional.of(true)
            option.publishMediaPlayerAudioTrack = AgoraRtcBoolOptional.of(true)
            rtc.updateChannel(with: option)
            Logger.log(self, message: "open \(music.path)", level: .info)
            return player.open(music.path, startPos: 0) == 0
        } else {
            return false
        }
    }

    func getAudioTrackCount() -> Int {
        if let player = player {
            let all = player.getStreamCount()
            Logger.log(self, message: "getStreamCount \(all)", level: .info)

            if all <= 0 {
                return 0
            }
            var count = 0
            for index in 0 ..< all {
                if player.getStreamBy(Int32(index))?.streamType == .audio {
                    count += 1
                }
            }
            return count
        } else {
            return 0
        }
    }

    func originMusic(enable: Bool) {
        monoChannel = enable
        if let player = player {
            player.setAudioDualMonoMode(enable ? .mixingDuraMonoL : .mixingDuraMonoMix)
        }
    }

    func seek(position: Int) {
        if let player = player, state == .paused || state == .playing {
            player.seek(toPosition: position)
        }
    }

    func pause() {
        if let player = player {
            player.pause()
        }
    }

    func resume() {
        if let player = player {
            player.resume()
        }
    }

    func stop() {
        if let player = player {
            player.stop()
        }
        music = nil
    }

    func release() {
        stop()
        uid = 0
        if let player = player, let rtc = rtcServer.rtcEngine {
            rtc.destroyMediaPlayer(player)
        }
    }

    func sendRtcMusicState(state: RtcMusicState) {
        guard let music = music, let rtcEngine = rtcServer.rtcEngine else {
            return
        }
        if streamId == -1 {
            let config = AgoraDataStreamConfig()
            config.ordered = true
            config.syncWithAudio = true
            rtcEngine.createDataStream(&streamId, config: config)
            if streamId == -1 {
                Logger.log(self, message: "error streamId == -1", level: .error)
                return
            }
        }
        RtcMusicPlayer.msgId += 1
        let msg = RtcMusicLrcMessage(msgId: RtcMusicPlayer.msgId, peerUid: uid, cmd: "setLrcTime", lrcId: music.id, duration: state.duration, time: state.position)
        let jsonEncoder = JSONEncoder()
        do {
            let jsonData = try jsonEncoder.encode(msg)
            let code = rtcEngine.sendStreamMessage(streamId, data: jsonData)
            if code != 0 {
                Logger.log(self, message: "sendRtcMusicState error(\(code)", level: .error)
            }
        } catch {
            Logger.log(self, message: error.localizedDescription, level: .error)
        }
    }
}

class RtcServer: NSObject {
    var rtcEngine: AgoraRtcEngineKit?
    private var rtcMusicPlayer: RtcMusicPlayer?
    private let statePublisher: PublishRelay<Result<RtcServerStateType>> = PublishRelay()
    private let rtcMusicStatePublisher: PublishRelay<Result<RtcMusicState>> = PublishRelay()

    private(set) var uid: UInt = 0
    private(set) var channel: String?
    private(set) var members: [UInt] = []
    private(set) var speakers = [UInt: Bool]()
    private(set) var role: AgoraClientRole?
    private(set) var muted: Bool = false
    private(set) var isEnableBeauty: Bool = false
    private(set) var isEnableEarloop: Bool = false
    private(set) var recordingSignalVolume: Float = 100 / 400

    var isJoinChannel: Bool {
        return channel != nil && channel?.isEmpty == false
    }

    var playingMusic: LocalMusic? {
        return rtcMusicPlayer?.music
    }

    override init() {
        super.init()
        let config = AgoraRtcEngineConfig()
        config.appId = BuildConfig.AppId
        #if LEANCLOUD
            config.areaCode = AgoraAreaCode.CN.rawValue
        #endif
        #if FIREBASE
            config.areaCode = AgoraAreaCode.GLOB.rawValue
        #endif
        rtcEngine = AgoraRtcEngineKit.sharedEngine(with: config, delegate: self)
        if let engine = rtcEngine {
            engine.setChannelProfile(.liveBroadcasting)
        }
    }

    func setClientRole(_ role: AgoraClientRole, _: Bool) {
        Logger.log(message: "rtc setClientRole \(role.rawValue)", level: .info)
        if self.role == role {
            return
        }
        self.role = role
        guard let rtc = rtcEngine else {
            return
        }
        rtc.setClientRole(role)
    }

    func enable(earloop: Bool) {
        isEnableEarloop = earloop
        guard let rtc = rtcEngine else {
            return
        }
        rtc.enable(inEarMonitoring: earloop)
    }

    func joinChannel(member: LiveKtvMember, channel: String, setting: LocalSetting) -> Observable<Result<Void>> {
        guard let rtc = rtcEngine else {
            return Observable.just(Result(success: false, message: "rtcEngine is nil!"))
        }
        role = nil
        members.removeAll()
        isEnableEarloop = false
        if member.isSpeaker() {
            setClientRole(.broadcaster, setting.audienceLatency)
        } else {
            setClientRole(.audience, setting.audienceLatency)
        }
        muteLocalMicrophone(mute: member.isSelfMuted)
        rtc.enable(inEarMonitoring: isEnableEarloop)
        setRecordingSignalVolume(value: recordingSignalVolume)
        return Single.create { single in
            let option = AgoraRtcChannelMediaOptions()
            option.autoSubscribeAudio = AgoraRtcBoolOptional.of(true)
            option.autoSubscribeVideo = AgoraRtcBoolOptional.of(false)
            let code = rtc.joinChannel(byToken: BuildConfig.Token, channelId: channel, uid: 0, mediaOptions: option)
            // rtc.joinChannel(byToken: BuildConfig.Token, channelId: channel, info: nil, uid: 0)
            single(.success(code))
            return Disposables.create()
        }.asObservable().subscribe(on: MainScheduler.instance)
            .concatMap { (code: Int32) -> Observable<Result<Void>> in
                if code != 0 {
                    return Observable.just(Result(success: false, message: RtcServer.toErrorString(type: .join, code: code)))
                } else {
                    return self.statePublisher.filter { state -> Bool in
                        state.data == RtcServerStateType.join || state.data == RtcServerStateType.error
                    }.take(1).map { state -> Result<Void> in
                        Result(success: state.success, message: state.message)
                    }
                }
            }
    }

    func leaveChannel() -> Observable<Result<Void>> {
        return Single.create { [unowned self] single in
            if isJoinChannel {
                if let rtc = self.rtcEngine {
                    self.channel = nil
                    self.uid = 0
                    self.members.removeAll()
                    self.statePublisher.accept(Result(success: true, data: RtcServerStateType.members))
                    Logger.log(message: "rtc leaveChannel", level: .info)
                    let code = rtc.leaveChannel { _ in
                        single(.success(Result(success: true)))
                    }
                    if code != 0 {
                        single(.success(Result(success: false, message: "leaveChannel error code:\(code) !")))
                    }
                } else {
                    single(.success(Result(success: false, message: "rtcEngine is nil!")))
                }
            } else {
                single(.success(Result(success: true)))
            }

            return Disposables.create()
        }.asObservable()
    }

    func releaseMusicPlayer() -> Observable<Result<Void>> {
        if let player = rtcMusicPlayer {
            return Single.create { single in
                player.release()
                self.rtcMusicPlayer = nil
                single(.success(Result(success: true)))
                return Disposables.create()
            }.asObservable()
        } else {
            return Observable.just(Result(success: true))
        }
    }

    func onSpeakersChanged() -> Observable<[UInt: Bool]> {
        return statePublisher
            .filter { state -> Bool in
                state.data == RtcServerStateType.members
            }
            .startWith(Result(success: true, data: RtcServerStateType.members))
            .map { [unowned self] _ in
                var speakers = [UInt: Bool]()
                self.members.forEach { member in
                    speakers[member] = self.speakers[member] ?? true
                }
                return speakers
            }
    }

    func muteLocalMicrophone(mute: Bool) {
        muted = mute
        rtcEngine?.muteRecordingSignal(mute)
//        let option = AgoraRtcChannelMediaOptions()
//        option.publishAudioTrack = AgoraRtcBoolOptional.of(!mute)
//        rtcEngine?.updateChannel(with: option)
    }

    func onRtcMusicStateChanged() -> Observable<Result<RtcMusicState>> {
        return rtcMusicStatePublisher.asObservable().observe(on: MainScheduler.instance)
    }

    func play(music: LocalMusic) -> Observable<Result<Void>> {
        if rtcMusicPlayer == nil {
            rtcMusicPlayer = RtcMusicPlayer(rtcServer: self)
        }
        if let player = rtcMusicPlayer {
            return Single.create { single in
                player.uid = self.uid
                let success = player.play(music: music)
                if !success {
                    single(.success(Result(success: false, message: "play \(music.name) failed!")))
                } else {
                    single(.success(Result(success: true)))
                }
                return Disposables.create()
            }.asObservable()
        } else {
            return Observable.just(Result(success: false, message: "rtcMusicPlayer is nil"))
        }
    }

    func seekMusic(position: TimeInterval) {
        if let player = rtcMusicPlayer {
            player.seek(position: Int(position))
        }
    }

    func pauseMusic() {
        if let player = rtcMusicPlayer {
            player.pause()
        }
    }

    func resumeMusic() {
        if let player = rtcMusicPlayer {
            player.resume()
        }
    }

    func stopMusic() {
        enable(earloop: false)
        if let player = rtcMusicPlayer {
            player.stop()
        }
    }

    func getRecordingSignalVolume() -> Float {
        return recordingSignalVolume
    }

    func setRecordingSignalVolume(value: Float) {
        recordingSignalVolume = value
        rtcEngine?.adjustRecordingSignalVolume(Int(recordingSignalVolume * 400))
    }

    func getPlayoutVolume() -> Float {
        return Float(rtcMusicPlayer?.player.getPlayoutVolume() ?? 0) / 400
    }

    func setPlayoutVolume(value: Float) {
        rtcMusicPlayer?.player.adjustPlayoutVolume(Int32(value * 400))
    }

    func isSupportSwitchOriginMusic() -> Bool {
        return true
//        return (rtcMusicPlayer?.getAudioTrackCount() ?? 0) > 1
    }

    func originMusic(enable: Bool) {
        if isSupportSwitchOriginMusic() {
            if let player = rtcMusicPlayer {
                player.originMusic(enable: enable)
            } else {
                Logger.log(self, message: "rtcMusicPlayer is nil", level: .error)
            }
        } else {
            Logger.log(self, message: "not support switch origin", level: .error)
        }
    }
}

extension RtcServer: AgoraRtcMediaPlayerDelegate {
    func agoraRtcMediaPlayer(_ playerKit: AgoraRtcMediaPlayerProtocol, didChangedToPosition position: Int) {
        // Logger.log(self, message: "didChangedToPosition \(position)", level: .info)
        if let player = rtcMusicPlayer {
            player.position = position
            player.duration = playerKit.getDuration()
            let state = RtcMusicState(uid: uid, streamId: 0, position: player.position, duration: player.duration, state: player.state)
            player.sendRtcMusicState(state: state)
            rtcMusicStatePublisher.accept(Result(success: true, data: state))
        }
    }

    func agoraRtcMediaPlayer(_ playerKit: AgoraRtcMediaPlayerProtocol, didChangedTo state: AgoraMediaPlayerState, error _: AgoraMediaPlayerError) {
        Logger.log(self, message: "didChangedTo \(state.rawValue)", level: .info)
        if let player = rtcMusicPlayer {
            var sync = false
            player.state = state
            switch state {
            case .openCompleted:
                player.isPlaying = true
                player.position = 0
                player.duration = playerKit.getDuration()
                player.player.play()
                sync = true
            case .paused:
                player.isPause = true
                sync = true
            case .stopped, .playBackCompleted, .playBackAllLoopsCompleted:
                player.isPlaying = false
                sync = true
            case .playing:
                player.isPlaying = true
                sync = true
            default:
                Logger.log(self, message: "status: \(state)", level: .info)
            }
            if sync {
                let state = RtcMusicState(uid: player.uid, streamId: 0, position: player.position, duration: player.duration, state: player.state)
                rtcMusicStatePublisher.accept(Result(success: true, data: state))
            }
        }
    }
}

extension RtcServer: AgoraRtcEngineDelegate {
    func rtcEngine(_: AgoraRtcEngineKit, didOccurError errorCode: AgoraErrorCode) {
        Logger.log(message: "didOccurError \(AgoraRtcEngineKit.getErrorDescription(errorCode.rawValue))", level: .info)
        statePublisher.accept(Result(success: false, data: RtcServerStateType.error, message: AgoraRtcEngineKit.getErrorDescription(errorCode.rawValue)))
    }

    func rtcEngine(_: AgoraRtcEngineKit, didJoinChannel channel: String, withUid uid: UInt, elapsed _: Int) {
        Logger.log(message: "rtc didJoinChannel:\(channel) uid:\(uid)", level: .info)
        self.uid = uid
        self.channel = channel
        members.append(uid)
        speakers[uid] = role == .audience
        statePublisher.accept(Result(success: true, data: RtcServerStateType.join))
    }

    func rtcEngine(_: AgoraRtcEngineKit, didLeaveChannelWith stats: AgoraChannelStats) {
        Logger.log(message: "rtc didLeaveChannelWith:\(stats)", level: .info)
    }

    func rtcEngine(_: AgoraRtcEngineKit, didJoinedOfUid uid: UInt, elapsed _: Int) {
        Logger.log(message: "rtc didJoinedOfUid uid:\(uid)", level: .info)
        members.append(uid)
        speakers[uid] = true
        statePublisher.accept(Result(success: true, data: RtcServerStateType.members))
    }

    func rtcEngine(_: AgoraRtcEngineKit, didAudioMuted muted: Bool, byUid uid: UInt) {
        Logger.log(message: "rtc didAudioMuted uid:\(uid) muted:\(muted)", level: .info)
        speakers[uid] = muted
        statePublisher.accept(Result(success: true, data: RtcServerStateType.members))
    }

    func rtcEngine(_: AgoraRtcEngineKit, didOfflineOfUid uid: UInt, reason _: AgoraUserOfflineReason) {
        Logger.log(message: "rtc didOfflineOfUid uid:\(uid)", level: .info)
        if let index = members.firstIndex(of: uid) {
            members.remove(at: index)
        }
        speakers[uid] = false
        statePublisher.accept(Result(success: true, data: RtcServerStateType.members))
    }

    func rtcEngine(_: AgoraRtcEngineKit, receiveStreamMessageFromUid uid: UInt, streamId: Int, data: Data) {
        // Logger.log(self, message: "receiveStreamMessageFromUid \(uid) \(streamId)", level: .info)
        if rtcMusicPlayer?.state == .playing || rtcMusicPlayer?.uid == uid {
            return
        }
        do {
            let content: NSDictionary = try JSONSerialization.jsonObject(with: data, options: .mutableContainers) as! NSDictionary
            let cmd: String? = content["cmd"] as? String
            guard let cmd = cmd else {
                return
            }
            switch cmd {
            case "musicStopped":
                Logger.log(self, message: "musicStopped", level: .info)
            case "setLrcTime":
                let duration = content["duration"] as! Int
                let position = content["time"] as! Int
                let state = RtcMusicState(uid: uid, streamId: streamId, position: position, duration: duration, state: .playing)
                rtcMusicStatePublisher.accept(Result(success: true, data: state))
            default: break
            }
        } catch {
            Logger.log(self, message: error.localizedDescription, level: .error)
        }
    }
}

enum RtcServerError: Int {
    case join = 0
    case register = 1
    case leave = 2
}

extension RtcServer: ErrorDescription {
    static func toErrorString(type: RtcServerError, code: Int32) -> String {
        switch type {
        case RtcServerError.join:
            switch code {
            case -2:
                return "Invalid Argument".localized
            case -3:
                return "SDK Not Ready".localized
            case -5:
                return "SDK Refused".localized
            case -7:
                return "SDK Not Initialized".localized
            default:
                return "Unknown Error".localized
            }
        case RtcServerError.register:
            return "Unknown Error".localized
        case RtcServerError.leave:
            switch code {
            case -2:
                return "Invalid Argument".localized
            case -7:
                return "SDK Not Initialized".localized
            default:
                return "Unknown Error".localized
            }
        }
    }
}
