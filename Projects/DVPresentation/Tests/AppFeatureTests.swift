// Copyright © 2026 Devault. All rights reserved

import ComposableArchitecture
import Foundation
import Testing

@testable import DVPresentation

@MainActor
@Suite("AppFeature")
struct AppFeatureTests {

    // MARK: - Screen 판정

    /// 화면 전환 애니메이션이 이 값 하나에 걸려 있다.
    @Test("screen: 세 화면이 각자 판정된다")
    func screenReportsCurrentScreen() {
        var onboarding = AppFeature.State()
        onboarding.onboarding = .init()
        #expect(onboarding.screen == .onboarding)

        var locked = AppFeature.State()
        locked.locked = .init()
        #expect(locked.screen == .locked)

        var main = AppFeature.State()
        main.main = .init()
        #expect(main.screen == .main)
    }

    /// 셋을 다 비웠다가 하나를 세우는 구간이 있다(`task`).
    @Test("screen: 아무것도 없으면 nil이다")
    func screenIsNilWhenNothingPresented() {
        #expect(AppFeature.State().screen == nil)
    }

    @Test("task는 온보딩을 완료했으면 locked 상태로 시작한다")
    func taskStartsLockedWhenOnboardingCompleted() async {
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0.appLaunchClient.hasCompletedOnboarding = { true }
            $0.appLaunchClient.requestNotificationAuthorization = { true }
            $0.appLaunchClient.syncExpiryNotifications = { }
            $0.appLaunchClient.iCloudRemoteChangeStream = { AsyncStream { $0.finish() } }
            $0.appSecurityClient.isRequireAuthOnLaunchEnabled = { true }
            $0.windowCaptureBlockerClient.enabledStream = { AsyncStream { $0.finish() } }
            $0.generalSettingsClient.appearanceStream = { AsyncStream { $0.finish() } }
        }

        await store.send(.task) {
            $0.locked = .init()
        }
    }

    @Test("task는 온보딩을 완료했으면 만료 알림을 동기화한다")
    func taskSyncsExpiryNotificationsWhenOnboardingCompleted() async {
        let synced = LockIsolated(false)
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0.appLaunchClient.hasCompletedOnboarding = { true }
            $0.appLaunchClient.requestNotificationAuthorization = { true }
            $0.appLaunchClient.syncExpiryNotifications = { synced.setValue(true) }
            $0.appLaunchClient.iCloudRemoteChangeStream = { AsyncStream { $0.finish() } }
            $0.appSecurityClient.isRequireAuthOnLaunchEnabled = { true }
            $0.windowCaptureBlockerClient.enabledStream = { AsyncStream { $0.finish() } }
            $0.generalSettingsClient.appearanceStream = { AsyncStream { $0.finish() } }
        }

        await store.send(.task) {
            $0.locked = .init()
        }

        #expect(synced.value)
    }

    // 온보딩에서 iCloud 사용 여부를 고르기 전에는 저장소를 지연 초기화한다.
    @Test("task는 온보딩 전이면 만료 알림 동기화를 건너뛴다")
    func taskSkipsExpiryNotificationsBeforeOnboarding() async {
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0.appLaunchClient.hasCompletedOnboarding = { false }
            $0.appLaunchClient.requestNotificationAuthorization = { true }
            $0.appLaunchClient.iCloudRemoteChangeStream = { AsyncStream { $0.finish() } }
            $0.windowCaptureBlockerClient.enabledStream = { AsyncStream { $0.finish() } }
            $0.generalSettingsClient.appearanceStream = { AsyncStream { $0.finish() } }
            // syncExpiryNotifications를 오버라이드하지 않는다 — 호출되면 @DependencyClient의
            // unimplemented 클로저가 테스트를 실패시킨다.
        }

        await store.send(.task) {
            $0.onboarding = .init()
        }
    }

    @Test("온보딩 완료 후 현재 저장소의 만료 알림을 동기화한다")
    func onboardingCompletionSyncsExpiryNotifications() async {
        let completed = LockIsolated(false)
        let synced = LockIsolated(false)
        var initial = AppFeature.State()
        initial.onboarding = .init()

        let store = TestStore(initialState: initial) {
            AppFeature()
        } withDependencies: {
            $0.appLaunchClient.setOnboardingCompleted = { completed.setValue(true) }
            $0.appLaunchClient.syncExpiryNotifications = { synced.setValue(true) }
            $0.appSecurityClient.inactivityTimeoutStream = { AsyncStream { $0.finish() } }
        }

        await store.send(.onboarding(.delegate(.completed))) {
            $0.onboarding = nil
            $0.main = .init()
        }
        await store.finish()

        #expect(completed.value)
        #expect(synced.value)
    }

    @Test("task는 앱 실행 시 인증 요구가 꺼져 있으면 잠금 없이 바로 main으로 시작한다")
    func taskStartsMainWhenRequireAuthOnLaunchDisabled() async {
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0.appLaunchClient.hasCompletedOnboarding = { true }
            $0.appLaunchClient.requestNotificationAuthorization = { true }
            $0.appLaunchClient.syncExpiryNotifications = { }
            $0.appLaunchClient.iCloudRemoteChangeStream = { AsyncStream { $0.finish() } }
            $0.appSecurityClient.isRequireAuthOnLaunchEnabled = { false }
            $0.appSecurityClient.inactivityTimeoutStream = { AsyncStream { $0.finish() } }
            $0.windowCaptureBlockerClient.enabledStream = { AsyncStream { $0.finish() } }
            $0.generalSettingsClient.appearanceStream = { AsyncStream { $0.finish() } }
        }

        await store.send(.task) {
            $0.main = .init()
        }
    }

    @Test("앱 비활성 타임아웃이 발생하면 main에서 locked로 전환한다")
    func inactivityTimeoutLocksApp() async {
        var initial = AppFeature.State()
        initial.main = .init()

        let store = TestStore(initialState: initial) {
            AppFeature()
        }

        await store.send(.inactivityTimeoutReached) {
            $0.main = nil
            $0.locked = .init()
        }
    }

    @Test("main이 아닐 때는 앱 비활성 타임아웃을 무시한다")
    func inactivityTimeoutIgnoredWhenNotInMain() async {
        var initial = AppFeature.State()
        initial.locked = .init()

        let store = TestStore(initialState: initial) {
            AppFeature()
        }

        await store.send(.inactivityTimeoutReached)
    }

    @Test("task 중 앱 비활성 타임아웃이 발생하면 inactivityTimeoutReached를 보낸다")
    func taskWatchesInactivityAndSendsTimeout() async {
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0.appLaunchClient.hasCompletedOnboarding = { true }
            $0.appLaunchClient.requestNotificationAuthorization = { true }
            $0.appLaunchClient.syncExpiryNotifications = { }
            $0.appLaunchClient.iCloudRemoteChangeStream = { AsyncStream { $0.finish() } }
            $0.appSecurityClient.isRequireAuthOnLaunchEnabled = { false }
            $0.appSecurityClient.inactivityTimeoutStream = {
                AsyncStream { continuation in
                    continuation.yield(())
                    continuation.finish()
                }
            }
            $0.windowCaptureBlockerClient.enabledStream = { AsyncStream { $0.finish() } }
            $0.generalSettingsClient.appearanceStream = { AsyncStream { $0.finish() } }
        }

        await store.send(.task) {
            $0.main = .init()
        }
        await store.receive(.inactivityTimeoutReached) {
            $0.main = nil
            $0.locked = .init()
        }
    }

    @Test("task는 화면 캡처 차단 설정 변경을 State에 반영한다")
    func taskWatchesWindowCaptureBlockingSetting() async {
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0.appLaunchClient.hasCompletedOnboarding = { false }
            $0.appLaunchClient.requestNotificationAuthorization = { true }
            $0.appLaunchClient.iCloudRemoteChangeStream = { AsyncStream { $0.finish() } }
            $0.windowCaptureBlockerClient.enabledStream = {
                AsyncStream { continuation in
                    continuation.yield(false)
                    continuation.finish()
                }
            }
            $0.generalSettingsClient.appearanceStream = { AsyncStream { $0.finish() } }
        }

        await store.send(.task) {
            $0.onboarding = .init()
        }
        await store.receive(.windowCaptureBlockingChanged(false)) {
            $0.isWindowCaptureBlockingEnabled = false
        }
    }

    @Test("task는 화면 모드 설정 변경을 State에 반영한다")
    func taskWatchesAppearanceSetting() async {
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0.appLaunchClient.hasCompletedOnboarding = { false }
            $0.appLaunchClient.requestNotificationAuthorization = { true }
            $0.appLaunchClient.iCloudRemoteChangeStream = { AsyncStream { $0.finish() } }
            $0.windowCaptureBlockerClient.enabledStream = { AsyncStream { $0.finish() } }
            $0.generalSettingsClient.appearanceStream = {
                AsyncStream { continuation in
                    continuation.yield("dark")
                    continuation.finish()
                }
            }
        }

        await store.send(.task) {
            $0.onboarding = .init()
        }
        await store.receive(.appearanceChanged(.dark)) {
            $0.appearance = .dark
        }
    }

    @Test("iCloud 원격 변경은 debounce 후 만료 알림을 다시 동기화한다")
    func iCloudRemoteChangeSyncsExpiryNotifications() async {
        let clock = TestClock()
        let synced = LockIsolated(false)
        let savedDate = LockIsolated<Date?>(nil)
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        var initial = AppFeature.State()
        initial.locked = .init()

        let store = TestStore(initialState: initial) {
            AppFeature()
        } withDependencies: {
            $0.continuousClock = clock
            $0.date = .constant(date)
            $0.appLaunchClient.syncExpiryNotifications = { synced.setValue(true) }
            $0.appLaunchClient.setICloudLastUpdateDetectedAt = { savedDate.setValue($0) }
        }

        await store.send(.iCloudRemoteChangeDetected)
        await clock.advance(by: .seconds(1))
        await store.receive(.iCloudRemoteChangeHandled)

        #expect(synced.value)
        #expect(savedDate.value == date)
    }

    // iCloud 동기화는 Pro 전용이라, 등급이 free로 내려가면 자동으로 꺼야 무료 사용자가 계속 동기화되지 않는다.
    @Test("등급이 free로 내려가면 iCloud 동기화를 자동으로 끄고 만료 알림을 다시 동기화한다")
    func entitlementDowngradeToFreeDisablesICloudSync() async {
        let synced = LockIsolated(false)
        let disabled = LockIsolated(false)
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0.entitlementClient.current = { .free }
            $0.appLaunchClient.syncExpiryNotifications = { synced.setValue(true) }
            $0.appLaunchClient.disableICloudSyncForDowngrade = { disabled.setValue(true) }
        }

        await store.send(.entitlementChanged)
        await store.finish()

        #expect(synced.value)
        #expect(disabled.value)
    }

    // 업그레이드나 Pro→Pro 플랜 변경에서는 동기화를 끄지 않는다.
    @Test("등급이 pro면 만료 알림만 다시 동기화하고 iCloud 동기화는 끄지 않는다")
    func entitlementChangeToProDoesNotDisableICloudSync() async {
        let synced = LockIsolated(false)
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0.entitlementClient.current = { .pro }
            $0.appLaunchClient.syncExpiryNotifications = { synced.setValue(true) }
            // disableICloudSyncForDowngrade를 오버라이드하지 않는다 — 호출되면
            // @DependencyClient의 unimplemented 클로저가 테스트를 실패시킨다.
        }

        await store.send(.entitlementChanged)
        await store.finish()

        #expect(synced.value)
    }

    // 앱이 꺼진 사이 만료돼 free로 확정된 채 시작하면, 스트림 첫 방출에서도 동기화를 강제 종료해야 한다.
    @Test("첫 방출이 free면 iCloud 동기화를 강제 종료한다")
    func settledAtLaunchFreeDisablesICloudSync() async {
        let disabled = LockIsolated(false)
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0.appLaunchClient.disableICloudSyncForDowngrade = { disabled.setValue(true) }
        }

        await store.send(.entitlementSettledAtLaunch(isFree: true))
        await store.finish()

        #expect(disabled.value)
    }

    @Test("첫 방출이 pro면 iCloud 동기화를 건드리지 않는다")
    func settledAtLaunchProDoesNotDisableICloudSync() async {
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        }
        // disableICloudSyncForDowngrade를 오버라이드하지 않는다 — 호출되면 미구현 클로저가 실패시킨다.

        await store.send(.entitlementSettledAtLaunch(isFree: false))
        await store.finish()
    }

    @Test("잠금 해제하면 새 앱 비활성 감시를 시작한다")
    func unlockStartsNewInactivityMonitoring() async {
        var initial = AppFeature.State()
        initial.locked = .init()

        let store = TestStore(initialState: initial) {
            AppFeature()
        } withDependencies: {
            $0.appSecurityClient.inactivityTimeoutStream = { AsyncStream { $0.finish() } }
        }

        await store.send(.locked(.delegate(.unlockCompleted))) {
            $0.locked = nil
            $0.main = .init()
        }
    }

    @Test("main의 lockRequested delegate는 main을 지우고 locked를 새로 연다")
    func lockRequestedLocksApp() async {
        var initial = AppFeature.State()
        initial.main = .init()

        let store = TestStore(initialState: initial) {
            AppFeature()
        }

        await store.send(.main(.didTapLock))
        await store.receive(.main(.delegate(.lockRequested))) {
            $0.main = nil
            $0.locked = .init()
        }
    }
}
