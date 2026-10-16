// Copyright © 2026 Devault. All rights reserved

import SwiftUI

import DVDesign

/// Review Duplicates 화면의 "Overwrite/Rename/Skip" 선택지 — `DVRadioButton`의
/// 커스텀 라벨로 제목+설명 두 줄을 얹는다. 인디케이터는 `DVRadioButton` 내부
/// HStack이 두 줄 전체 높이에 가운데 정렬한다(제목 줄에 맞춰 위쪽 정렬이
/// 아님) — mockup과 완전히 같진 않지만 새로 만들기보다 재사용을 택했다.
struct DuplicateActionOptionView: View {

  let title: String
  let description: String
  let isSelected: Bool
  let action: () -> Void

  var body: some View {
    DVRadioButton(isSelected: isSelected, action: action) {
      VStack(alignment: .leading, spacing: 4) {
        Text(title)
          .dvFont(.bodyLG)
          .foregroundStyle(Color.dv(.gray900))
        Text(description)
          .dvFont(.bodyMD)
          .foregroundStyle(Color.dv(.gray600))
      }
    }
  }
}

// MARK: - Preview

#if DEBUG

#Preview("세 옵션") {
  VStack(alignment: .leading, spacing: 16) {
    DuplicateActionOptionView(
      title: String.module("Overwrite"),
      description: String.module("Replace the existing secret with the imported secret."),
      isSelected: false,
      action: {}
    )
    DuplicateActionOptionView(
      title: String.module("Rename"),
      description: String.module("Keep both secrets by giving the imported secret a new name."),
      isSelected: true,
      action: {}
    )
    DuplicateActionOptionView(
      title: String.module("Skip"),
      description: String.module("Keep the existing secret and skip this item."),
      isSelected: false,
      action: {}
    )
  }
  .padding(20)
  .frame(width: 340)
}

#endif
