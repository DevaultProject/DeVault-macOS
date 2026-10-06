// Copyright © 2026 Devault. All rights reserved

import ComposableArchitecture
import DVDomain
import Foundation

/// Secret 저장 실패 시 사용자에게 표시할 Presentation 계층 오류.
/// `SecretUseCaseError`에서 매핑하며, 세부 도메인 원인을 UX 친화적 케이스로 분류한다.
enum CreateSecretError: Equatable {
    /// Keychain 미사용 가능 또는 암호화 실패 (crypto layer).
    case cryptoUnavailable
    /// 생체인증·패스코드 인증 요구.
    case authRequired
    /// 저장소 쓰기 실패.
    case repositoryFailure
    /// 그 외 예기치 않은 오류.
    case unexpected

    static func map(_ error: SecretUseCaseError) -> CreateSecretError {
        switch error {
        case .cryptoFailure(let crypto):
            switch crypto {
            case .keyUnavailable, .keychainFailure: return .cryptoUnavailable
            case .encryptionFailed, .encodingFailed: return .cryptoUnavailable
            case .decryptionFailed, .decodingFailed: return .unexpected
            }
        case .authenticationFailure:
            return .authRequired
        case .repositoryFailure:
            return .repositoryFailure
        case .invalidName, .invalidSecretType, .secretNotFound, .unexpected:
            return .unexpected
        }
    }
}

// MARK: - AlertState presets

extension AlertState where Action == CreateSecretFeature.Action.Alert {
    static func createSecretFailed(_ error: CreateSecretError) -> Self {
        switch error {
        case .cryptoUnavailable:
            return Self {
                TextState("Encryption unavailable.", bundle: .module)
            } actions: {
                ButtonState(role: .cancel) { TextState("OK", bundle: .module) }
            } message: {
                TextState(
                    "The secret could not be saved because encryption is unavailable. Check that your device passcode is enabled.",
                    bundle: .module
                )
            }

        case .authRequired:
            return Self {
                TextState("Authentication required", bundle: .module)
            } actions: {
                ButtonState(role: .cancel) { TextState("OK", bundle: .module) }
            } message: {
                TextState(
                    "Please authenticate to save the secret.",
                    bundle: .module
                )
            }

        case .repositoryFailure:
            return Self {
                TextState("Save failed", bundle: .module)
            } actions: {
                ButtonState(role: .cancel) { TextState("OK", bundle: .module) }
            } message: {
                TextState(
                    "A database error occurred while saving the secret. Please try again.",
                    bundle: .module
                )
            }

        case .unexpected:
            return Self {
                TextState("Save failed", bundle: .module)
            } actions: {
                ButtonState(role: .cancel) { TextState("OK", bundle: .module) }
            } message: {
                TextState(
                    "An unexpected error occurred. Please try again.",
                    bundle: .module
                )
            }
        }
    }
}
