//
//  UserManagerProxy.swift
//  Core
//
//  Created by XC on 2021/6/1.
//
#if LEANCLOUD
    import Core
    import Foundation
    import LeanCloud
    import RxSwift

    class LeanCloudUserManager: IUserManager {
        static func from(object: LCObject) throws -> User {
            let name: String = object.get(User.NAME)!.stringValue!
            let avatar: String = object.get(User.AVATAR)!.stringValue!
            return User(id: object.objectId!.stringValue!, name: name, avatar: avatar)
        }

        func randomUser() -> Observable<Result<User>> {
            let user = User(id: "", name: Utils.randomString(length: 8), avatar: Utils.randomAvatar())
            return create(user: user).map { result in
                if result.success {
                    user.id = result.data!
                    return Result(success: true, data: user)
                } else {
                    return Result(success: false, message: result.message)
                }
            }
        }

        func create(user: User) -> Observable<Result<String>> {
            return Database.save {
                let object = LCObject(className: User.TABLE)
                try object.set(User.NAME, value: user.name)
                try object.set(User.AVATAR, value: user.avatar)
                return object
            }
        }

        func getUser(by objectId: String) -> Observable<Result<User>> {
            return Database.query(
                className: User.TABLE,
                objectId: objectId,
                queryWhere: nil,
                transform: { (data: LCObject) -> User in
                    try LeanCloudUserManager.from(object: data)
                }
            )
        }

        func update(user: User, name: String) -> Observable<Result<Void>> {
            return Database.save {
                let object = LCObject(className: User.TABLE, objectId: user.id)
                try object.set(User.NAME, value: name)
                return object
            }
            .map { result in
                if result.success {
                    user.name = name
                }
                return Result(success: result.success, message: result.message)
            }
        }

        func getMusicList(key: String?) -> Observable<Result<[LrcMusic]>> {
            if let key = key {
                return Database.query(className: "MUSIC_REPOSITORY", queryWhere: { query in
                    try query.where("name", .matchedSubstring(key))
                }) { (list: [LCObject]) in
                    list.map { data in
                        let id = data.get("musicId")!.stringValue!
                        let name = data.get("name")!.stringValue!
                        return LrcMusic(id: id, name: name, song: "", lrc: "")
                    }
                }
            } else {
                return Database.query(className: "MUSIC_REPOSITORY", queryWhere: nil) { (list: [LCObject]) in
                    list.map { data in
                        let id = data.get("musicId")!.stringValue!
                        let name = data.get("name")!.stringValue!
                        return LrcMusic(id: id, name: name, song: "", lrc: "")
                    }
                }
            }
        }

        func getMusic(id: String) -> Observable<Result<LrcMusic>> {
            return Single.create { single in
                LCEngine.run("getMusic", parameters: ["id": id], completionQueue: Database.completionQueue) { result in
                    switch result {
                    case let .success(value: value):
                        if let results = value as! String? {
                            do {
                                let data: LrcMusic = try JSONDecoder().decode(LrcMusic.self, from: Data(results.utf8))
                                single(.success(Result(success: true, data: data)))
                            } catch {
                                single(.success(Result(success: false, message: error.localizedDescription)))
                            }
                        } else {
                            single(.success(Result(success: false, message: "empty result!")))
                        }
                    case let .failure(error: error):
                        single(.success(Result(success: false, message: error.description)))
                    }
                }
                return Disposables.create()
            }.asObservable()
        }
    }

#endif
