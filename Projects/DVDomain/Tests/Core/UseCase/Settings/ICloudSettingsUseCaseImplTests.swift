// Copyright © 2026 Devault. All rights reserved

import Foundation
import Testing

@testable import DVDomain

@Suite("ICloudSettingsUseCaseImpl")
struct ICloudSettingsUseCaseImplTests {

    @Test("iCloud 동기화 설정과 마지막 update 감지 시각을 읽고 쓴다")
    func settingsRoundTrip() async throws {
        let repository = FakeSettingsRepository()
        let sut = ICloudSettingsUseCaseImpl(
            repository: repository,
            iCloudService: StubICloudService(status: .available),
            entitlementUseCase: StubEntitlementUseCase()
        )
        let date = Date(timeIntervalSince1970: 1_700_000_000)

        try await sut.setEnabled(true)
        sut.setLastUpdateDetectedAt(date)

        #expect(sut.isEnabled() == true)
        #expect(sut.lastUpdateDetectedAt() == date)
    }

    @Test("iCloud 계정 상태 확인을 Service에 위임한다")
    func accountStatusUsesService() async {
        let sut = ICloudSettingsUseCaseImpl(
            repository: FakeSettingsRepository(),
            iCloudService: StubICloudService(status: .noAccount),
            entitlementUseCase: StubEntitlementUseCase()
        )

        let status = await sut.accountStatus()

        #expect(status == .noAccount)
    }

    @Test("저장소 구성에 실패하면 설정값을 변경하지 않는다")
    func configurationFailureDoesNotPersistSetting() async {
        let repository = FakeSettingsRepository()
        let sut = ICloudSettingsUseCaseImpl(
            repository: repository,
            iCloudService: StubICloudService(
                status: .available,
                configurationFails: true
            ),
            entitlementUseCase: StubEntitlementUseCase()
        )

        await #expect(throws: StubICloudService.Error.configurationFailed) {
            try await sut.setEnabled(true)
        }
        #expect(repository.isICloudSyncEnabled() == false)
    }

    // 끄기는 fail-safe여야 한다: 저장소 전환이 실패해도 free가 계속 동기화되면 안 된다.
    @Test("동기화 끄기: 저장소 전환이 실패해도 플래그는 false로 확정된다")
    func disableForcesFlagOffEvenWhenStorageSwitchFails() async {
        let repository = FakeSettingsRepository()
        repository.setICloudSyncEnabled(true) // 이미 켜진 상태에서 다운그레이드
        let sut = ICloudSettingsUseCaseImpl(
            repository: repository,
            iCloudService: StubICloudService(
                status: .available,
                configurationFails: true
            ),
            entitlementUseCase: StubEntitlementUseCase()
        )

        await #expect(throws: StubICloudService.Error.configurationFailed) {
            try await sut.setEnabled(false)
        }
        #expect(repository.isICloudSyncEnabled() == false) // 전환 실패해도 플래그는 꺼짐
    }

    @Test("iCloud 원격 변경 스트림을 Service에 위임한다")
    func remoteChangeStreamUsesService() async {
        let sut = ICloudSettingsUseCaseImpl(
            repository: FakeSettingsRepository(),
            iCloudService: StubICloudService(
                status: .available,
                emitsRemoteChange: true
            ),
            entitlementUseCase: StubEntitlementUseCase()
        )

        var iterator = sut.remoteChangeStream().makeAsyncIterator()
        let value: Void? = await iterator.next()

        #expect(value != nil)
    }
}

private struct StubICloudService: ICloudService {
    enum Error: Swift.Error {
        case configurationFailed
    }

    let status: ICloudAccountStatus
    var emitsRemoteChange = false
    var configurationFails = false

    func fetchAccountStatus() async -> ICloudAccountStatus {
        status
    }

    func remoteChangeStream() -> AsyncStream<Void> {
        AsyncStream { continuation in
            if emitsRemoteChange {
                continuation.yield(())
            }
            continuation.finish()
        }
    }

    func configureStorage(iCloudSyncEnabled: Bool) async throws {
        if configurationFails {
            throw Error.configurationFailed
        }
    }
}
