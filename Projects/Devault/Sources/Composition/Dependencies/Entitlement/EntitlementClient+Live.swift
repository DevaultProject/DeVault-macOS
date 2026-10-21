// Copyright © 2026 Devault. All rights reserved

import ComposableArchitecture
import DVDomain
import DVPresentation

extension EntitlementClient: @retroactive DependencyKey {
    public static let liveValue: EntitlementClient = {
        let useCase = LiveUseCases.entitlement
        return EntitlementClient(
            current: { useCase.current() },
            stream: { useCase.stream() },
            canCreateSecret: { try await useCase.canCreateSecret() },
            canCreateProject: { try await useCase.canCreateProject() },
            canImportSecrets: { try await useCase.canImportSecrets(count: $0) },
            canEditSecrets: { try await useCase.canEditSecrets() },
            canEnableICloudSync: { useCase.canEnableICloudSync() },
            canUseMultipleExpiryAlertDays: { useCase.canUseMultipleExpiryAlertDays() }
        )
    }()
}
