// Copyright © 2026 Devault. All rights reserved

import DVDomain

/// 등급과 판정 결과를 고정으로 돌려주는 테스트용 ``EntitlementUseCase``.
///
/// 기본값은 **모든 게이트를 여는 Pro**다. 게이트와 무관한 테스트가 판정 때문에 실패하지 않게 하기 위한 것이며, 잠금을 검증하는 테스트만 `canEditSecretsValue` 등을 내려 쓴다.
public final class StubEntitlementUseCase: EntitlementUseCase, @unchecked Sendable {

    public var entitlementValue: Entitlement
    public var canCreateSecretValue: Bool
    public var canCreateProjectValue: Bool
    public var canEditSecretsValue: Bool
    public var canImportSecretsValue: Bool

    /// 판정 호출 횟수. 허용된 변경이 개수를 세지 않고 지나가는지 확인할 때 쓴다.
    public private(set) var canEditSecretsCallCount = 0

    /// 마지막 Import 판정에 넘어온 개수. 호출부가 생성 수가 아닌 전체 항목 수를 넘기는 실수를 잡는다.
    public private(set) var lastImportCount: Int?

    /// 생성 판정 호출 횟수. 개수를 줄이는 동작이 판정을 거치지 않는지 확인할 때 쓴다.
    public private(set) var canCreateSecretCallCount = 0

    /// 판정이 저장소 오류로 실패하는 상황을 만든다. 게이트 차단(`EntitlementError`)과 판정 실패가 갈라지는지 보는 데 쓴다.
    public var judgementError: (any Error)?

    public init(
        entitlement: Entitlement = .pro,
        canCreateSecret: Bool = true,
        canCreateProject: Bool = true,
        canEditSecrets: Bool = true,
        canImportSecrets: Bool = true
    ) {
        self.entitlementValue = entitlement
        self.canCreateSecretValue = canCreateSecret
        self.canCreateProjectValue = canCreateProject
        self.canEditSecretsValue = canEditSecrets
        self.canImportSecretsValue = canImportSecrets
    }

    public func current() -> Entitlement { entitlementValue }

    public func stream() -> AsyncStream<Entitlement> {
        AsyncStream { continuation in
            continuation.yield(entitlementValue)
            continuation.finish()
        }
    }

    public func canCreateSecret() async throws -> Bool {
        canCreateSecretCallCount += 1
        if let judgementError { throw judgementError }
        return canCreateSecretValue
    }

    public func canCreateProject() async throws -> Bool {
        if let judgementError { throw judgementError }
        return canCreateProjectValue
    }

    public func canImportSecrets(count: Int) async throws -> Bool {
        lastImportCount = count
        if let judgementError { throw judgementError }
        return canImportSecretsValue
    }

    public func canEditSecrets() async throws -> Bool {
        canEditSecretsCallCount += 1
        if let judgementError { throw judgementError }
        return canEditSecretsValue
    }

    public func canEnableICloudSync() -> Bool { entitlementValue == .pro }
    public func canUseMultipleExpiryAlertDays() -> Bool { entitlementValue == .pro }
}
