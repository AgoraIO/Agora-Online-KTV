//
//  MVPlayer.swift
//  LiveKtv
//
//  Created by XC on 2021/6/7.
//

import Core
import Foundation
import UIKit

class MVPlayer: NSObject {
    enum Status {
        case stop
        case play
        case pause
    }

    weak var delegate: RoomController!
    weak var player: UIView! {
        didSet {
            player.addSubview(musicLyricView)
            musicLyricView.fill(view: player, leading: 0, top: 32, trailing: 0, bottom: 32)
                .active()
        }
    }

    weak var mv: UIImageView!
    weak var originSettingView: UISwitch! {
        didSet {
            originSettingView.isOn = true
            originSettingView.superview?.addSubview(hookSwitchView)
            hookSwitchView.fill(view: originSettingView)
                .active()
        }
    }

    weak var settingsView: UIButton!
    weak var playerControlView: UIButton!
    weak var switchMusicView: UIButton!
    weak var icon: UIImageView!
    weak var name: UILabel!

    let musicLyricView = MusicLyricView()

    var member: LiveKtvMember? {
        didSet {
            onChanged()
        }
    }

    var status: MVPlayer.Status! {
        didSet {
            onChanged()
        }
    }

    private lazy var hookSwitchView = UIView()

    private lazy var stopView: UIView = {
        let view = UIView()
        let icon = UIImageView()
        icon.image = UIImage(named: "empty1", in: Utils.bundle, with: nil)
        let tips1 = UILabel()
        tips1.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        tips1.textColor = UIColor(hex: Colors.Text)
        tips1.numberOfLines = 0
        tips1.textAlignment = .center
        tips1.text = "当前无人演唱"
        let tips2 = UILabel()
        tips2.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        tips2.textColor = UIColor(hex: Colors.Text)
        tips2.numberOfLines = 0
        tips2.textAlignment = .center
        tips2.text = "点击“点歌”一展歌喉"

        view.addSubview(icon)
        view.addSubview(tips1)
        view.addSubview(tips2)

        icon.width(constant: 117)
            .height(constant: 117)
            .marginTop(anchor: view.topAnchor, constant: 50)
            .centerX(anchor: view.centerXAnchor)
            .active()
        tips1.marginTop(anchor: icon.bottomAnchor, constant: 16)
            .marginLeading(anchor: view.leadingAnchor, constant: 15)
            .centerX(anchor: view.centerXAnchor)
            .active()
        tips2.marginTop(anchor: tips1.bottomAnchor, constant: 8)
            .marginLeading(anchor: view.leadingAnchor, constant: 15)
            .centerX(anchor: view.centerXAnchor)
            .active()

        return view
    }()

    var music: LiveKtvMusic? {
        didSet {
            if music?.id == oldValue?.id {
                if music?.type == 1 {
                    onChorusStateChange(old: oldValue)
                }
                return
            }
            onPlayMusicChange()
        }
    }

    private func onChanged() {
        switch status {
        case .stop, .none:
            settingsView.superview?.isHidden = true
            if stopView.superview == nil {
                player.superview!.addSubview(stopView)
                stopView.fill(view: player.superview!)
                    .active()
            }
            stopView.isHidden = false
            mv.isHidden = true
            musicLyricView.isHidden = true
        case .play, .pause:
            stopView.isHidden = true
            mv.isHidden = false
            musicLyricView.isHidden = false
            updateMusicLyricViewLayout()
            if settingsView.superview?.isHidden == false {
                playerControlView.setImage(UIImage(named: status == .play ? "iconPause" : "iconPlay", in: Utils.bundle, with: nil), for: .normal)
            }
        }
    }

    private func updateMusicLyricViewLayout() {
        if let member = member, let music = music {
            settingsView.superview?.isHidden = !music.isOrderBy(member: member)
        } else {
            settingsView.superview?.isHidden = true
        }
        if let settingRoot = settingsView.superview, let root = player.superview {
            if settingRoot.isHidden {
                if musicLyricView.superview != root {
                    musicLyricView.removeFromSuperview()
                    root.addSubview(musicLyricView)
                    let padding = (root.bounds.height - musicLyricView.bounds.height) / 2
                    musicLyricView.fill(view: root, leading: 0, top: padding, trailing: 0, bottom: padding)
                        .active()
                }
            } else {
                if musicLyricView.superview != player {
                    musicLyricView.removeFromSuperview()
                    player.addSubview(musicLyricView)
                    musicLyricView.fill(view: player, leading: 0, top: 32, trailing: 0, bottom: 32)
                        .active()
                }
            }
        }
    }

    private func onPlayMusicChange() {
        if let music = music {
            originSettingView.setOn(true, animated: true)
            status = .play
            updateMusicLyricViewLayout()
            delegate.viewModel.fetchMusicLrc(music: music) { [weak self] waiting in
                if waiting {
                    self?.musicLyricView.lyrics = nil
                }
            } onSuccess: { [weak self] localMusic in
                if localMusic.id == self?.music?.musicId {
                    self?.musicLyricView.lyrics = LocalMusicManager.parseLyric(music: localMusic)
                }
            } onError: { [weak self] message in
                self?.delegate.show(message: message, type: .error)
            }
        } else {
            status = .none
        }

        if let musicName = music?.name {
            name.text = musicName
            icon.isHidden = false
            name.isHidden = false
        } else {
            icon.isHidden = true
            name.isHidden = true
        }
    }

    private func onChorusStateChange(old _: LiveKtvMusic?) {}

    func subcribeUIEvent() {
        settingsView.addTarget(self, action: #selector(onTapSettingsView), for: .touchUpInside)
        playerControlView.addTarget(self, action: #selector(onTapPlayerControlView), for: .touchUpInside)
        switchMusicView.addTarget(self, action: #selector(onSwitchMusic), for: .touchUpInside)
        hookSwitchView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(onSwitchOrigin)))
        musicLyricView.delegate = self
    }

    func onMusic(state: RtcMusicState) {
        musicLyricView.scrollLyric(currentTime: TimeInterval(state.position), totalTime: TimeInterval(state.duration))
        if let playerState = state.state {
            switch playerState {
            case .playing:
                if status != .play {
                    status = .play
                }
                musicLyricView.paused = false
            case .paused:
                if status != .pause {
                    status = .pause
                }
                musicLyricView.paused = true
            case .playBackCompleted, .playBackAllLoopsCompleted:
                if status != .stop {
                    status = .stop
                    originSettingView.setOn(true, animated: true)
                }
                if let music = music {
                    delegate.viewModel.end(music: music) { [unowned self] waiting in
                        delegate.show(processing: waiting)
                    } onSuccess: { [unowned self] in
                        self.music = nil
                    } onError: { [unowned self] message in
                        delegate.show(message: message, type: .error)
                    }
                }
            default: break
            }
        }
        if state.state == .openCompleted {}
    }

    @objc func onTapSettingsView() {
        PlayerSettingDialog().show(delegate: delegate)
    }

    @objc func onTapPlayerControlView() {
        if status == .play {
            delegate.viewModel.pauseMusic()
        } else if status == .pause {
            delegate.viewModel.resumeMusic()
        }
    }

    @objc func onSwitchMusic() {
        let alert = AlertDialog(title: "切歌".localized, message: "终止当前歌曲的演唱？".localized)
        alert.cancelAction = { [unowned self] in
            self.delegate.dismiss(dialog: alert, completion: nil)
        }
        alert.okAction = { [unowned self] in
            self.delegate.dismiss(dialog: alert, completion: nil)
            if let music = music {
                delegate.viewModel.end(music: music) { [unowned self] waiting in
                    delegate.show(processing: waiting)
                } onSuccess: { [unowned self] in
                    self.music = nil
                } onError: { [unowned self] message in
                    delegate.show(message: message, type: .error)
                }
            }
        }
        delegate.show(dialog: alert, style: .center, padding: 27, relation: .greaterOrEqual, completion: nil)
    }

    @objc func onSwitchOrigin() {
        let enable = originSettingView.isOn
        if enable {
            if delegate.viewModel.isSupportSwitchOriginMusic {
                originSettingView.setOn(false, animated: true)
                delegate.viewModel.originMusic(enable: true)
            } else {
                delegate.show(message: "该歌曲无法进行人声切换", type: .error)
            }
        } else {
            if delegate.viewModel.isSupportSwitchOriginMusic {
                originSettingView.setOn(true, animated: true)
                delegate.viewModel.originMusic(enable: false)
            }
        }
    }

    deinit {
        Logger.log(self, message: "deinit", level: .info)
    }
}

extension MVPlayer: MusicLyricViewDelegate {
    func userEndSeeking(time: TimeInterval) {
        Logger.log(self, message: "userEndSeeking \(time)", level: .info)
        delegate.viewModel.seekMusic(position: time)
    }
}
