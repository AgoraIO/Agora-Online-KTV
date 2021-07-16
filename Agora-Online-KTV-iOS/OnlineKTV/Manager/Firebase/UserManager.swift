//
//  UserManagerProxy.swift
//  Core
//
//  Created by XC on 2021/6/2.
//
#if FIREBASE
    import Core
    import Firebase
    import FirebaseFirestoreSwift
    import Foundation
    import RxSwift

    class FirebaseUserManager: IUserManager {
        static func from(object: DocumentSnapshot) throws -> User {
            let data = object.data()!
            let name: String = data[User.NAME] as! String
            let avatar: String = data[User.AVATAR] as! String
            return User(id: object.documentID, name: name, avatar: avatar)
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
            return Database.save { () -> (String, data: [String: Any], String?) in
                (User.TABLE, [User.NAME: user.name, User.AVATAR: user.avatar as Any], nil)
            }
        }

        func getUser(by objectId: String) -> Observable<Result<User>> {
            return Database.query(className: User.TABLE, objectId: objectId) { (data: DocumentSnapshot) -> User in
                try FirebaseUserManager.from(object: data)
            }
        }

        func update(user: User, name: String) -> Observable<Result<Void>> {
            return Database.save { () -> (String, data: [String: Any], String?) in
                (User.TABLE, [User.NAME: name], user.id)
            }
            .map { result in
                if result.success {
                    user.name = name
                }
                return Result(success: result.success, message: result.message)
            }
        }

        func getMusicList(key _: String?) -> Observable<Result<[LrcMusic]>> {
            return Single.create { single in
                single(.success(Result(success: false, message: "not instance!")))
                return Disposables.create()
            }.asObservable()
        }

        func getMusic(id _: String) -> Observable<Result<LrcMusic>> {
            return Single.create { single in
                single(.success(Result(success: false, message: "not instance!")))
                return Disposables.create()
            }.asObservable()
        }
    }

#endif
