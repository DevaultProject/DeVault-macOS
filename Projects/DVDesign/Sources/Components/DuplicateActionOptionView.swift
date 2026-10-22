// Copyright © 2026 Devault. All rights reserved

import SwiftUI

/// Review Duplicates 화면의 "Overwrite/Rename/Skip" 선택지 — 제목+설명 두 줄 라벨
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
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                indicator
                Text(title)
                    .dvFont(.bodyMD)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.dv(.gray900))
            }
            Text(description)
                .dvFont(.captionMDRegular)
                .foregroundStyle(Color.dv(.gray600))
                .padding(.leading, 16 + 8)
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

    /// `DVRadioButton`과 같은 16pt 원·5pt 점 스타일.
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
