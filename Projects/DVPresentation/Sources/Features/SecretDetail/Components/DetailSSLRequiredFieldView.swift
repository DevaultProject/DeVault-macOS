// Copyright © 2026 Devault. All rights reserved

import SwiftUI

import DVDesign

/// 조회 화면의 "SSL Required" 필드 — 생성 화면 `SSLRequiredFieldView`의 read-only 대응. 값이 Bool이라
/// 텍스트(`DetailReadOnlyFieldView`)가 아니라 읽기 전용 체크박스로 표시하며, 생성 화면이 체크박스로
/// 입력받는 값을 조회 화면에서 "Required" 같은 문자열로 바꿔 보여주면 두 화면의 표현이 어긋나기 때문이다.
/// 라벨·간격도 생성 화면과 같은 값을 쓴다.
struct DetailSSLRequiredFieldView: View {

    let isRequired: Bool

    var body: some View {
        HStack(spacing: 6) {
            Text(.module("SSL Required"))
                .dvFont(.bodyMD)
                .foregroundStyle(Color.dv(.gray700))
            DVCheckBox(readOnly: isRequired)
        }
        // 체크 상태를 **값으로 따로 읽어 준다** — `DVCheckBox(readOnly:)`는 비인터랙티브 도형이라 접근성 트리에
        // 아무것도 남기지 않아 묶기만 하면 VoiceOver가 "SSL Required"만 읽고 켜짐/꺼짐은 알려주지 않으며,
        // 다른 조회 필드는 라벨 + 값으로 읽히므로 이 행만 값이 비면 한 칸이 빈 것처럼 들린다.
        // 켜짐 값의 키는 `"Required"`다 — 마침표가 붙은 `"Required."`는 빈 필수 입력을 알리는 검증 문구
        // (`필수 항목이에요.`)라, 그쪽을 쓰면 SSL 상태 대신 엉뚱한 경고가 읽힌다.
        .accessibilityElement(children: .combine)
        .accessibilityValue(Text(isRequired ? .module("Required") : .module("Not Required")))
    }
}

// MARK: - Preview

#if DEBUG

#Preview("Required") {
    DetailSSLRequiredFieldView(isRequired: true)
        .padding()
        .previewWidth(420)
}

#Preview("Not Required") {
    DetailSSLRequiredFieldView(isRequired: false)
        .padding()
        .previewWidth(420)
}

#endif
