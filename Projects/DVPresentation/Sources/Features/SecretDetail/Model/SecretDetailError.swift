// Copyright © 2026 Devault. All rights reserved

import Foundation

import ComposableArchitecture
import DVDomain

// MARK: - SecretDetailError

/// Secret 조회/복호화 실패 시 Presentation 계층 오류.
enum SecretDetailError: Equatable {
    case authRequired
    /// 복호화 실패 (키 없음·복호화 오류·디코딩 실패).
    case decryptionFailed
    case unexpected

    static func map(_ error: SecretUseCaseError) -> SecretDetailError {
        switch error {
        case .authenticationFailure:
            return .authRequired
        case .cryptoFailure(let crypto):
            switch crypto {
            case .keyUnavailable, .keychainFailure,
                 .decryptionFailed, .decodingFailed:
                return .decryptionFailed
            case .encryptionFailed, .encodingFailed:
                return .unexpected
            }
        case .secretNotFound, .repositoryFailure,
             .invalidName, .invalidSecretType, .unexpected:
            return .unexpected
        }
    }

}

// MARK: - AlertState Presets

extension AlertState where Action == SecretDetailFeature.Action.Alert {

    static func payloadRevealFailed(_ error: SecretDetailError) -> Self {
        switch error {
        case .authRequired:
            return Self {
                TextState("Authentication required", bundle: .module)
            } actions: {
                ButtonState(role: .cancel) { TextState("OK", bundle: .module) }
            } message: {
                TextState(
                    "Please authenticate to view the secret.",
                    bundle: .module
                )
            }

        case .decryptionFailed:
            return Self {
                TextState("Failed to reveal secret.", bundle: .module)
            } actions: {
                ButtonState(role: .cancel) { TextState("OK", bundle: .module) }
            } message: {
                TextState(
                    "The secret could not be decrypted. Check that your device passcode is enabled.",
                    bundle: .module
                )
            }

        case .unexpected:
            return Self {
                TextState("Failed to reveal secret.", bundle: .module)
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

    /// 편집 폼의 **선택 가능한** 프로젝트 조회 실패. 프로젝트 연결만 못 바꿀 뿐
    /// 나머지 필드는 계속 고칠 수 있으므로 편집을 이어가게 둔다.
    static var projectsLoadFailed: Self {
        Self {
            TextState("Failed to load projects.", bundle: .module)
        } actions: {
            ButtonState(role: .cancel) { TextState("OK", bundle: .module) }
        } message: {
            TextState(
                "Project information could not be loaded. Other details are unaffected.",
                bundle: .module
            )
        }
    }

    /// 이 시크릿에 **연결된** 프로젝트 조회 실패. 재시도를 제공하는 유일한 alert다. 연결을 모르는 채로
    /// 수정에 들어가면 편집 baseline이 빈 목록이 되어 저장할 때 **실제 연결이 조용히 끊긴다.**
    /// 읽을 때까지 수정을 막으므로 복구 경로가 필요하다.
    static var linkedProjectsLoadFailed: Self {
        Self {
            TextState("Failed to load linked projects", bundle: .module)
        } actions: {
            ButtonState(action: .retryLinkedProjects) { TextState("Retry", bundle: .module) }
            ButtonState(role: .cancel) { TextState("OK", bundle: .module) }
        } message: {
            TextState(
                "Editing is unavailable until the linked projects load. Other details are unaffected.",
                bundle: .module
            )
        }
    }

    /// 저장 직전 재인증 실패·취소. ``updateFailed``와 나누는 이유는 사용자가 할 일이 달라서다 —
    /// 이쪽은 다시 눌러 인증하면 되고, 저쪽은 다시 눌러도 같은 오류가 날 수 있다.
    static var updateAuthRequired: Self {
        Self {
            TextState("Authentication required", bundle: .module)
        } actions: {
            ButtonState(role: .cancel) { TextState("OK", bundle: .module) }
        } message: {
            TextState(
                "Please authenticate to save your changes. Your changes are still here.",
                bundle: .module
            )
        }
    }

    /// 클립보드 복사 실패. 자동 정리·반복 감지까지 포함한 경로가 실패한 경우다.
    static var copyFailed: Self {
        Self {
            TextState("Failed to copy.", bundle: .module)
        } actions: {
            ButtonState(role: .cancel) { TextState("OK", bundle: .module) }
        } message: {
            TextState(
                "The value could not be copied to the clipboard. Please try again.",
                bundle: .module
            )
        }
    }

    /// 즐겨찾기 갱신 실패. payload 복호화가 없는 경로이므로 인증 실패는 나오지 않는다.
    static var likeFailed: Self {
        Self {
            TextState("Failed to update favorite.", bundle: .module)
        } actions: {
            ButtonState(role: .cancel) { TextState("OK", bundle: .module) }
        } message: {
            TextState(
                "An unexpected error occurred. Please try again.",
                bundle: .module
            )
        }
    }

    static var confirmDelete: Self {
        Self {
            TextState("Move to trash?", bundle: .module)
        } actions: {
            ButtonState(role: .destructive, action: .confirmDelete) {
                TextState("Delete", bundle: .module)
            }
            ButtonState(role: .cancel) {
                TextState("Cancel", bundle: .module)
            }
        } message: {
            TextState(
                "You can restore it later from Trash.",
                bundle: .module
            )
        }
    }

    /// 이미 휴지통에 있는 시크릿을 조회 화면에서 지우는 경우. 다시 소프트 삭제해봤자
    /// 아무 일도 안 일어나므로, 여기서는 영구 삭제를 확인한다 — 리스트 화면의
    /// "Delete Forever" 흐름과 같은 문구를 쓴다.
    static var confirmDeleteForever: Self {
        Self {
            TextState("Delete Forever?", bundle: .module)
        } actions: {
            ButtonState(role: .destructive, action: .confirmDeleteForever) {
                TextState("Delete Forever", bundle: .module)
            }
            ButtonState(role: .cancel) {
                TextState("Cancel", bundle: .module)
            }
        } message: {
            TextState(
                "This action cannot be undone.",
                bundle: .module
            )
        }
    }

    static var deleteFailed: Self {
        Self {
            TextState("Failed to delete secret.", bundle: .module)
        } actions: {
            ButtonState(role: .cancel) { TextState("OK", bundle: .module) }
        } message: {
            TextState(
                "An unexpected error occurred. Please try again.",
                bundle: .module
            )
        }
    }

    /// 수정 저장 실패. 편집 모드는 유지되므로 입력한 내용이 남아 있다는 것을 문구로 알린다.
    static var updateFailed: Self {
        Self {
            TextState("Failed to save changes.", bundle: .module)
        } actions: {
            ButtonState(role: .cancel) { TextState("OK", bundle: .module) }
        } message: {
            TextState(
                "An unexpected error occurred. Your changes were not saved and are still here.",
                bundle: .module
            )
        }
    }

    static var confirmDiscard: Self {
        Self {
            TextState("Discard changes?", bundle: .module)
        } actions: {
            ButtonState(role: .destructive, action: .confirmDiscard) {
                TextState("Discard", bundle: .module)
            }
            ButtonState(role: .cancel) {
                TextState("Keep editing", bundle: .module)
            }
        } message: {
            TextState(
                "Your unsaved changes will be lost.",
                bundle: .module
            )
        }
    }
}
