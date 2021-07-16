//
//  SyncManager.swift
//  Core
//
//  Created by XC on 2021/5/31.
//

import Foundation

public class AgoraError: NSObject, LocalizedError {
    private let message: String

    override public var description: String {
        return message
    }

    public var errorDescription: String? {
        return message
    }

    public init(message: String) {
        self.message = message
    }
}

open class AgoraRoom: Codable {
    public static let TABLE: String = "AGORA_ROOM"

    public var id: String
    public var userId: String

    public init(id: String, userId: String) {
        self.id = id
        self.userId = userId
    }

    open func toDictionary() -> [String: Any?] {
        return [
            "userId": userId,
        ]
    }
}

public protocol IAgoraModel {
    var roomId: String { get set }
    func toDictionary() -> [String: Any?]
}

public protocol IAgoraObject {
    func getId() throws -> String
    // func toObject<T>() throws -> T where T: Decodable
    func getValue(key: String, type: Any.Type) throws -> Any?
}

public protocol IAgoraObjectDelegate {
    func onSuccess(result: IAgoraObject) -> Void
    func onFailed(code: Int, msg: String) -> Void
}

public protocol IAgoraObjectListDelegate {
    func onSuccess(result: [IAgoraObject]) -> Void
    func onFailed(code: Int, msg: String) -> Void
}

public protocol IAgoraDocumentReferenceDelegate {
    func onSuccess() -> Void
    func onFailed(code: Int, msg: String) -> Void
}

public class AgoraDocumentReference {
    public var className: String {
        return parent!.className
    }

    public let id: String
    public let parent: AgoraCollectionReference?

    public var whereEQ = [String: Any]()

    public init(parent: AgoraCollectionReference?, id: String) {
        self.parent = parent
        self.id = id
    }

    public func whereEqual(key: String, value: Any) -> AgoraDocumentReference {
        whereEQ[key] = value
        return self
    }

    public func get(delegate: IAgoraObjectDelegate) {
        SyncManager.shared.get(reference: self, delegate: delegate)
    }

    public func update(data: [String: Any?], delegate: IAgoraObjectDelegate) {
        SyncManager.shared.update(reference: self, data: data, delegate: delegate)
    }

    public func delete(delegate: IAgoraDocumentReferenceDelegate) {
        SyncManager.shared.delete(reference: self, delegate: delegate)
    }

    public func subscribe(delegate: ISyncManagerEventDelegate) -> ISyncManagerLiveQuery {
        return SyncManager.shared.subscribe(reference: self, delegate: delegate)
    }
}

public class AgoraRoomReference: AgoraDocumentReference {
    override public var className: String {
        return AgoraRoom.TABLE
    }

    public init(id: String) {
        super.init(parent: nil, id: id)
    }

    public func collection(className: String) -> AgoraCollectionReference {
        return AgoraCollectionReference(parent: self, className: className)
    }
}

public class AgoraCollectionReference {
    // private var documentRef: AgoraDocumentReference?

    public let className: String
    public let parent: AgoraRoomReference

    public init(parent: AgoraRoomReference, className: String) {
        self.className = className
        self.parent = parent
    }

    public func document(id: String = "") -> AgoraDocumentReference {
        return AgoraDocumentReference(parent: self, id: id)
    }

    public func add(data: [String: Any?], delegate: IAgoraObjectDelegate) {
        SyncManager.shared.add(reference: self, data: data, delegate: delegate)
    }

    public func get(delegate: IAgoraObjectListDelegate) {
        SyncManager.shared.get(reference: self, delegate: delegate)
    }

    public func delete(delegate: IAgoraDocumentReferenceDelegate) {
        SyncManager.shared.delete(reference: self, delegate: delegate)
    }
}

public protocol ISyncManagerEventDelegate {
    func onCreated(object: IAgoraObject) -> Void
    func onUpdated(object: IAgoraObject) -> Void
    func onDeleted(objectId: String) -> Void
    func onSubscribed() -> Void
    func onError(code: Int, msg: String) -> Void
}

public protocol ISyncManagerLiveQuery {
    func unsubscribe() -> Void
}

public protocol ISyncManager {
    func createAgoraRoom(_ room: AgoraRoom, _ delegate: IAgoraObjectDelegate) -> Void
    func getAgoraRooms(_ delegate: IAgoraObjectListDelegate) -> Void
    func get(_ reference: AgoraDocumentReference, _ delegate: IAgoraObjectDelegate) -> Void
    func get(_ reference: AgoraCollectionReference, _ delegate: IAgoraObjectListDelegate) -> Void
    func add(_ reference: AgoraCollectionReference, _ data: [String: Any?], _ delegate: IAgoraObjectDelegate) -> Void
    func update(_ reference: AgoraDocumentReference, _ data: [String: Any?], _ delegate: IAgoraObjectDelegate) -> Void
    func delete(_ reference: AgoraDocumentReference, _ delegate: IAgoraDocumentReferenceDelegate) -> Void
    func delete(_ reference: AgoraCollectionReference, _ delegate: IAgoraDocumentReferenceDelegate) -> Void
    func subscribe(_ reference: AgoraDocumentReference, _ delegate: ISyncManagerEventDelegate) -> ISyncManagerLiveQuery
}

public class SyncManager {
    public static var shared = SyncManager()

    private var proxy: ISyncManager {
        InjectionService.shared.resolve(ISyncManager.self)
    }

    private init() {}

    public func getRoom(id: String) -> AgoraRoomReference {
        return AgoraRoomReference(id: id)
    }

    public func createAgoraRoom(room: AgoraRoom, delegate: IAgoraObjectDelegate) {
        proxy.createAgoraRoom(room, delegate)
    }

    public func getAgoraRooms(delegate: IAgoraObjectListDelegate) {
        proxy.getAgoraRooms(delegate)
    }

    public func get(reference: AgoraDocumentReference, delegate: IAgoraObjectDelegate) {
        proxy.get(reference, delegate)
    }

    public func get(reference: AgoraCollectionReference, delegate: IAgoraObjectListDelegate) {
        proxy.get(reference, delegate)
    }

    public func add(reference: AgoraCollectionReference, data: [String: Any?], delegate: IAgoraObjectDelegate) {
        proxy.add(reference, data, delegate)
    }

    public func update(reference: AgoraDocumentReference, data: [String: Any?], delegate: IAgoraObjectDelegate) {
        proxy.update(reference, data, delegate)
    }

    public func delete(reference: AgoraDocumentReference, delegate: IAgoraDocumentReferenceDelegate) {
        proxy.delete(reference, delegate)
    }

    public func delete(reference: AgoraCollectionReference, delegate: IAgoraDocumentReferenceDelegate) {
        proxy.delete(reference, delegate)
    }

    public func subscribe(reference: AgoraDocumentReference, delegate: ISyncManagerEventDelegate) -> ISyncManagerLiveQuery {
        return proxy.subscribe(reference, delegate)
    }
}
