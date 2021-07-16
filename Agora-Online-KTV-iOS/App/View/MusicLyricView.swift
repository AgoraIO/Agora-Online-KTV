//
//  MusicLyricView.swift
//  LiveKtv
//
//  Created by XC on 2021/6/11.
//

import Core
import Foundation
import UIKit

private class MusicLyricLabel: UILabel {
    private static let STYLE = false
    var progress: CGFloat = 0 {
        didSet {
            if oldValue != progress {
                setNeedsDisplay()
            }
        }
    }

    private func renderText() {
        if let text = self.text {
            if progress <= 0 {
                textColor = UIColor.white.withAlphaComponent(0.59)
            } else if progress >= 1 {
                textColor = MusicLyricView.hightColor
            } else {
                let fill = Int(progress * CGFloat(text.count))
                let fillText = String(text[Range(NSRange(location: 0, length: fill), in: text)!])
                let left = text.count - fill
                let leftText = left <= 0 ? "" : String(text[Range(NSRange(location: fill, length: left), in: text)!])
                let renderText = NSMutableAttributedString(
                    attributedString: NSAttributedString(
                        string: fillText,
                        attributes: [NSAttributedString.Key.foregroundColor: MusicLyricView.hightColor]
                    )
                )
                renderText.append(
                    NSAttributedString(
                        string: leftText,
                        attributes: [NSAttributedString.Key.foregroundColor: UIColor.white.withAlphaComponent(0.59)]
                    )
                )
                attributedText = renderText
            }
        }
    }

    override func draw(_ rect: CGRect) {
        super.draw(rect)
        if progress <= 0 {
            return
        }
        let lines = Int(bounds.size.height / font.lineHeight)
        let padingTop = (bounds.size.height - CGFloat(lines) * font.lineHeight) / 2
        let maxWidth = sizeThatFits(CGSize(width: CGFloat(MAXFLOAT), height: font.lineHeight * 2)).width
        let oneLineProgress = maxWidth <= bounds.size.width ? 1 : bounds.size.width / maxWidth
        let path = CGMutablePath()
        for index in 0 ..< lines {
            let leftProgress = min(progress, 1) - CGFloat(index) * oneLineProgress
            let fillRect: CGRect
            if leftProgress >= oneLineProgress {
                fillRect = CGRect(x: 0, y: padingTop + CGFloat(index) * font.lineHeight, width: bounds.size.width, height: font.lineHeight)
                path.addRect(fillRect)
            } else if leftProgress > 0 {
                if (index != lines - 1) || (maxWidth <= bounds.size.width) {
                    fillRect = CGRect(x: 0, y: padingTop + CGFloat(index) * font.lineHeight, width: maxWidth * leftProgress, height: font.lineHeight)
                } else {
                    let width = maxWidth.truncatingRemainder(dividingBy: bounds.size.width)
                    let dw = (bounds.size.width - width) / 2 + maxWidth * leftProgress
                    fillRect = CGRect(x: 0, y: padingTop + CGFloat(index) * font.lineHeight, width: dw, height: font.lineHeight)
                }
                path.addRect(fillRect)
                break
            }
        }
        if let context = UIGraphicsGetCurrentContext(), !path.isEmpty {
            context.addPath(path)
            context.clip()
            let _textColor = textColor
            textColor = UIColor.white
            if MusicLyricLabel.STYLE {
                let _shadowOffset = shadowOffset
                let _shadowColor = shadowColor
                //            super.draw(rect)
                //            context.setLineWidth(1)
                //            context.setLineJoin(.round)
                //            context.setTextDrawingMode(.stroke)
                //            textColor = MusicLyricView.hightColor
                shadowOffset = CGSize(width: 0, height: 2)
                shadowColor = MusicLyricView.hightColor
                super.draw(rect)
                shadowOffset = _shadowOffset
                shadowColor = _shadowColor
            } else {
                super.draw(rect)
            }
            textColor = _textColor
        }
    }
}

private class MusicLyricCell: UITableViewCell {
    let lyricLabel: MusicLyricLabel = {
        let view = MusicLyricLabel()
        view.textAlignment = .center
        view.numberOfLines = 0
        view.font = UIFont.systemFont(ofSize: 16)
        view.backgroundColor = .clear
        return view
    }()

    var progress: CGFloat = 0 {
        didSet {
            lyricLabel.progress = progress
        }
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        addSubview(lyricLabel)
        lyricLabel.marginLeading(anchor: leadingAnchor, constant: 15, relation: .greaterOrEqual)
            .centerX(anchor: centerXAnchor)
            // .height(constant: 44, relation: .greaterOrEqual)
            .marginTop(anchor: topAnchor, constant: 12, relation: .greaterOrEqual)
            .centerY(anchor: centerYAnchor)
            .active()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

protocol MusicLyricViewDelegate: NSObject {
    func userEndSeeking(time: TimeInterval) -> Void
}

class MusicLyricView: UIView, UITableViewDataSource, UITableViewDelegate {
    static var hightColor = UIColor.white
    weak var delegate: MusicLyricViewDelegate?
    // ms
    private var seekTime: TimeInterval = 0
    private var Distance = 3
    private let normalLyricTextColor = UIColor.white.withAlphaComponent(0.59)
    private(set) var isWillDraging: Bool = false
    private(set) var isScrolling: Bool = false
    private(set) var lyricIndex: Int = 0
    var lyrics: [LrcSentence]? {
        didSet {
            DispatchQueue.main.async { [weak self] in
                if let self = self {
                    self.lyricsChanged()
                }
            }
        }
    }

    private var timer: DispatchSourceTimer?

    /** 歌词列表 */
    private lazy var lyricTable: UITableView = {
        let view = UITableView(frame: .zero, style: .plain)
        view.delegate = self
        view.dataSource = self
        view.separatorStyle = .none
        view.backgroundColor = .clear
        // view.rowHeight = 44
        view.register(MusicLyricCell.self, forCellReuseIdentifier: NSStringFromClass(MusicLyricCell.self))
        view.scrollsToTop = false
        return view
    }()

    /** 提示 */
    private lazy var tipsLabel: UILabel = {
        let view = UILabel()
        view.textColor = .white
        view.font = UIFont.systemFont(ofSize: 17)
        view.isHidden = true
        return view
    }()

    private lazy var timelineView: UIView = {
        let view = UIView()
        view.backgroundColor = normalLyricTextColor
        view.isHidden = true
        return view
    }()

    private lazy var timeLabel: UILabel = {
        let view = UILabel()
        view.textColor = .white
        view.font = UIFont.systemFont(ofSize: 13)
        view.isHidden = true
        return view
    }()

    private var curLyricsTimestamp: TimeInterval = 0
    private var currentTime: TimeInterval = 0
    private var totalTime: TimeInterval = 0
    var paused: Bool = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        addSubview(lyricTable)
        lyricTable.fill(view: self)
            .active()
        lyricTable.addSubview(tipsLabel)
        tipsLabel
            .centerX(anchor: lyricTable.centerXAnchor)
            .centerY(anchor: lyricTable.centerYAnchor)
            .active()

        addSubview(timelineView)
        addSubview(timeLabel)
        timelineView.height(constant: 0.5)
            .marginLeading(anchor: leadingAnchor, constant: 50)
            .marginTrailing(anchor: trailingAnchor, constant: 50)
            .centerY(anchor: lyricTable.centerYAnchor)
            .active()
        timeLabel.centerY(anchor: timelineView.centerYAnchor)
            .centerX(anchor: timelineView.trailingAnchor, constant: 25)
            .active()

        timer = DispatchSource.makeTimerSource(flags: [], queue: DispatchQueue(label: "MusicLyricView"))
        if let timer = timer {
            timer.setEventHandler { [weak self] in
                if let self = self {
                    self.timerTrigger()
                }
            }
            timer.schedule(deadline: .now(), repeating: .milliseconds(1000 / 30))
            timer.activate()
        }
    }

    private func timerTrigger() {
        // Logger.log(self, message: "timerTrigger", level: .info)
        if paused {
            return
        }
        if let lyrics = lyrics {
            if lyrics.count == 0 {
                lyricIndex = 0
                return
            }
            if lyricIndex > lyrics.count - 1 {
                lyricIndex = 0
            }
            let currentLyric = lyrics[lyricIndex]
            let currentTime = self.currentTime
            let totalTime = self.totalTime
            let curLyricsTimestamp = self.curLyricsTimestamp
            var offset: TimeInterval = (Date().timeIntervalSince1970 * 1000 - curLyricsTimestamp)
            if abs(offset) > 1500 {
                offset = 0
            }

            if currentTime < currentLyric.startMsTime() {
                return
            }

            let nextIndex = lyricIndex + 1
            let nextLyric = nextIndex < lyrics.count ? lyrics[nextIndex] : nil
            if let nextLyric = nextLyric {
                if currentTime > nextLyric.startMsTime() {
                    return
                }
            }

            let consume = (currentTime - currentLyric.startMsTime()) + offset
            let index = lyricIndex + Distance
            let progress = currentLyric.getProgress(consume: consume, totalMsTime: totalTime)

            DispatchQueue.main.async { [weak self] in
                if let self = self {
                    let cell: MusicLyricCell? = self.lyricTable.cellForRow(at: IndexPath(row: index, section: 0)) as? MusicLyricCell
                    cell?.progress = CGFloat(progress)

                    if progress >= 1, nextLyric != nil, (currentLyric.startMsTime() + consume) >= nextLyric!.startMsTime() {
                        self.scrollLyric(currentTime: currentLyric.startMsTime() + consume, totalTime: totalTime)
                    }
                }
            }
        }
    }

    private func lyricsChanged() {
        Logger.log(self, message: "lyricsChanged", level: .info)
        lyricIndex = 0
        currentTime = 0
        totalTime = 0
        if let lyrics = lyrics {
            tipsLabel.isHidden = lyrics.count > 0
            tipsLabel.text = lyrics.count > 0 ? nil : "纯音乐，无歌词"
            lyricTable.reloadData { [weak self] in
                if let self = self {
                    self.lyricTable.selectRow(at: IndexPath(row: self.Distance, section: 0), animated: true, scrollPosition: .middle)
                }
            }
        } else {
            tipsLabel.isHidden = false
            tipsLabel.text = "歌词加载中..."
            lyricTable.reloadData()
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func scrollLyric(currentTime: TimeInterval, totalTime: TimeInterval) {
        if self.currentTime == currentTime && self.totalTime == totalTime {
            return
        }
        Logger.log(self, message: "scrollLyric current:\(currentTime) total:\(totalTime)", level: .info)
        curLyricsTimestamp = Date().timeIntervalSince1970 * 1000
        self.currentTime = currentTime
        self.totalTime = totalTime

        if totalTime <= 0 || currentTime > totalTime {
            return
        }

        if let lyrics = lyrics {
            if lyrics.count == 0 {
                lyricIndex = 0
            }
            let curIndex = lyrics.enumerated().first { item in
                let currentLyric = item.element
                let index = item.offset
                let nexrLyric = index < lyrics.count - 1 ? lyrics[index + 1] : nil
                return (self.currentTime >= currentLyric.startMsTime()) &&
                    ((nexrLyric != nil && self.currentTime < nexrLyric!.startMsTime()) || (index == lyrics.count - 1))
            }?.offset ?? -1

            if curIndex != -1, curIndex != lyricIndex {
                lyricTable.reloadData()
                if !isScrolling {
                    let index = curIndex + Distance
                    if index < lyricTable.numberOfRows(inSection: 0) {
                        lyricIndex = curIndex
                        lyricTable.selectRow(at: IndexPath(row: index, section: 0), animated: true, scrollPosition: .middle)
                    }
                }
            }
        }
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection _: Int) -> Int {
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        return (lyrics?.count ?? 0) + Distance * 2
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: MusicLyricCell = tableView.dequeueReusableCell(withIdentifier: NSStringFromClass(MusicLyricCell.self), for: indexPath) as! MusicLyricCell
        cell.lyricLabel.textColor = normalLyricTextColor
        if cell.selectedBackgroundView == nil {
            cell.selectedBackgroundView = UIView()
        }
        cell.backgroundColor = .clear
        let lyricsCount = lyrics?.count ?? 0
        let index = indexPath.row - Distance
        let current = lyricIndex + Distance

        if index < 0 || index >= lyricsCount {
            cell.lyricLabel.textColor = .clear
            cell.lyricLabel.text = nil
        } else {
            cell.lyricLabel.text = lyrics?[index].getSentence()
            if indexPath.row == current {
                cell.lyricLabel.font = UIFont.systemFont(ofSize: 20, weight: .medium)
                lyrics?[index].render(with: cell.lyricLabel)
            } else {
                cell.lyricLabel.font = UIFont.systemFont(ofSize: 16)
                cell.progress = 0
            }
        }
        return cell
    }

    func scrollViewWillBeginDragging(_: UIScrollView) {
        isWillDraging = true
        NSObject.cancelPreviousPerformRequests(withTarget: self)
        isScrolling = true
        timelineView.isHidden = false
        timeLabel.isHidden = false
        seekTime = -1
    }

    func scrollViewDidEndDragging(_: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            isWillDraging = false
            perform(#selector(endScroll), with: nil, afterDelay: 1)
        }
        if let delegate = delegate, seekTime >= 0 {
            delegate.userEndSeeking(time: seekTime)
            seekTime = -1
            isScrolling = false
        }
    }

    func scrollViewWillBeginDecelerating(_: UIScrollView) {
        isScrolling = true
    }

    func scrollViewDidEndDecelerating(_: UIScrollView) {
        isWillDraging = false
        perform(#selector(endScroll), with: nil, afterDelay: 1)
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if !isScrolling {
            return
        }
        if let lyrics = lyrics {
            let indexPath = lyricTable.indexPathForRow(at: CGPoint(x: 0, y: scrollView.contentOffset.y + lyricTable.frame.size.height / 2))
            if let indexPath = indexPath {
                let index = indexPath.item - Distance
                if index >= 0, index <= lyrics.count - 1 {
                    let lyric = lyrics[index]
                    seekTime = lyric.startMsTime()
                    timeLabel.text = lyric.timeString()
                    timeLabel.isHidden = false
                    return
                } else if index < 0 {
                    timeLabel.text = nil
                    timeLabel.isHidden = true
                    seekTime = 0
                    return
                }
            }
        }
        timeLabel.text = nil
        timeLabel.isHidden = true
        seekTime = -1
    }

    @objc private func endScroll() {
        if isWillDraging {
            return
        }
        timelineView.isHidden = true
        timeLabel.isHidden = true

        perform(#selector(endScrolling), with: nil, afterDelay: 1)
    }

    @objc private func endScrolling() {
        if isWillDraging {
            return
        }
        isScrolling = false
    }

    deinit {
        Logger.log(self, message: "deinit", level: .info)
        timer?.cancel()
        timer = nil
    }
}
