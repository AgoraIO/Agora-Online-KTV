//
//  LiveKtvMusic.swift
//  LiveKtv
//
//  Created by XC on 2021/6/10.
//

import Core
import Foundation
import RxSwift

class LiveKtvMusic: Codable, IAgoraModel {
    public static let NORMAL = 0
    public static let CHORUS = 1

    public var id: String
    public var roomId: String
    public var name: String
    public var musicId: String

    public var type: Int

    public var userId: String
    public var userStatus: Int?

    public var user1Id: String?
    public var user1Status: Int?

    public var applyUser1Id: String?

    init(id: String, userId: String, roomId: String, name: String, musicId: String, type: Int = LiveKtvMusic.NORMAL) {
        self.id = id
        self.userId = userId
        self.roomId = roomId
        self.name = name
        self.musicId = musicId
        self.type = type
    }

    func isOrderBy(member: LiveKtvMember) -> Bool {
        return userId == member.userId
    }

    func toDictionary() -> [String: Any?] {
        return [
            LiveKtvMusic.NAME: name,
            LiveKtvMusic.MUSIC_ID: musicId,
            LiveKtvMusic.ROOM: roomId,
            LiveKtvMusic.USER: userId,
        ]
    }
}

extension LiveKtvMusic {
    static let TABLE: String = "MUSIC_KTV"
    static let ROOM: String = "roomId"
    static let USER = "userId"
    static let NAME = "name"
    static let MUSIC_ID = "musicId"

    private static var manager: SyncManager {
        SyncManager.shared
    }

    static func get(object: IAgoraObject, room: LiveKtvRoom) throws -> LiveKtvMusic {
        let id = try object.getId()
        let name: String = try object.getValue(key: LiveKtvMusic.NAME, type: String.self) as! String
        let music: String = try object.getValue(key: LiveKtvMusic.MUSIC_ID, type: String.self) as! String
        let roomId = room.id
        let userId: String = try object.getValue(key: LiveKtvMusic.USER, type: String.self) as! String
        return LiveKtvMusic(id: id, userId: userId, roomId: roomId, name: name, musicId: music)
    }

//    static func get(object: IAgoraObject, member: LiveKtvMember) throws -> LiveKtvMusic {
//        let id = try object.getId()
//        let name: String = try object.getValue(key: LiveKtvMusic.NAME, type: String.self) as! String
//        let music: String = try object.getValue(key: LiveKtvMusic.MUSIC_ID, type: String.self) as! String
//        let roomId = member.roomId
//        let memberId: String = member.id // try object.getValue(key: LiveKtvMusic.MEMBER, type: String.self) as! String
//        return LiveKtvMusic(id: id, memberId: memberId, roomId: roomId, name: name, musicId: music)
//    }

    func order() -> Observable<Result<LiveKtvMusic>> {
        return Single.create { single in
            LiveKtvMusic.manager
                .getRoom(id: self.roomId)
                .collection(className: LiveKtvMusic.TABLE)
                .add(data: self.toDictionary(), delegate: AgoraObjectDelegate(success: { object in
                    do {
                        self.id = try object.getId()
                        single(.success(Result(success: true, data: self)))
                    } catch {
                        single(.success(Result(success: false, message: error.localizedDescription)))
                    }
                }, failed: { _, message in
                    single(.success(Result(success: false, message: message)))
                }))
            return Disposables.create()
        }.asObservable()
    }

    func delete() -> Observable<Result<Void>> {
        return Single.create { single in
            LiveKtvMusic.manager
                .getRoom(id: self.roomId)
                .collection(className: LiveKtvMusic.TABLE)
                .document(id: self.id)
                .delete(delegate: AgoraDocumentReferenceDelegate(success: {
                    single(.success(Result(success: true)))
                }, failed: { _, message in
                    single(.success(Result(success: false, message: message)))
                }))
            return Disposables.create()
        }.asObservable()
    }

    static func delete(roomId: String) -> Observable<Result<Void>> {
        return Single.create { single in
            LiveKtvMusic.manager
                .getRoom(id: roomId)
                .collection(className: LiveKtvMusic.TABLE)
                .delete(delegate: AgoraDocumentReferenceDelegate(success: {
                    single(.success(Result(success: true)))
                }, failed: { _, message in
                    single(.success(Result(success: false, message: message)))
                }))

            return Disposables.create()
        }.asObservable()
    }

    static func delete(roomId: String, userId: String) -> Observable<Result<Void>> {
        return Single.create { single in
            LiveKtvMusic.manager
                .getRoom(id: roomId)
                .collection(className: LiveKtvMusic.TABLE)
                .document()
                .whereEqual(key: LiveKtvMusic.USER, value: userId)
                .delete(delegate: AgoraDocumentReferenceDelegate(success: {
                    single(.success(Result(success: true)))
                }, failed: { _, message in
                    single(.success(Result(success: false, message: message)))
                }))

            return Disposables.create()
        }.asObservable()
    }
}
