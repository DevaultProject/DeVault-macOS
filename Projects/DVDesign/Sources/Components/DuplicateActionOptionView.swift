// Copyright © 2026 Devault. All rights reserved

import SwiftUI

/// Review Duplicates 화면의 "Overwrite/Rename/Skip" 선택지 — 제목+설명 두 줄 라벨에
/// 인디케이터를 제목 줄에 맞춰 위쪽 정렬한다. `DVRadioButton`은 라벨 전체 높이에 인디케이터를
/// 가운데 정렬해 이 레이아웃엔 안 맞아, 같은 인디케이터 스타일·인터랙션을 직접 구현했다.
public struct DuplicateActionOptionView: View {

    // MARK: - Properties

    private let title: String
    private let description: String
    private let isSelected: Bool
    private let action: () -> Void

    // MARK: - Init

    public init(
        title: String,
        description: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.description = description
        self.isSelected = isSelected
        self.action = action
    }

    // MARK: - Body

    public var body: some View {
        HStack(alignment: .top, spacing: 3) {
            indicator
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .dvFont(.bodyLG)
                    .foregroundStyle(Color.dv(.gray900))
                Text(description)
                    .dvFont(.bodyMD)
                    .foregroundStyle(Color.dv(.gray600))
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 2)
        .contentShape(Rectangle())
        .onTapGesture(perform: action)
        .focusable(true)
        .focusEffectDisabled()
        .onKeyPress(.space) {
            action()
            return .handled
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    /// 제목 줄 높이(`.bodyLG`)에 맞춰 수직 중앙 정렬 — `DVRadioButton`과 같은 16pt 원·5pt 점 스타일.
    private var indicator: some View {
        ZStack {
            Circle()
                .fill(isSelected ? Color.dv(.vaultGreen) : Color.dv(.gray300))
                .frame(width: 16, height: 16)
            if isSelected {
                Circle()
                    .fill(Color.dv(.white))
                    .frame(width: 5, height: 5)
            }
        }
        .frame(height: DVFont.bodyLG.lineHeight)
    }
}

// MARK: - Preview

#if DEBUG

#Preview("세 옵션") {
    VStack(alignment: .leading, spacing: 16) {
        DuplicateActionOptionView(
            title: "Overwrite",
            description: "Replace the existing secret with the imported secret.",
            isSelected: false,
            action: {}
        )
        DuplicateActionOptionView(
            title: "Rename",
            description: "Keep both secrets by giving the imported secret a new name.",
            isSelected: true,
            action: {}
        )
        DuplicateActionOptionView(
            title: "Skip",
            description: "Keep the existing secret and skip this item.",
            isSelected: false,
            action: {}
        )
    }
    .padding(20)
    .frame(width: 340)
}

#endif
