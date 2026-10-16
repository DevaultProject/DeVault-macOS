// Copyright © 2026 Devault. All rights reserved

import SwiftUI

import DVDesign
import DVDomain

/// 시크릿 조회 화면 상단 헤더 — 즐겨찾기 + 타입명 + 액션 + 읽기 전용 서브타입 탭바.
///
/// ```
/// [★ API Keys/Token                            ✎  🗑]   ← Type row, 30pt
///                                                        ← spacing 16
/// [○ API Key   ● Access Token   ○ API Webhook Secret]   ← Tab Bar, 16pt
/// ```
///
/// 서브타입 탭바는 조회·수정 모두 읽기 전용이다 — 서브타입이 바뀌면 payload 스키마가
/// 통째로 달라져(`CreateSecretPayload` case 교체) 수정이 아니라 재생성에 해당한다.
struct SecretDetailHeaderView: View {

    let secretType: SecretType
    let subType: SecretSubType?
    let isLiked: Bool
    /// 수정 진입을 받을 수 있는지. 복호화 중이거나 연결 프로젝트를 아직 못 읽은 동안 거짓이다.
    var isEditEnabled: Bool = true
    /// 편집 폼 위에 얹힌 헤더인지. 수정·삭제는 렌더하지 않고 즐겨찾기만 회색으로 남긴다.
    ///
    /// 별을 숨기지 않는 것은 상태 표시를 겸하기 때문이고, 잠그는 것은 편집 중 즐겨찾기가
    /// 성공하면 `state.secret`이 교체되어 저장 diff의 baseline과 어긋나기 때문이다.
    var isEditing: Bool = false
    let onToggleLike: () -> Void
    let onShare: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    private var subTypes: [CreatableSecretSubType] {
        secretType.creatableType.availableSubTypes
    }

    /// `subType`이 nil일 때의 폴백은 `resolvedSubType`이 정의한다 — 저장 경로와 같은 규칙을 써야
    /// 화면에 보이는 서브타입과 저장되는 서브타입이 갈리지 않는다.
    private var selectedSubType: CreatableSecretSubType? {
        secretType.creatableType.resolvedSubType(subType)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: subTypes.isEmpty ? 0 : 16) {
            typeRow
            if !subTypes.isEmpty {
                tabBar
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Subviews

extension SecretDetailHeaderView {

    private var typeRow: some View {
        HStack(spacing: 0) {
            HStack(spacing: 10) {
                likeButton
                Text(secretType.creatableType.displayName)
                    .dvFont(.headingXL)
                    .foregroundStyle(Color.dv(.gray900))
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            if !isEditing {
                actionsContainer
            }
        }
        // 액션이 빠지는 편집 모드에서도 타입명이 위아래로 움직이지 않도록 고정한다.
        .frame(height: 30)
    }

    private var likeButton: some View {
        DVIconButton(
            systemName: isLiked ? "star.fill" : "star",
            font: .headingLG,
            idle: .vaultGreen,
            hovered: .vaultGreenDark,
            pressed: .vaultGreenDark,
            disabled: .gray400,
            pressedOpacity: 0.7,
            hitSize: 24, // 폭이 30이면 타입명이 6pt 밀린다.
            hitHeight: 30,
            action: onToggleLike
        )
        .disabled(isEditing)
        .accessibilityLabel(
            Text(isLiked ? .module("Remove from favorites") : .module("Add to favorites"))
        )
    }

    private var actionsContainer: some View {
        HStack(spacing: 6) {
            actionButton(
                systemName: "square.and.arrow.up",
                accessibilityLabel: .module("Export"),
                action: onShare
            )
            actionButton(
                systemName: "pencil",
                accessibilityLabel: .module("Edit"),
                isEnabled: isEditEnabled,
                action: onEdit
            )
            actionButton(
                systemName: "trash",
                accessibilityLabel: .module("Delete"),
                action: onDelete
            )
        }
    }

    private func actionButton(
        systemName: String,
        accessibilityLabel: LocalizedStringResource,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        DVIconButton(
            systemName: systemName,
            font: .bodyLG,
            idle: .gray700,
            hovered: .gray900,
            pressed: .gray900,
            pressedOpacity: 0.7,
            hitSize: 30,
            action: action
        )
        .disabled(!isEnabled)
        .accessibilityLabel(Text(accessibilityLabel))
    }

    private var tabBar: some View {
        // 디자인 간격은 28pt. DVRadioButton이 좌우 2pt 패딩을 가져 spacing 24가 실제 28이 된다.
        HStack(spacing: 24) {
            ForEach(subTypes, id: \.self) { sub in
                DVRadioButton(
                    readOnly: String(localized: sub.displayName),
                    isSelected: sub == selectedSubType
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Preview

#if DEBUG

/// Main Container 420 - 좌우 padding 20×2.
private let _headerWidth: CGFloat = 380

#Preview("API Keys/Token · Access Token 선택") {
    SecretDetailHeaderView(
        secretType: .apiKeyToken,
        subType: .accessToken,
        isLiked: false,
        onToggleLike: {},
        onShare: {},
        onEdit: {},
        onDelete: {}
    )
    .padding(20)
    .previewWidth(_headerWidth + 40)
}

#Preview("API Keys/Token · liked") {
    SecretDetailHeaderView(
        secretType: .apiKeyToken,
        subType: .apiKey,
        isLiked: true,
        onToggleLike: {},
        onShare: {},
        onEdit: {},
        onDelete: {}
    )
    .padding(20)
    .previewWidth(_headerWidth + 40)
}

#Preview("OAuth · 2 subs") {
    SecretDetailHeaderView(
        secretType: .oauth,
        subType: .serviceAccount,
        isLiked: false,
        onToggleLike: {},
        onShare: {},
        onEdit: {},
        onDelete: {}
    )
    .padding(20)
    .previewWidth(_headerWidth + 40)
}

#Preview("SSH & Credentials · 긴 타입명") {
    SecretDetailHeaderView(
        secretType: .sshAndCredentials,
        subType: .sslTlsCertificate,
        isLiked: true,
        onToggleLike: {},
        onShare: {},
        onEdit: {},
        onDelete: {}
    )
    .padding(20)
    .previewWidth(_headerWidth + 40)
}

#Preview("Database · 탭바 없음") {
    SecretDetailHeaderView(
        secretType: .database,
        subType: nil,
        isLiked: false,
        onToggleLike: {},
        onShare: {},
        onEdit: {},
        onDelete: {}
    )
    .padding(20)
    .previewWidth(_headerWidth + 40)
}

#Preview("EnvSet · 탭바 없음") {
    SecretDetailHeaderView(
        secretType: .environmentVariableSet,
        subType: nil,
        isLiked: false,
        onToggleLike: {},
        onShare: {},
        onEdit: {},
        onDelete: {}
    )
    .padding(20)
    .previewWidth(_headerWidth + 40)
}

#Preview("ETC · subType nil → 첫 탭 선택") {
    SecretDetailHeaderView(
        secretType: .etc,
        subType: nil,
        isLiked: false,
        onToggleLike: {},
        onShare: {},
        onEdit: {},
        onDelete: {}
    )
    .padding(20)
    .previewWidth(_headerWidth + 40)
}

/// 액션이 빠져도 타입명 행의 높이는 조회 모드와 같아야 한다.
#Preview("편집 중 · 즐겨찾기만 회색으로 남음") {
    SecretDetailHeaderView(
        secretType: .apiKeyToken,
        subType: .apiKey,
        isLiked: true,
        isEditing: true,
        onToggleLike: {},
        onShare: {},
        onEdit: {},
        onDelete: {}
    )
    .padding(20)
    .previewWidth(_headerWidth + 40)
}

#Preview("수정 비활성 (복호화 진행 중)") {
    SecretDetailHeaderView(
        secretType: .apiKeyToken,
        subType: .apiKey,
        isLiked: false,
        isEditEnabled: false,
        onToggleLike: {},
        onShare: {},
        onEdit: {},
        onDelete: {}
    )
    .padding(20)
    .previewWidth(_headerWidth + 40)
}

#endif
