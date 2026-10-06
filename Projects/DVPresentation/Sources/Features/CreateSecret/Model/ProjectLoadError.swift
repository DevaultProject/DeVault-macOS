// Copyright © 2026 Devault. All rights reserved

import ComposableArchitecture
import DVDomain
import Foundation

/// 프로젝트 목록 로드 실패 시 사용자에게 표시할 Presentation 계층 오류.
/// `ProjectUseCaseError`에서 매핑한다.
enum ProjectLoadError: Equatable {
    /// 저장소 읽기 실패.
    case repositoryFailure
    /// 그 외 예기치 않은 오류.
    case unexpected

    static func map(_ error: ProjectUseCaseError) -> ProjectLoadError {
        switch error {
        case .repositoryFailure:
            return .repositoryFailure
        case .invalidName, .projectNotFound, .unexpected:
            return .unexpected
        }
    }
}

// MARK: - AlertState presets

extension AlertState where Action == CreateSecretFeature.Action.Alert {
    static func projectLoadFailed(_ error: ProjectLoadError) -> Self {
        switch error {
        case .repositoryFailure:
            return Self {
                TextState("Failed to load projects.", bundle: .module)
            } actions: {
                ButtonState(role: .cancel) { TextState("OK", bundle: .module) }
            } message: {
                TextState(
                    "A database error occurred while loading projects. The project list may be incomplete.",
                    bundle: .module
                )
            }

        case .unexpected:
            return Self {
                TextState("Failed to load projects.", bundle: .module)
            } actions: {
                ButtonState(role: .cancel) { TextState("OK", bundle: .module) }
            } message: {
                TextState(
                    "The project list couldn't be loaded. Please try again later.",
                    bundle: .module
                )
            }
        }
    }
}
