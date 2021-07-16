//
//  LiveKtvRoom.swift
//  LiveKtv
//
//  Created by XC on 2021/6/8.
//

import Core
import Foundation
import RxSwift

class LiveKtvRoom: AgoraRoom, Equatable {
    public static func == (lhs: LiveKtvRoom, rhs: LiveKtvRoom) -> Bool {
        return lhs.id == rhs.id
    }

    enum CodingKeys: String, CodingKey {
        case id
        case ownerId
        case name
        case cover
        case mv
        case count
    }

    public var channelName: String
    public var count: Int = 0
    public var cover: String?
    public var mv: String?
    public var createdAt: Date?

    public init(id: String, userId: String, channelName: String, cover: String?, mv: String?) {
        self.channelName = channelName
        self.cover = cover
        self.mv = mv
        super.init(id: id, userId: userId)
    }

    private init(id: String, userId: String, channelName: String, cover: String?, mv: String?, count: Int) {
        self.channelName = channelName
        self.cover = cover
        self.mv = mv
        self.count = count
        super.init(id: id, userId: userId)
    }

    required convenience init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let id = try values.decode(String.self, forKey: .id)
        let ownerId = try values.decode(String.self, forKey: .ownerId)
        let name = try values.decode(String.self, forKey: .name)
        let cover = try values.decode(String.self, forKey: .cover)
        let mv = try values.decode(String.self, forKey: .mv)
        let count = try values.decode(Int.self, forKey: .count)
        self.init(id: id, userId: ownerId, channelName: name, cover: cover, mv: mv, count: count)
    }

    override public func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(id, forKey: .id)
        try values.encode(userId, forKey: .ownerId)
        try values.encode(channelName, forKey: .name)
        try values.encode(cover, forKey: .cover)
        try values.encode(mv, forKey: .mv)
        try values.encode(count, forKey: .count)
    }

    override func toDictionary() -> [String: Any?] {
        return [
            LiveKtvRoom.OWNER_ID: userId,
            LiveKtvRoom.NAME: channelName,
            LiveKtvRoom.COVER: cover,
            LiveKtvRoom.MV: mv,
        ]
    }
}

extension LiveKtvRoom {
    static let OWNER_ID = "userId"
    static let NAME = "channelName"
    static let COVER = "cover"
    static let MV = "mv"

    private static let CHECK_TIME_UP = true
    private static let TIME_UP: Double = 10 * 60

    private static var manager: SyncManager {
        SyncManager.shared
    }

    static func get(object: IAgoraObject, check: Bool = false) throws -> LiveKtvRoom {
        let id = try object.getId()
        let ownerId = try object.getValue(key: LiveKtvRoom.OWNER_ID, type: String.self) as! String
        let name = try object.getValue(key: LiveKtvRoom.NAME, type: String.self) as! String
        let cover = try object.getValue(key: LiveKtvRoom.COVER, type: String.self) as? String
        let mv = try object.getValue(key: LiveKtvRoom.MV, type: String.self) as? String
        let createdAt = try object.getValue(key: "createdAt", type: Date.self) as? Date
        if check, CHECK_TIME_UP {
            if let createdAt = createdAt {
                let passTime = Date().timeIntervalSince1970 - createdAt.timeIntervalSince1970
                if passTime >= TIME_UP {
                    throw AgoraError(message: "当前房间直播时间超时！")
                }
            }
        }
        let room = LiveKtvRoom(id: id, userId: ownerId, channelName: name, cover: cover, mv: mv)
        room.createdAt = createdAt
        return room
    }

    static func create(room: LiveKtvRoom) -> Observable<Result<String>> {
        return Single.create { single in
            let delegate = AgoraObjectDelegate { object in
                do {
                    let id: String = try object.getId()
                    single(.success(Result(success: true, data: id)))
                } catch {
                    single(.success(Result(success: false, message: error.localizedDescription)))
                }
            } failed: { _, message in
                single(.success(Result(success: false, message: message)))
            }
            manager.createAgoraRoom(room: room, delegate: delegate)
            return Disposables.create()
        }.asObservable()
    }

    static func delete(roomId: String) -> Observable<Result<Void>> {
        return Single.create { single in
            let delegate = AgoraDocumentReferenceDelegate {
                single(.success(Result<Void>(success: true)))
            } failed: { _, message in
                single(.success(Result<Void>(success: false, message: message)))
            }
            let ref = AgoraRoomReference(id: roomId)
            LiveKtvRoom.manager.delete(reference: ref, delegate: delegate)
            return Disposables.create()
        }.asObservable()
    }

    static func getRooms() -> Observable<Result<[LiveKtvRoom]>> {
        return Single.create { single in
            let delegate = AgoraObjectListDelegate { (result: [IAgoraObject]) in
                do {
                    let rooms = try result.map { object -> LiveKtvRoom in
                        try get(object: object)
                    }
                    single(.success(Result(success: true, data: rooms)))
                } catch {
                    single(.success(Result(success: false, message: error.localizedDescription)))
                }
            } failed: { _, message in
                single(.success(Result(success: false, message: message)))
            }

            manager.getAgoraRooms(delegate: delegate)
            return Disposables.create()
        }.asObservable()
    }

    static func getRoom(by objectId: String) -> Observable<Result<LiveKtvRoom>> {
        return Single.create { single in
            let delegate = AgoraObjectDelegate { object in
                do {
                    let data = try get(object: object, check: true)
                    single(.success(Result(success: true, data: data)))
                } catch {
                    single(.success(Result(success: false, message: error.localizedDescription)))
                }
            } failed: { _, message in
                single(.success(Result(success: false, message: message)))
            }
            manager.getRoom(id: objectId).get(delegate: delegate)
            return Disposables.create()
        }.asObservable()
    }

    static func queryMemberCount(by roomId: String) -> Observable<Result<Int>> {
        return Single.create { single in
            manager.getRoom(id: roomId)
                .collection(className: LiveKtvMember.TABLE)
                .get(delegate: AgoraObjectListDelegate(success: { objects in
                    single(.success(Result<Int>(success: true, data: objects.count)))
                }, failed: { _, message in
                    single(.success(Result<Int>(success: false, message: message)))
                }))
            return Disposables.create()
        }.asObservable()
    }

    func getMembers() -> Observable<Result<[LiveKtvMember]>> {
        return Single.create { single in
            let delegate = AgoraObjectListDelegate { (result: [IAgoraObject]) in
                do {
                    let members = try result.map { object -> LiveKtvMember in
                        try LiveKtvMember.get(object: object, room: self)
                    }
                    single(.success(Result(success: true, data: members)))
                } catch {
                    single(.success(Result(success: false, message: error.localizedDescription)))
                }
            } failed: { _, message in
                single(.success(Result(success: false, message: message)))
            }
            LiveKtvRoom.manager.getRoom(id: self.id)
                .collection(className: LiveKtvMember.TABLE)
                .get(delegate: delegate)
            return Disposables.create()
        }.asObservable()
    }

    func getMusicList() -> Observable<Result<[LiveKtvMusic]>> {
        return Single.create { single in
            let delegate = AgoraObjectListDelegate { (result: [IAgoraObject]) in
                do {
                    let list = try result.map { object -> LiveKtvMusic in
                        try LiveKtvMusic.get(object: object, room: self)
                    }
                    single(.success(Result(success: true, data: list)))
                } catch {
                    single(.success(Result(success: false, message: error.localizedDescription)))
                }
            } failed: { _, message in
                single(.success(Result(success: false, message: message)))
            }
            LiveKtvRoom.manager.getRoom(id: self.id)
                .collection(className: LiveKtvMusic.TABLE)
                .get(delegate: delegate)
            return Disposables.create()
        }.asObservable()
    }

    func subscribeMembers() -> Observable<Result<[LiveKtvMember]>> {
        return Observable<Result<Void>>.create { [unowned self] observer -> Disposable in
            let handler = LiveKtvRoom.manager
                .getRoom(id: self.id)
                .collection(className: LiveKtvMember.TABLE)
                .document()
                .subscribe(delegate: AgoraSyncManagerEventDelegate(onEvent: { _ in
                    observer.onNext(Result<Void>(success: true))
                }, failed: { _, message in
                    observer.onNext(Result<Void>(success: false, message: message))
                    // observer.onCompleted()
                }))
            return Disposables.create {
                handler.unsubscribe()
            }
        }
        .startWith(Result<Void>(success: true))
        .flatMap { [unowned self] result -> Observable<Result<[LiveKtvMember]>> in
            result.onSuccess { self.getMembers() }
        }
    }

    func subscribeMusicList() -> Observable<Result<[LiveKtvMusic]>> {
        return Observable<Result<Void>>.create { [unowned self] observer -> Disposable in
            let handler = LiveKtvRoom.manager
                .getRoom(id: self.id)
                .collection(className: LiveKtvMusic.TABLE)
                .document()
                .subscribe(delegate: AgoraSyncManagerEventDelegate(onEvent: { _ in
                    observer.onNext(Result<Void>(success: true))
                }, failed: { _, message in
                    observer.onNext(Result<Void>(success: false, message: message))
                    // observer.onCompleted()
                }))
            return Disposables.create {
                handler.unsubscribe()
            }
        }
        .startWith(Result<Void>(success: true))
        .flatMap { [unowned self] result -> Observable<Result<[LiveKtvMusic]>> in
            result.onSuccess { self.getMusicList() }
        }
    }

    func subscribe() -> Observable<Result<LiveKtvRoom>> {
        return Observable.create { [unowned self] observer -> Disposable in
            let handler = LiveKtvRoom.manager
                .getRoom(id: self.id)
                .subscribe(delegate: AgoraSyncManagerEventDelegate(onEvent: { event in
                    do {
                        switch event {
                        case let .create(object: object):
                            observer.onNext(Result<LiveKtvRoom>(success: true, data: try LiveKtvRoom.get(object: object)))
                        case let .update(object: object):
                            let room = try LiveKtvRoom.get(object: object)
                            self.channelName = room.channelName
                            self.cover = room.cover
                            self.mv = room.mv
                            observer.onNext(Result<LiveKtvRoom>(success: true, data: room))
                        case let .delete(id: id):
                            Logger.log(self, message: "(\(id)) delete", level: .info)
                            observer.onNext(Result<LiveKtvRoom>(success: true, data: nil))
                        case .subscribed:
                            observer.onNext(Result<LiveKtvRoom>(success: true, data: self))
                        }
                    } catch {
                        observer.onNext(Result<LiveKtvRoom>(success: false, message: error.localizedDescription))
                    }
                }, failed: { _, message in
                    observer.onNext(Result<LiveKtvRoom>(success: false, message: message))
                    observer.onCompleted()
                }))
            return Disposables.create {
                handler.unsubscribe()
            }
        }.startWith(Result(success: true, data: self))
    }

    func timeUp() -> Observable<Result<LiveKtvRoom>> {
        if LiveKtvRoom.CHECK_TIME_UP, let createdAt = createdAt {
            let leftTime = Int(LiveKtvRoom.TIME_UP - Date().timeIntervalSince1970 + createdAt.timeIntervalSince1970)
            Logger.log(self, message: "leftTime: \(leftTime) date: \(createdAt)", level: .info)
            if leftTime >= Int(LiveKtvRoom.TIME_UP) || leftTime <= 0 {
                return Observable.just(Result(success: true, data: nil, message: "试用时间已到！"))
            } else {
                return Observable.just(Result(success: true, data: nil, message: "试用时间已到！"))
                    .delay(RxTimeInterval.seconds(leftTime), scheduler: MainScheduler.instance)
            }
        } else {
            return Observable.just(Result(success: true, data: self))
        }
    }

    func changeMV(localMV: String) -> Observable<Result<Void>> {
        return Single.create { single in
            let mv = LiveKtvRoom.getMV(local: localMV)
            if mv == self.mv {
                single(.success(Result<Void>(success: true)))
            } else {
                LiveKtvRoom.manager
                    .getRoom(id: self.id)
                    .update(data: [LiveKtvRoom.MV: LiveKtvRoom.getMV(local: localMV)], delegate: AgoraObjectDelegate(success: { _ in
                        single(.success(Result<Void>(success: true)))
                    }, failed: { _, message in
                        single(.success(Result<Void>(success: false, message: message)))
                    }))
            }
            return Disposables.create()
        }.asObservable()
    }
}
