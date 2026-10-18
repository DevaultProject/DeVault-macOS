// Copyright © 2026 Devault. All rights reserved

import DVCore

public struct EntitlementUseCaseImpl: EntitlementUseCase {

    private let secretRepository: any SecretRepository
    private let projectRepository: any ProjectRepository
    private let entitlementProvider: @Sendable () -> Entitlement
    private let entitlementStream: @Sendable () -> AsyncStream<Entitlement>

    /// 등급 공급자를 주입받아 생성한다.
    ///
    /// StoreKit이 붙기 전에는 Composition Root가 `.free`를 고정으로 넘기고, 붙은 뒤에는 `PurchaseService`가 넘긴다. **판정 로직은 그대로 두고 근거만 교체**하기 위한 구조이며, 테스트에서 `.pro`를 주입하는 통로이기도 하다.
    /// - Parameters:
    ///   - secretRepository: Secret 개수 판정에 쓰는 저장소
    ///   - projectRepository: Project 개수 판정에 쓰는 저장소
    ///   - entitlementProvider: 현재 등급을 돌려주는 클로저
    ///   - entitlementStream: 등급 변경 스트림을 만드는 클로저
    public init(
        secretRepository: any SecretRepository,
        projectRepository: any ProjectRepository,
        entitlementProvider: @escaping @Sendable () -> Entitlement,
        entitlementStream: @escaping @Sendable () -> AsyncStream<Entitlement>
    ) {
        self.secretRepository = secretRepository
        self.projectRepository = projectRepository
        self.entitlementProvider = entitlementProvider
        self.entitlementStream = entitlementStream
    }

    public func current() -> Entitlement {
        entitlementProvider()
    }

    public func stream() -> AsyncStream<Entitlement> {
        entitlementStream()
    }

    public func canCreateSecret() async throws -> Bool {
        guard current() == .free else { return log("canCreateSecret", allowed: true) }
        let count = try await secretRepository.totalCountExcludingTrash()
        return log("canCreateSecret", allowed: count < EntitlementLimits.maxSecrets, detail: "보유: \(count)/\(EntitlementLimits.maxSecrets)")
    }

    public func canCreateProject() async throws -> Bool {
        guard current() == .free else { return log("canCreateProject", allowed: true) }
        // Project는 무료 1개 · Pro 무제한이라 목록이 길어질 일이 없다. 전용 count를 두지 않는다.
        let count = try await projectRepository.fetchAll().count
        return log("canCreateProject", allowed: count < EntitlementLimits.maxProjects, detail: "보유: \(count)/\(EntitlementLimits.maxProjects)")
    }

    public func canImportSecrets(count: Int) async throws -> Bool {
        // 생성이 없는 import(전부 덮어쓰기·건너뛰기)는 보유 수를 늘리지 않으므로 이 게이트의 관심사가 아니다. 한도 초과 보유 상태에서도 통과시켜 `canEditSecrets()`가 제 판정을 내리게 둔다 — 여기서 막으면 `limitReached`("더 만들 수 없다")가 나가는데 실제 필요한 안내는 `editLocked`다.
        guard count > 0 else { return log("canImportSecrets", allowed: true, detail: "생성 없음") }
        guard current() == .free else { return log("canImportSecrets", allowed: true) }
        let existing = try await secretRepository.totalCountExcludingTrash()
        return log("canImportSecrets", allowed: existing + count <= EntitlementLimits.maxSecrets, detail: "보유: \(existing)/\(EntitlementLimits.maxSecrets), 요청: \(count)")
    }

    public func canEditSecrets() async throws -> Bool {
        guard current() == .free else { return log("canEditSecrets", allowed: true) }
        // 한도와 **같으면** 허용한다. `canCreateSecret`의 `<`와 달리 여기가 `<=`인 이유는, 정확히 한도만큼 보유한 사용자는 잠기면 안 되기 때문이다. 잠금은 초과부터다.
        let count = try await secretRepository.totalCountExcludingTrash()
        return log("canEditSecrets", allowed: count <= EntitlementLimits.maxSecrets, detail: "보유: \(count)/\(EntitlementLimits.maxSecrets)")
    }

    public func canEnableICloudSync() -> Bool {
        log("canEnableICloudSync", allowed: current() == .pro)
    }

    public func canUseMultipleExpiryAlertDays() -> Bool {
        log("canUseMultipleExpiryAlertDays", allowed: current() == .pro)
    }

    /// 판정 결과를 그대로 돌려주면서 근거를 남긴다. **`current()`와 `stream()`은 찍지 않는다** — 호출 빈도가 판정의 몇 배라 로그가 그쪽으로 덮인다.
    @discardableResult
    private func log(_ gate: String, allowed: Bool, detail: String? = nil) -> Bool {
        let suffix = detail.map { ", \($0)" } ?? ""
        Log.debug("[Gate] \(gate) — 등급: \(current())\(suffix) → \(allowed ? "허용" : "차단")", category: .domain)
        return allowed
    }
}
