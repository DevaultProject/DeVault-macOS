// Copyright © 2026 Devault. All rights reserved

import SwiftUI

/// Import 화면들(Preview·Review Duplicates)이 공유하는 시크릿 행 — 원형 아이콘 + 이름 + 서브타입 배지.
/// `isHighlighted`는 Preview에서 "이게 들어온다"를 강조할 때만 켠다.
public struct ImportedSecretRowView: View {

    // MARK: - Properties

    private let name: String
    private let subTypeText: String
    private let isHighlighted: Bool
    /// "duplicated" 같은 우측 상태 문구. 문자열은 호출부가 로컬라이즈해서 넘긴다.
    private let statusText: String?

    // MARK: - Init

    public init(
        name: String,
        subTypeText: String,
        isHighlighted: Bool = false,
        statusText: String? = nil
    ) {
        self.name = name
        self.subTypeText = subTypeText
        self.isHighlighted = isHighlighted
        self.statusText = statusText
    }

    // MARK: - Body

    public var body: some View {
        HStack(spacing: 14) {
            Circle()
                .fill(Color.dv(.gray200))
                .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 6) {
                Text(name)
                    .dvFont(.bodyLG)
                    .foregroundStyle(Color.dv(.gray900))
                    .lineLimit(1)
                subTypeBadge
            }

            Spacer(minLength: 8)

            if let statusText {
                Text(statusText)
                    .dvFont(.bodyMD)
                    .foregroundStyle(Color.dv(.gray500))
            }
        }
        .padding(12)
        .background {
            if isHighlighted {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.dv(.vaultGreenTint))
            }
        }
    }
}

// MARK: - Subviews

extension ImportedSecretRowView {

    private var subTypeBadge: some View {
        Text(subTypeText)
            .dvFont(.captionMDSemibold)
            .foregroundStyle(Color.dv(.white))
            .padding(.horizontal, 10)
            .padding(.vertical, 3)
            .background(Capsule().fill(Color.dv(.vaultGreen)))
    }
}

// MARK: - Preview

#if DEBUG

#Preview("기본") {
    ImportedSecretRowView(name: "GitHub Token", subTypeText: "Access Token")
        .padding(20)
        .frame(width: 380)
}

#Preview("강조 — Preview 화면") {
    ImportedSecretRowView(name: "GitHub Token", subTypeText: "Access Token", isHighlighted: true)
        .padding(20)
        .frame(width: 380)
}

#Preview("중복됨") {
    ImportedSecretRowView(
        name: "GitHub Token",
        subTypeText: "Access Token",
        isHighlighted: true,
        statusText: "Duplicated"
    )
    .padding(20)
    .frame(width: 380)
}

#Preview("좁은 폭 — 이름 길어짐") {
    ImportedSecretRowView(name: "Very Long Secret Name That Should Truncate", subTypeText: "API Webhook Secret")
        .padding(12)
        .frame(width: 240)
}

#endif
