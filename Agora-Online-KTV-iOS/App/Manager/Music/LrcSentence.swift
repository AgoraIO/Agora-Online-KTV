//
//  File.swift
//  app
//
//  Created by XC on 2021/7/7.
//

import Core
import Foundation
import UIKit

protocol LrcSentence {
    func startMsTime() -> TimeInterval
    func endMsTime() -> TimeInterval
    func render(with: UILabel) -> Void
    func getProgress(consume: TimeInterval, totalMsTime: TimeInterval) -> Float
    func getSentence() -> String
    func timeString() -> String
}

class NormalLrc: LrcSentence {
    private let model: LyricModel
    private var _endMsTime: TimeInterval

    init(model: LyricModel, endMsTime: TimeInterval = 0) {
        self.model = model
        _endMsTime = endMsTime
    }

    func startMsTime() -> TimeInterval {
        return model.msTime
    }

    func endMsTime() -> TimeInterval {
        return _endMsTime
    }

    func setEndMsTime(_ endMsTime: TimeInterval) {
        _endMsTime = endMsTime
    }

    func getProgress(consume: TimeInterval, totalMsTime: TimeInterval) -> Float {
        if endMsTime() <= 0 || endMsTime() <= startMsTime() {
            _endMsTime = totalMsTime
        }
        let diff = endMsTime() - startMsTime()
        if consume >= diff {
            return 1
        } else if consume <= 0 {
            return 0
        } else {
            return Float(min(consume, diff) / diff)
        }
    }

    func getSentence() -> String {
        return model.content.trimmingCharacters(in: .newlines)
    }

    func timeString() -> String {
        return model.timeString
    }

    func render(with _: UILabel) {}
}

class MiguLrc: LrcSentence {
    private let model: MiguLrcSentence
    private var params: [Float] = []

    init(model: MiguLrcSentence) {
        self.model = model
    }

    func startMsTime() -> TimeInterval {
        return model.startTime()
    }

    func endMsTime() -> TimeInterval {
        return model.endTime()
    }

    func render(with cell: UILabel) {
        if params.count < model.tones.count {
            let lyric = cell.text
            let fullWidth = cell.sizeThatFits(CGSize(width: CGFloat(MAXFLOAT), height: cell.font.lineHeight)).width
            model.tones.forEach { tone in
                cell.text = tone.word
                let width = cell.sizeThatFits(CGSize(width: CGFloat(MAXFLOAT), height: cell.font.lineHeight)).width
                let param = Float(width / fullWidth)
                params.append(param)
            }
            cell.text = lyric
        }
    }

    func getProgress(consume: TimeInterval, totalMsTime _: TimeInterval) -> Float {
        if params.count < model.tones.count {
            return 0
        }
        let consume = consume + startMsTime()
        if consume >= endMsTime() {
            return 1
        }
        let firstIndex = model.tones.enumerated().first { item in
            let tone = item.element
            let index = item.offset
            let next = index > model.tones.count - 2 ? nil : model.tones[index + 1]
            return (tone.begin <= consume && tone.end >= consume) || next == nil || next!.begin > consume
        }?.offset
        if let firstIndex = firstIndex {
            return model.tones.enumerated().map { item -> Float in
                let index = item.offset
                if index > firstIndex {
                    return 0
                } else if index == firstIndex {
                    let tone = model.tones[index]
                    let x = consume - tone.begin
                    let diff = tone.end - tone.begin
                    if x > 0, diff != 0 {
                        return Float(min(x, diff) / diff) * params[index]
                    } else {
                        return 0
                    }
                } else {
                    return params[index]
                }
            }.reduce(0) { last, now in
                last + now
            }
        } else if (model.tones.first?.begin ?? consume + 1) > consume {
            return 0
        } else {
            return 1
        }
    }

    func getSentence() -> String {
        return model.toSentence()
    }

    func timeString() -> String {
        return Utils.format(time: startMsTime() / 1000)
    }
}
