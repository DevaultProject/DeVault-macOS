// Copyright © 2026 Devault. All rights reserved

import SwiftUI

/// Import 화면들(Password·Preview·Review Duplicates)이 제목 아래에 두는 한 줄 부제 — 문서 아이콘 + 캡션.
public struct ImportSubtitleView: View {

    // MARK: - Properties

    /// 호출부가 로컬라이즈해서 넘긴다.
    private let text: String

    // MARK: - Init

    public init(_ text: String) {
        self.text = text
    }

    // MARK: - Body

    public var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "doc")
                .accessibilityHidden(true)
            Text(text)
        }
        .dvFont(.captionMDRegular)
        .foregroundStyle(Color.dv(.gray700))
    }
}

// MARK: - Preview

#Preview("파일 이름") {
    ImportSubtitleView("DeVault.dvt")
        .padding()
}

#Preview("요약") {
    ImportSubtitleView("3 duplicates · 5 secrets selected")
        .padding()
}
