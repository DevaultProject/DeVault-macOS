// Copyright © 2026 Devault. All rights reserved

import Foundation
import Testing

import DVDomain
@testable import Devault
@testable import DVData

/// iCloud 동기화는 Pro 전용이라, 저장소 구성 지점에서 등급과 함께 판정한다.
/// Pro일 때 켠 플래그가 free로 내려온 뒤에도 남아 컨테이너가 `.private`(CloudKit 미러링)로 만들어지는 것을 막는 게이트를 검증한다.
@Suite("LiveStorage iCloud 게이트")
struct LiveStorageICloudGateTests {

    private func makeSettings() -> SettingsRepositoryImpl {
        let suiteName = "LiveStorageICloudGateTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        return SettingsRepositoryImpl(defaults: defaults)
    }

    @Test("free인데 켜짐 플래그가 남아 있으면 동기화를 끄고 플래그를 정리한다")
    func freeWithStaleFlagIsDisabledAndReconciled() {
        let settings = makeSettings()
        settings.setICloudSyncEnabled(true)
        settings.setCachedEntitlement(.free)

        #expect(LiveStorage.resolveICloudSync(settings) == false)
        #expect(settings.isICloudSyncEnabled() == false) // 실제 상태(미러링 없음)에 맞춰 정리됨
    }

    @Test("Pro면 켜짐 플래그를 그대로 두고 동기화를 유지한다")
    func proKeepsSyncEnabled() {
        let settings = makeSettings()
        settings.setICloudSyncEnabled(true)
        settings.setCachedEntitlement(.pro)

        #expect(LiveStorage.resolveICloudSync(settings) == true)
        #expect(settings.isICloudSyncEnabled() == true)
    }

    @Test("플래그가 꺼져 있으면 등급과 무관하게 동기화하지 않는다")
    func disabledFlagStaysDisabled() {
        let settings = makeSettings()
        settings.setICloudSyncEnabled(false)
        settings.setCachedEntitlement(.pro)

        #expect(LiveStorage.resolveICloudSync(settings) == false)
        #expect(settings.isICloudSyncEnabled() == false)
    }
}
