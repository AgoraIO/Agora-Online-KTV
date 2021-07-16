//
//  DownloadManager.swift
//  Core
//
//  Created by XC on 2021/6/29.
//

import Foundation

public enum DownloadResult {
    case success(file: String)
    case failed(error: String)
}

public class DownloadManager {
    public static let shared = DownloadManager()

    private init() {}

    public func getFile(url: String, completion: @escaping (DownloadResult) -> Void) -> URLSessionTask? {
        Logger.log(self, message: "getFile: \(url)", level: .info)
        let _url = URL(string: url)
        if let _url = _url {
            do {
                let documentsURL = try FileManager.default.url(for: .cachesDirectory,
                                                               in: .userDomainMask,
                                                               appropriateFor: nil,
                                                               create: false)
                let savedURL = documentsURL.appendingPathComponent(_url.lastPathComponent)
//                if FileManager.default.fileExists(atPath: savedURL.path) {
//                    try FileManager.default.removeItem(at: savedURL)
//                }
                if FileManager.default.fileExists(atPath: savedURL.path) {
                    completion(DownloadResult.success(file: savedURL.path))
                } else {
                    let downloadTask = URLSession.shared.downloadTask(with: _url) { urlOrNil, _, _ in
                        guard let fileURL = urlOrNil else {
                            completion(DownloadResult.failed(error: "url is Empty!"))
                            return
                        }
                        do {
                            try FileManager.default.moveItem(at: fileURL, to: savedURL)
                            completion(DownloadResult.success(file: savedURL.path))
                        } catch {
                            completion(DownloadResult.failed(error: error.localizedDescription))
                        }
                    }
                    downloadTask.resume()
                    return downloadTask
                }
            } catch {
                completion(DownloadResult.failed(error: error.localizedDescription))
            }
        } else {
            completion(DownloadResult.failed(error: "url is Empty!"))
        }
        return nil
    }
}
