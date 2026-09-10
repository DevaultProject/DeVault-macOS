// Copyright © 2026 Devault. All rights reserved

import Foundation
import Testing

@testable import DVDomain

@Suite("NotificationSettingsUseCaseImpl")
struct NotificationSettingsUseCaseImplTests {

    @Test("만료 알림 사용 여부를 읽고 쓴다")
    func expiryAlertsEnabledRoundTrips() async throws {
        let repository = FakeSettingsRepository()
        let scheduler = StubExpiryNotificationScheduler()
        let sut = NotificationSettingsUseCaseImpl(
            repository: repository,
            expiryNotificationScheduler: scheduler,
            entitlementUseCase: StubEntitlementUseCase()
        )

        #expect(sut.isExpiryAlertsEnabled() == true)
        try await sut.setExpiryAlertsEnabled(false)
        #expect(sut.isExpiryAlertsEnabled() == false)
        #expect(scheduler.syncAllCount == 1)
    }

    @Test("만료 알림 타이밍(며칠 전)을 읽고 쓴다")
    func expiryAlertDaysBeforeRoundTrips() async throws {
        let repository = FakeSettingsRepository()
        let scheduler = StubExpiryNotificationScheduler()
        let sut = NotificationSettingsUseCaseImpl(
            repository: repository,
            expiryNotificationScheduler: scheduler,
            entitlementUseCase: StubEntitlementUseCase()
        )

        #expect(sut.expiryAlertDaysBefore() == ExpiryAlertDay.defaultSelection)
        try await sut.setExpiryAlertDaysBefore([.sevenDaysBefore, .threeDaysBefore])
        #expect(sut.expiryAlertDaysBefore() == [.sevenDaysBefore, .threeDaysBefore])
        #expect(scheduler.syncAllCount == 1)
    }

    @Test("등급 전환 리셋: Pro면 전체 시점으로 되돌린다")
    func resetForProSetsAllTimings() {
        let repository = FakeSettingsRepository()
        repository.setExpiryAlertDaysBefore([.threeDaysBefore])
        let sut = NotificationSettingsUseCaseImpl(
            repository: repository,
            expiryNotificationScheduler: StubExpiryNotificationScheduler(),
            entitlementUseCase: StubEntitlementUseCase(entitlement: .pro)
        )

        sut.resetExpiryAlertDaysForCurrentEntitlement()

        #expect(Set(repository.expiryAlertDaysBefore()) == Set(ExpiryAlertDay.defaultSelection))
    }

    @Test("등급 전환 리셋: Free면 선택 중 가장 이른 시점 하나만 남긴다")
    func resetForFreeKeepsEarliest() {
        let repository = FakeSettingsRepository()
        repository.setExpiryAlertDaysBefore([.threeDaysBefore, .sevenDaysBefore, .expirationDay])
        let sut = NotificationSettingsUseCaseImpl(
            repository: repository,
            expiryNotificationScheduler: StubExpiryNotificationScheduler(),
            entitlementUseCase: StubEntitlementUseCase(entitlement: .free)
        )

        sut.resetExpiryAlertDaysForCurrentEntitlement()

        #expect(repository.expiryAlertDaysBefore() == [.sevenDaysBefore])
    }

    @Test("등급 전환 리셋: Free이고 선택이 비어 있으면 그대로 둔다")
    func resetForFreeEmptyStaysEmpty() {
        let repository = FakeSettingsRepository()
        repository.setExpiryAlertDaysBefore([])
        let sut = NotificationSettingsUseCaseImpl(
            repository: repository,
            expiryNotificationScheduler: StubExpiryNotificationScheduler(),
            entitlementUseCase: StubEntitlementUseCase(entitlement: .free)
        )

        sut.resetExpiryAlertDaysForCurrentEntitlement()

        #expect(repository.expiryAlertDaysBefore() == [])
    }

    @Test("반복 인증 실패/클립보드 비정상 접근 알림 설정을 읽고 쓴다")
    func abnormalAccessAlertsRoundTrip() {
        let repository = FakeSettingsRepository()
        let sut = NotificationSettingsUseCaseImpl(
            repository: repository,
            expiryNotificationScheduler: StubExpiryNotificationScheduler(),
            entitlementUseCase: StubEntitlementUseCase()
        )

        #expect(sut.isAuthFailureAlertEnabled() == true)
        sut.setAuthFailureAlertEnabled(false)
        #expect(sut.isAuthFailureAlertEnabled() == false)

        #expect(sut.isClipboardAbnormalAccessAlertEnabled() == true)
        sut.setClipboardAbnormalAccessAlertEnabled(false)
        #expect(sut.isClipboardAbnormalAccessAlertEnabled() == false)
    }
}

private final class StubExpiryNotificationScheduler: ScheduleSecretExpiryNotificationsUseCase, @unchecked Sendable {
    private(set) var syncAllCount = 0

    func syncAll() async throws {
        syncAllCount += 1
    }

    func schedule(secret: Secret) async {}
    func cancel(secretID: UUID) async {}
    func cancelAll() async {}
}
