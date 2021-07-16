//
//  Model.swift
//  LiveKtv
//
//  Created by XC on 2021/6/4.
//

import Core
import Foundation
import RxSwift

class AgoraDocumentReferenceDelegate: IAgoraDocumentReferenceDelegate {
    private let callSuccess: () -> Void
    private let callFailed: (Int, String) -> Void

    init(success: @escaping () -> Void, failed: @escaping (Int, String) -> Void) {
        callSuccess = success
        callFailed = failed
    }

    func onSuccess() {
        callSuccess()
    }

    func onFailed(code: Int, msg: String) {
        callFailed(code, msg)
    }
}

class AgoraObjectDelegate: IAgoraObjectDelegate {
    private let callSuccess: (IAgoraObject) -> Void
    private let callFailed: (Int, String) -> Void

    init(success: @escaping (IAgoraObject) -> Void, failed: @escaping (Int, String) -> Void) {
        callSuccess = success
        callFailed = failed
    }

    func onSuccess(result: IAgoraObject) {
        callSuccess(result)
    }

    func onFailed(code: Int, msg: String) {
        callFailed(code, msg)
    }
}

class AgoraObjectListDelegate: IAgoraObjectListDelegate {
    private let callSuccess: ([IAgoraObject]) -> Void
    private let callFailed: (Int, String) -> Void

    init(success: @escaping ([IAgoraObject]) -> Void, failed: @escaping (Int, String) -> Void) {
        callSuccess = success
        callFailed = failed
    }

    func onSuccess(result: [IAgoraObject]) {
        callSuccess(result)
    }

    func onFailed(code: Int, msg: String) {
        callFailed(code, msg)
    }
}

enum AgoraSyncEvent {
    case create(object: IAgoraObject)
    case update(object: IAgoraObject)
    case delete(id: String)
    case subscribed
}

class AgoraSyncManagerEventDelegate: ISyncManagerEventDelegate {
    private let onEvent: (AgoraSyncEvent) -> Void
    private let callFailed: (Int, String) -> Void

    init(onEvent: @escaping (AgoraSyncEvent) -> Void, failed: @escaping (Int, String) -> Void) {
        self.onEvent = onEvent
        callFailed = failed
    }

    func onCreated(object: IAgoraObject) {
        onEvent(.create(object: object))
    }

    func onUpdated(object: IAgoraObject) {
        onEvent(.update(object: object))
    }

    func onDeleted(objectId: String) {
        onEvent(.delete(id: objectId))
    }

    func onSubscribed() {
        onEvent(.subscribed)
    }

    func onError(code: Int, msg: String) {
        callFailed(code, msg)
    }
}
