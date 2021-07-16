//
//  RoomController.swift
//  LiveKtv
//
//  Created by XC on 2021/6/7.
//

import Core
import Foundation
import UIKit

protocol RoomControlDelegate: AnyObject {
    func onTap(view: SeatView)
    func onMemberListChanged()
    func onMuted(mute: Bool)
    func onRoomUpdate()
    func onRoomClosed()
    func onPlayListChanged()
    func onFetchMusic(finish: Bool)
    func onMusic(state: RtcMusicState)
    func show(processing: Bool)
    func onError(message: String?)
}

class RoomController: BaseViewContoller, DialogDelegate {
    @IBOutlet var closeRoomView: UIButton!
    @IBOutlet var roomCoverView: UIImageView!
    @IBOutlet var roomNameView: UILabel!
    @IBOutlet var player: UIView! {
        didSet {
            mvPlayer.delegate = self
            mvPlayer.player = player
        }
    }

    @IBOutlet var mvView: UIImageView! {
        didSet {
            mvPlayer.mv = mvView
        }
    }

    @IBOutlet var iconView: UIImageView! {
        didSet {
            mvPlayer.icon = iconView
            iconView.isHidden = true
        }
    }

    @IBOutlet var musicNameView: UILabel! {
        didSet {
            mvPlayer.name = musicNameView
            musicNameView.isHidden = true
        }
    }

    @IBOutlet var originSettingView: UISwitch! {
        didSet {
            mvPlayer.originSettingView = originSettingView
        }
    }

    @IBOutlet var settingsView: UIButton! {
        didSet {
            mvPlayer.settingsView = settingsView
        }
    }

    @IBOutlet var playerControlView: UIButton! {
        didSet {
            mvPlayer.playerControlView = playerControlView
        }
    }

    @IBOutlet var switchMusicView: UIButton! {
        didSet {
            mvPlayer.switchMusicView = switchMusicView
        }
    }

    @IBOutlet var seat1Root: UIView! {
        didSet {
            seatViews[0].delegate = self
            seatViews[0].root = seat1Root
        }
    }

    @IBOutlet var seat1Icon: UIImageView! {
        didSet {
            seatViews[0].icon = seat1Icon
        }
    }

    @IBOutlet var seat1Label: UILabel! {
        didSet {
            seatViews[0].label = seat1Label
        }
    }

    @IBOutlet var seat2Root: UIView! {
        didSet {
            seatViews[1].delegate = self
            seatViews[1].root = seat2Root
        }
    }

    @IBOutlet var seat2Icon: UIImageView! {
        didSet {
            seatViews[1].icon = seat2Icon
        }
    }

    @IBOutlet var seat2Label: UILabel! {
        didSet {
            seatViews[1].label = seat2Label
        }
    }

    @IBOutlet var seat3Root: UIView! {
        didSet {
            seatViews[2].delegate = self
            seatViews[2].root = seat3Root
        }
    }

    @IBOutlet var seat3Icon: UIImageView! {
        didSet {
            seatViews[2].icon = seat3Icon
        }
    }

    @IBOutlet var seat3Label: UILabel! {
        didSet {
            seatViews[2].label = seat3Label
        }
    }

    @IBOutlet var seat4Root: UIView! {
        didSet {
            seatViews[3].delegate = self
            seatViews[3].root = seat4Root
        }
    }

    @IBOutlet var seat4Icon: UIImageView! {
        didSet {
            seatViews[3].icon = seat4Icon
        }
    }

    @IBOutlet var seat4Label: UILabel! {
        didSet {
            seatViews[3].label = seat4Label
        }
    }

    @IBOutlet var seat5Root: UIView! {
        didSet {
            seatViews[4].delegate = self
            seatViews[4].root = seat5Root
        }
    }

    @IBOutlet var seat5Icon: UIImageView! {
        didSet {
            seatViews[4].delegate = self
            seatViews[4].icon = seat5Icon
        }
    }

    @IBOutlet var seat5Label: UILabel! {
        didSet {
            seatViews[4].label = seat5Label
        }
    }

    @IBOutlet var seat6Root: UIView! {
        didSet {
            seatViews[5].delegate = self
            seatViews[5].root = seat6Root
        }
    }

    @IBOutlet var seat6Icon: UIImageView! {
        didSet {
            seatViews[5].icon = seat6Icon
        }
    }

    @IBOutlet var seat6Label: UILabel! {
        didSet {
            seatViews[5].label = seat6Label
        }
    }

    @IBOutlet var seat7Root: UIView! {
        didSet {
            seatViews[6].delegate = self
            seatViews[6].root = seat7Root
        }
    }

    @IBOutlet var seat7Icon: UIImageView! {
        didSet {
            seatViews[6].icon = seat7Icon
        }
    }

    @IBOutlet var seat7Label: UILabel! {
        didSet {
            seatViews[6].label = seat7Label
        }
    }

    @IBOutlet var seat8Root: UIView! {
        didSet {
            seatViews[7].delegate = self
            seatViews[7].root = seat8Root
        }
    }

    @IBOutlet var seat8Icon: UIImageView! {
        didSet {
            seatViews[7].icon = seat8Icon
        }
    }

    @IBOutlet var seat8Label: UILabel! {
        didSet {
            seatViews[7].label = seat8Label
        }
    }

    @IBOutlet var speakerControllViewRoot: UIView! {
        didSet {
            speakerToolbar.root = speakerControllViewRoot
            speakerToolbar.delegate = self
        }
    }

    @IBOutlet var micView: UIButton! {
        didSet {
            speakerToolbar.micView = micView
        }
    }

    @IBOutlet var switchMVView: UIButton! {
        didSet {
            speakerToolbar.switchMVView = switchMVView
        }
    }

    @IBOutlet var orderMusicView: UIButton! {
        didSet {
            speakerToolbar.orderMusicView = orderMusicView
        }
    }

    @IBOutlet var listenerViewRoot: UILabel! {
        didSet {
            listenerToolbar.root = listenerViewRoot
            listenerToolbar.delegate = self
        }
    }

    let viewModel = RoomViewModel()
    private let mvPlayer = MVPlayer()

    private let seatViews: [SeatView] = [0, 1, 2, 3, 4, 5, 6, 7].map { index in
        SeatView(index: index)
    }

    private let speakerToolbar = SpeakerToolbar()
    private let listenerToolbar = ListenerToolbar()

    override func viewDidLoad() {
        super.viewDidLoad()
        viewModel.delegate = self
        // initUI()
        renderToolbar()
        subcribeUIEvent()
        subcribeRoomEvent()
    }

    private func initUI() {
        Logger.log(self, message: "initUI", level: .info)
        roomNameView.text = viewModel.room.channelName
        roomCoverView.image = UIImage(named: LiveKtvRoom.getLocalCover(cover: viewModel.room.cover), in: Utils.bundle, with: nil)
        mvPlayer.mv.image = UIImage(named: LiveKtvRoom.getLocalMV(cover: viewModel.room.mv), in: Utils.bundle, with: nil)
        performSelector(inBackground: #selector(getImageColor), with: nil)
    }

    @objc private func getImageColor() {
        if let image = UIImage(named: LiveKtvRoom.getLocalMV(cover: viewModel.room.mv), in: Utils.bundle, with: nil) {
            let color = ColorThief.getColor(from: image)?.makeUIColor()
            if let color = color {
                Logger.log(self, message: "set MusicLyricView.hightColor \(color)", level: .info)
                MusicLyricView.hightColor = color
            }
        }
    }

    private func renderToolbar() {
        Logger.log(self, message: "renderToolbar", level: .info)
        mvPlayer.member = viewModel.member
        speakerToolbar.member = viewModel.member
        listenerToolbar.member = viewModel.member
    }

    private func subcribeUIEvent() {
        Logger.log(self, message: "subcribeUIEvent", level: .info)
        closeRoomView.addTarget(self, action: #selector(onTapCloseButton), for: .touchUpInside)
        seatViews.forEach { view in
            view.subcribeUIEvent()
        }
        listenerToolbar.delegate = self
        speakerToolbar.delegate = self
        speakerToolbar.subcribeUIEvent()
        mvPlayer.subcribeUIEvent()
    }

    private func subcribeRoomEvent() {
        Logger.log(self, message: "subcribeRoomEvent", level: .info)
        viewModel.subcribeRoomEvent()
    }

    @objc func onTapCloseButton() {
        if viewModel.member.isManager {
            let alert = AlertDialog(title: "Close room".localized, message: "Leaving the room ends the session and removes everyone".localized)
            alert.cancelAction = { [unowned self] in
                self.dismiss(dialog: alert, completion: nil)
            }
            alert.okAction = { [unowned self] in
                self.dismiss(dialog: alert, completion: nil)
                self.leaveRoom()
            }
            show(dialog: alert, style: .center, padding: 27, relation: .greaterOrEqual, completion: nil)
        } else {
            leaveRoom()
        }
    }

    private func leaveRoom() {
        viewModel.leaveRoom { [unowned self] waiting in
            self.show(processing: waiting)
        } onSuccess: { [unowned self] in
            self.dismiss(completion: nil)
        } onError: { [unowned self] message in
            self.show(message: message, type: .error)
        }
    }

    override func viewDidAppear(_: Bool) {
        navigationController?.interactivePopGestureRecognizer?.delegate = self
    }

    deinit {
        Logger.log(self, message: "deinit", level: .info)
    }

    public static func instance() -> RoomController {
        let storyBoard = UIStoryboard(name: "Main", bundle: Utils.bundle)
        let controller = storyBoard.instantiateViewController(withIdentifier: "RoomController") as! RoomController
        return controller
    }
}

extension RoomController: RoomControlDelegate {
    func onFetchMusic(finish: Bool) {
        show(loading: !finish, message: "歌曲准备中")
    }

    func onRoomUpdate() {
        initUI()
    }

    func onRoomClosed() {
        leaveRoom()
    }

    func onPlayListChanged() {
        mvPlayer.music = viewModel.playingMusic
        seatViews.forEach { view in
            view.music = viewModel.playingMusic
        }
        speakerToolbar.onMusicListChanged()
    }

    func onMusic(state: RtcMusicState) {
        mvPlayer.onMusic(state: state)
    }

    func onMemberListChanged() {
        let list = viewModel.memberList.filter { member in
            member.isSpeaker()
        }
        let count = min(list.count, 8)
        for index in 0 ..< 8 {
            seatViews[index].member = index < count ? list[index] : nil
        }
        renderToolbar()
    }

    func onMuted(mute: Bool) {
        speakerToolbar.onMuted(mute: mute)
    }

    func onTap(view: SeatView) {
        if viewModel.isManager {
            if let member = view.member {
                if member.id != viewModel.member.id {
                    ManageSpeakerDialog().show(with: member, delegate: self)
                }
            }
        } else if !viewModel.isSpeaker, view.member == nil {
            viewModel.handsUp { [unowned self] waiting in
                self.show(processing: waiting)
            } onSuccess: {} onError: { [unowned self] message in
                self.show(message: message, type: .error)
            }
        }
    }

    func onError(message: String?) {
        show(message: message, type: .error)
    }
}

extension RoomController: UIGestureRecognizerDelegate {
    func gestureRecognizerShouldBegin(_: UIGestureRecognizer) -> Bool {
        false
    }
}
