// Copyright © 2026 Devault. All rights reserved

import Foundation

import ComposableArchitecture

@DependencyClient
public struct AppLaunchClient: Sendable {
    /// 온보딩을 완료했는지 확인한다.
    public var hasCompletedOnboarding: @Sendable () -> Bool = { false }
    /// 온보딩 완료 상태를 저장한다.
    public var setOnboardingCompleted: @Sendable () -> Void
    /// 알림 권한을 요청하고 허용 여부를 반환한다.
    public var requestNotificationAuthorization: @Sendable () async -> Bool = { false }
    /// 만료일이 있는 모든 Secret의 알림을 다시 계산해 예약한다.
    public var syncExpiryNotifications: @Sendable () async -> Void
    /// CloudKit 원격 변경이 감지될 때마다 값을 방출한다.
    public var iCloudRemoteChangeStream: @Sendable () -> AsyncStream<Void> = {
        AsyncStream { $0.finish() }
    }
    /// 마지막 CloudKit 원격 변경 감지 시각을 저장한다.
    public var setICloudLastUpdateDetectedAt: @Sendable (Date) -> Void
    /// 등급이 free로 내려갔을 때 호출한다. iCloud 동기화가 켜져 있으면 끈다(로컬 데이터는 유지, 미러링만 중단).
    public var disableICloudSyncForDowngrade: @Sendable () async -> Void
}

extension AppLaunchClient: TestDependencyKey {
    public static let testValue = AppLaunchClient()

    public static let previewValue = AppLaunchClient(
        hasCompletedOnboarding: { false },
        setOnboardingCompleted: {},
        requestNotificationAuthorization: { true },
        syncExpiryNotifications: {},
        iCloudRemoteChangeStream: { AsyncStream { $0.finish() } },
        setICloudLastUpdateDetectedAt: { _ in },
        disableICloudSyncForDowngrade: {}
    )
}

extension DependencyValues {
    public var appLaunchClient: AppLaunchClient {
        get { self[AppLaunchClient.self] }
        set { self[AppLaunchClient.self] = newValue }
    }
}
