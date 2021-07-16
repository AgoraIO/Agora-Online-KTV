//
//  SyncManagerProxy.swift
//  Scene-Examples_LeanCloud
//
//  Created by XC on 2021/6/1.
//
#if LEANCLOUD
    import Core
    import Foundation
    import LeanCloud

    class AgoraObject: IAgoraObject {
        private let object: LCObject

        init(object: LCObject) {
            self.object = object
        }

        func getId() throws -> String {
            return object.objectId!.stringValue!
        }

        func getValue(key: String, type: Any.Type) throws -> Any? {
            if key == "createdAt" {
                return object.get(key)?.dateValue
            }
            if type == String.self {
                return object.get(key)?.stringValue
            } else if type == Int.self {
                return object.get(key)?.intValue
            } else if type == Bool.self {
                return object.get(key)?.boolValue
            } else if type == UInt.self {
                return object.get(key)?.uintValue
            } else if type == AgoraDocumentReference.self {
                let obj = object.get(key) as! LCObject
                return AgoraDocumentReference(parent: nil, id: obj.objectId!.stringValue!)
            }
            return nil
        }

        func toObject<T>() throws -> T where T: Decodable {
            let data: Data
            if #available(iOS 11.0, *) {
                data = try NSKeyedArchiver.archivedData(withRootObject: object, requiringSecureCoding: false)
            } else {
                data = NSKeyedArchiver.archivedData(withRootObject: object)
            }
            return try JSONDecoder().decode(T.self, from: data)
        }
    }

    class AgoraLiveQuery: ISyncManagerLiveQuery {
        private var liveQuery: LiveQuery?
        private let className: String

        init(className: String, liveQuery: LiveQuery?) {
            self.className = className
            self.liveQuery = liveQuery
        }

        func unsubscribe() {
            liveQuery?.unsubscribe { result in
                switch result {
                case .success:
                    Logger.log(message: "----- unsubscribe \(self.className) success -----", level: .info)
                case let .failure(error: error):
                    Logger.log(message: "----- unsubscribe \(self.className) error:\(error) -----", level: .error)
                }
            }
            liveQuery = nil
        }
    }

    class LeanCloudSyncManager: ISyncManager {
        func createAgoraRoom(_ room: AgoraRoom, _ delegate: IAgoraObjectDelegate) {
            let object = LCObject(className: AgoraRoom.TABLE)
            let acl = LCACL()
            acl.setAccess([.read, .write], allowed: true)
            object.ACL = acl
            do {
                for item in room.toDictionary() {
                    Logger.log(message: "createAgoraRoom key:\(item.key) value:\(item.value ?? "nil")", level: .info)
                    try object.set(item.key, value: item.value as? LCValueConvertible)
                }
                object.save(completionQueue: Database.completionQueue, completion: { result in
                    switch result {
                    case .success:
                        delegate.onSuccess(result: AgoraObject(object: object))
                    case let .failure(error: error):
                        Logger.log(message: "createAgoraRoom failure:\(error.code)", level: .error)
                        delegate.onFailed(code: error.code, msg: error.description)
                    }
                })
            } catch {
                delegate.onFailed(code: -1, msg: error.localizedDescription)
            }
        }

        func getAgoraRooms(_ delegate: IAgoraObjectListDelegate) {
            let query = LCQuery(className: AgoraRoom.TABLE)
            do {
                try query.where("createdAt", .descending)
                let time = Date(timeIntervalSinceNow: -24 * 60 * 60)
                try query.where("createdAt", .greaterThanOrEqualTo(time))
                query.find(completionQueue: Database.completionQueue, completion: { result in
                    switch result {
                    case let .success(objects: list):
                        delegate.onSuccess(result: list.map { (object: LCObject) in
                            AgoraObject(object: object)
                        })
                    case let .failure(error: error):
                        delegate.onFailed(code: error.code, msg: error.description)
                    }
                })
            } catch {
                delegate.onFailed(code: -1, msg: error.localizedDescription)
            }
        }

        func get(_ reference: AgoraDocumentReference, _ delegate: IAgoraObjectDelegate) {
            let query = LCQuery(className: reference.className)
            query.get(reference.id, completionQueue: Database.completionQueue, completion: { result in
                switch result {
                case let .success(object: data):
                    delegate.onSuccess(result: AgoraObject(object: data))
                case let .failure(error: error):
                    delegate.onFailed(code: error.code, msg: error.description)
                }
            })
        }

        func get(_ reference: AgoraCollectionReference, _ delegate: IAgoraObjectListDelegate) {
            let roomId = reference.parent.id
            let roomObject = LCObject(className: AgoraRoom.TABLE, objectId: roomId)
            let query = LCQuery(className: reference.className)
            do {
                try query.where("roomId", .equalTo(roomObject))
                try query.where("createdAt", .ascending)
                query.find(completionQueue: Database.completionQueue, completion: { result in
                    switch result {
                    case let .success(objects: list):
                        Logger.log(self, message: "get AgoraCollectionReference \(list.count)", level: .info)
                        delegate.onSuccess(result: list.map { (object: LCObject) in
                            AgoraObject(object: object)
                        })
                    case let .failure(error: error):
                        delegate.onFailed(code: error.code, msg: error.description)
                    }
                })
            } catch {
                delegate.onFailed(code: -1, msg: error.localizedDescription)
            }
        }

        func add(_ reference: AgoraCollectionReference, _ data: [String: Any?], _ delegate: IAgoraObjectDelegate) {
            let className = reference.className
            let object = LCObject(className: className)
            let roomId = reference.parent.id
            let roomObject = LCObject(className: AgoraRoom.TABLE, objectId: roomId)
            do {
                for value in data {
                    try object.set(value.key, value: value.value as? LCValueConvertible)
                }
                try object.set("roomId", value: roomObject)
                let acl = LCACL()
                acl.setAccess([.read, .write], allowed: true)
                object.ACL = acl
                object.save(completionQueue: Database.completionQueue, completion: { result in
                    switch result {
                    case .success:
                        delegate.onSuccess(result: AgoraObject(object: object))
                    case let .failure(error: error):
                        delegate.onFailed(code: error.code, msg: error.description)
                    }
                })
            } catch {
                delegate.onFailed(code: -1, msg: error.localizedDescription)
            }
        }

        func update(_ reference: AgoraDocumentReference, _ data: [String: Any?], _ delegate: IAgoraObjectDelegate) {
            let object = LCObject(className: reference.className, objectId: reference.id)
            do {
                for value in data {
                    try object.set(value.key, value: value.value as? LCValueConvertible)
                }
                let acl = LCACL()
                acl.setAccess([.read, .write], allowed: true)
                object.ACL = acl
                object.save(completionQueue: Database.completionQueue, completion: { result in
                    switch result {
                    case .success:
                        delegate.onSuccess(result: AgoraObject(object: object))
                    case let .failure(error: error):
                        delegate.onFailed(code: error.code, msg: error.description)
                    }
                })
            } catch {
                delegate.onFailed(code: -1, msg: error.localizedDescription)
            }
        }

        func delete(_ reference: AgoraDocumentReference, _ delegate: IAgoraDocumentReferenceDelegate) {
            if reference.id != "" {
                let object = LCObject(className: reference.className, objectId: reference.id)
                object.delete { _result in
                    switch _result {
                    case .success:
                        delegate.onSuccess()
                    case let .failure(error: error):
                        delegate.onFailed(code: error.code, msg: error.description)
                    }
                }
            } else if reference.whereEQ.count > 0 {
                let query = LCQuery(className: reference.className)
                do {
                    for eqs in reference.whereEQ {
                        let key = eqs.key
                        let value = eqs.value
                        if value is AgoraDocumentReference {
                            let ref: AgoraDocumentReference = value as! AgoraDocumentReference
                            try query.where(key, .equalTo(LCObject(className: ref.className, objectId: ref.id)))
                        } else {
                            try query.where(key, .equalTo(value as! LCValueConvertible))
                        }
                    }
                    query.find(completionQueue: Database.completionQueue, completion: { result in
                        switch result {
                        case let .success(objects: list):
                            LCObject.delete(list) { _result in
                                switch _result {
                                case .success:
                                    delegate.onSuccess()
                                case let .failure(error: error):
                                    delegate.onFailed(code: error.code, msg: error.description)
                                }
                            }
                        case let .failure(error: error):
                            if error.code == 101 {
                                delegate.onSuccess()
                            } else {
                                delegate.onFailed(code: error.code, msg: error.description)
                            }
                        }
                    })
                } catch {
                    delegate.onFailed(code: -1, msg: error.localizedDescription)
                }
            } else {
                delegate.onFailed(code: -1, msg: "can not delete reference!")
            }
        }

        func delete(_ reference: AgoraCollectionReference, _ delegate: IAgoraDocumentReferenceDelegate) {
            let query = LCQuery(className: reference.className)
            let room = LCObject(className: reference.parent.className, objectId: reference.parent.id)
            do {
                try query.where("roomId", .equalTo(room))
                query.find(completionQueue: Database.completionQueue, completion: { result in
                    switch result {
                    case let .success(objects: list):
                        LCObject.delete(list) { _result in
                            switch _result {
                            case .success:
                                delegate.onSuccess()
                            case let .failure(error: error):
                                delegate.onFailed(code: error.code, msg: error.description)
                            }
                        }
                    case let .failure(error: error):
                        if error.code == 101 {
                            delegate.onSuccess()
                        } else {
                            delegate.onFailed(code: error.code, msg: error.description)
                        }
                    }
                })
            } catch {
                delegate.onFailed(code: -1, msg: error.localizedDescription)
            }
        }

        func subscribe(_ reference: AgoraDocumentReference, _ delegate: ISyncManagerEventDelegate) -> ISyncManagerLiveQuery {
            let className = reference.className
            let query = LCQuery(className: className)
            var liveQuery: LiveQuery?
            do {
                for eqs in reference.whereEQ {
                    let key = eqs.key
                    let value = eqs.value
                    if value is AgoraDocumentReference {
                        let ref: AgoraDocumentReference = value as! AgoraDocumentReference
                        try query.where(key, .equalTo(LCObject(className: ref.className, objectId: ref.id)))
                    } else {
                        try query.where(key, .equalTo(value as! LCValueConvertible))
                    }
                }
                if let parent = reference.parent {
                    try query.where("roomId", .equalTo(LCObject(className: AgoraRoom.TABLE, objectId: parent.parent.id)))
                } else if reference is AgoraRoomReference {
                    try query.where("objectId", .equalTo(reference.id))
                }
                liveQuery = try LiveQuery(query: query, eventHandler: { _, event in
                    Logger.log(message: "liveQueryEvent event:\(event)", level: .info)
                    switch event {
                    case let .create(object: object):
                        delegate.onCreated(object: AgoraObject(object: object))
                    case let .delete(object: object):
                        delegate.onDeleted(objectId: object.objectId!.stringValue!)
                    case .update(object: let object, updatedKeys: _):
                        delegate.onUpdated(object: AgoraObject(object: object))
                    case let .state(state):
                        switch state {
                        case .subscribed:
                            delegate.onSubscribed()
                        default: break
                        }
                    default: break
                    }
                })
                liveQuery!.subscribe { result in
                    switch result {
                    case .success:
                        Logger.log(message: "----- subscribe \(className) success -----", level: .info)
                        return
                    case let .failure(error: error):
                        Logger.log(message: "subscribe1 \(className) error:\(error)", level: .error)
                        delegate.onError(code: error.code, msg: error.description)
                        return
                    }
                }
            } catch {
                Logger.log(message: "subscribe0 \(className) error:\(error)", level: .error)
                delegate.onError(code: -1, msg: error.localizedDescription)
            }
            return AgoraLiveQuery(className: className, liveQuery: liveQuery)
        }
    }

#endif
