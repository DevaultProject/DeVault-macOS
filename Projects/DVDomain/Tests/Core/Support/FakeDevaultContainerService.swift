// Copyright © 2026 Devault. All rights reserved

import Foundation

@testable import DVDomain

/// 봉인·개봉을 흉내 내고 입력을 기록하는 테스트용 ``DevaultContainerService``. 실제 암복호는 `DevaultContainerServiceImpl` 테스트가 본다.
public final class FakeDevaultContainerService: DevaultContainerService, @unchecked Sendable {

    /// 마지막으로 봉인 요청된 내용. Export가 무엇을 담았는지 확인할 때 쓴다.
    public private(set) var lastPayload: DevaultContainerPayload?
    public private(set) var exportCount = 0

    /// 개봉이 실패하는 상황을 만든다. 에러 표면이 닫히는지 볼 때 쓴다.
    public var errorOnImport: (any Error)?
    /// 개봉 결과로 돌려줄 내용.
    public var importResult = DevaultContainerPayload(secrets: [])

    public init() {}

    public func export(payload: DevaultContainerPayload, password: SensitiveString, expiresAt: Date?) async throws -> Data {
        exportCount += 1
        lastPayload = payload
        return Data("sealed".utf8)
    }

    public func `import`(data: Data, password: SensitiveString) async throws -> DevaultContainerPayload {
        if let errorOnImport { throw errorOnImport }
        return importResult
    }
}
