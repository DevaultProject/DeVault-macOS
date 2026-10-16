// Copyright © 2026 Devault. All rights reserved

import DVDomain

extension AuthenticationReason {
    /// `LocalUserAuthenticationServiceImpl`(DVData)에 주입하는 인증 시트 문구 팩토리. DVData가 접근 못 하는 로컬라이제이션 카탈로그를 이 모듈에서 대신 룩업한다.
    @Sendable
    public static func moduleText(for reason: AuthenticationReason) -> String {
        switch reason {
        case .revealSecret:
            return String.module("Authenticate to view the secret value.")
        case .copySecret:
            return String.module("Authenticate to copy the secret value.")
        case .editSecret:
            return String.module("Authenticate to edit the secret.")
        case .unlock:
            return String.module("Authenticate to unlock DeVault.")
        case .enableTouchID:
            return String.module("Authenticate to enable Touch ID.")
        case .deleteAllData:
            return String.module("Authenticate to delete all data.")
        case .exportSecrets:
            return String.module("Authenticate to export secrets.")
        case .importSecrets:
            return String.module("Authenticate to import secrets.")
        }
    }
}
