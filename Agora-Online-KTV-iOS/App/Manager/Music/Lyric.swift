//
//  Lyric.swift
//  LiveKtv
//
//  Created by XC on 2021/6/11.
//

import Core
import Foundation

class LyricModel {
    let msTime: TimeInterval
    let secTime: TimeInterval
    let timeString: String
    let content: String

    init(msTime: TimeInterval, secTime: TimeInterval, timeString: String, content: String) {
        self.msTime = msTime
        self.secTime = secTime
        self.timeString = timeString
        self.content = content
    }

    func toString() -> String {
        return "\(msTime)|\(secTime)|\(timeString)|\(content)"
    }
}

class LyricParser {
    static func parseLyric(filePath: String, isDelBlank: Bool = false) -> [LyricModel] {
        do {
            let lyricStr = try String(contentsOf: URL(fileURLWithPath: filePath), encoding: .utf8)
            return parseLyric(lyricStr: lyricStr, isDelBlank: isDelBlank)
        } catch {
            Logger.log(self, message: error.localizedDescription, level: .error)
            return []
        }
    }

    static func parseLyric(lyricStr: String, isDelBlank: Bool = false) -> [LyricModel] {
        let list = lyricStr.components(separatedBy: "\n")
        var modelArray: [LyricModel] = []
        do {
            let regular = try NSRegularExpression(pattern: "\\[[0-9][0-9]:[0-9][0-9].[0-9]{1,}\\]", options: .caseInsensitive)
            list.forEach { line in
                let array = regular.matches(in: line, options: .reportProgress, range: NSRange(location: 0, length: line.count))
                let content = line.components(separatedBy: "]").last ?? ""
                if !isDelBlank || content != "" {
                    let list: [LyricModel] = array.map { match in
                        let timeStr = String(line[Range(NSRange(location: match.range.location + 1, length: match.range.length - 2), in: line)!])
                        let minStr = String(timeStr[Range(NSRange(location: 0, length: 2), in: timeStr)!])
                        let secStr = String(timeStr[Range(NSRange(location: 3, length: 2), in: timeStr)!])
                        let mseStr = String(timeStr[Range(NSRange(location: 6, length: timeStr.count - 6), in: timeStr)!])

                        let time: TimeInterval = minStr.doubleValue * 60 * 1000 + secStr.doubleValue * 1000 + mseStr.doubleValue
                        let secTime: TimeInterval = time / 1000
                        return LyricModel(msTime: time, secTime: secTime, timeString: Utils.format(time: secTime), content: content)
                    }
                    modelArray.append(contentsOf: list)
                }
            }
        } catch {
            Logger.log(self, message: error.localizedDescription, level: .error)
        }
        return modelArray.sorted { a, b in
            a.msTime <= b.msTime
        }
    }
}
