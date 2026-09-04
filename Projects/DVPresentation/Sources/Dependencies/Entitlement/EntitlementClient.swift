// Copyright © 2026 Devault. All rights reserved

import ComposableArchitecture
import DVDomain

/// 무료 / Pro 게이트 판정 Client. 생성·수정·설정 화면이 공유한다.
///
/// **화면은 동작을 시도하기 전에 여기서 먼저 묻는다.** 폼을 끝까지 채우게 한 뒤 저장에서 막으면 입력한 값이 날아간다. UseCase 쪽 `EntitlementError`는 이 물음을 건너뛴 호출을 막는 2차 방어선이지, 화면이 분기하는 신호가 아니다.
///
/// **`async throws` 판정이 throw하면 저장소가 깨진 상태다.** 업그레이드 시트를 띄우지 말고 일반 오류로 다뤄야 한다 — 결제해도 해결되지 않는다.
@DependencyClient
public struct EntitlementClient: Sendable {

    /// 현재 등급.
    public var current: @Sendable () -> Entitlement = { .free }

    /// 구독 즉시 현재 등급을 1회 방출하고, 이후 변경마다 최신값을 방출한다.
    public var stream: @Sendable () -> AsyncStream<Entitlement> = { .finished }

    /// 새 Secret을 만들 수 있는지. 저장소 개수를 세므로 비용이 있다.
    public var canCreateSecret: @Sendable () async throws -> Bool

    /// 새 Project를 만들 수 있는지. 저장소 개수를 세므로 비용이 있다.
    public var canCreateProject: @Sendable () async throws -> Bool

    /// Secret 수정 모드에 들어갈 수 있는지. 보유 수가 한도를 넘긴 경우에만 false다.
    public var canEditSecrets: @Sendable () async throws -> Bool

    /// iCloud 동기화를 켤 수 있는지.
    public var canEnableICloudSync: @Sendable () -> Bool = { false }

    /// 만료 알림 시점을 여러 개 지정할 수 있는지.
    public var canUseMultipleExpiryAlertDays: @Sendable () -> Bool = { false }
}

extension EntitlementClient: TestDependencyKey {
    /// 동기 판정만 **열린 상태**로 채운다. 게이트와 무관한 테스트가 잠긴 경로로 빠지면 무엇을 검증하는지 흐려진다. 잠금을 검증하는 테스트가 `false`로 덮어쓴다.
    ///
    /// `async throws` 판정은 그대로 둔다 — 덮어쓰지 않은 테스트에서 실패해 의존이 드러난다.
    public static var testValue: EntitlementClient {
        var client = EntitlementClient()
        // 등급을 표시용으로만 읽는 곳(예: 피드백 메일의 Plan 줄)이 미구현 호출로 깨지지 않게 기본값을 연다. 등급을 검증하는 테스트가 덮어쓴다.
        client.current = { .free }
        client.canEnableICloudSync = { true }
        client.canUseMultipleExpiryAlertDays = { true }
        // 화면이 `.task`에서 구독하므로, 비워 두면 게이트와 무관한 테스트가 미구현 호출로 먼저 깨진다. 즉시 끝나는 스트림이라 등급 변경은 오지 않는다.
        client.stream = { .finished }
        return client
    }

    /// 프리뷰는 Pro로 둔다. 게이트와 무관한 화면이 잠긴 모습으로 보이면 디자인 확인에 방해가 된다.
    public static let previewValue = EntitlementClient(
        current: { .pro },
        stream: { AsyncStream { $0.yield(.pro); $0.finish() } },
        canCreateSecret: { true },
        canCreateProject: { true },
        canEditSecrets: { true },
        canEnableICloudSync: { true },
        canUseMultipleExpiryAlertDays: { true }
    )
}

extension DependencyValues {
    public var entitlementClient: EntitlementClient {
        get { self[EntitlementClient.self] }
        set { self[EntitlementClient.self] = newValue }
    }
}
