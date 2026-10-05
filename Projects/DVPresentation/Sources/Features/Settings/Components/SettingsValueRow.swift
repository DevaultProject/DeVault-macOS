// Copyright © 2026 Devault. All rights reserved

import SwiftUI

import DVDesign

struct SettingsValueRow: View {
  enum ValueStyle {
    case regular
    case emphasized
  }

  let title: String
  let description: String?
  let value: String?
  let valueStyle: ValueStyle
  let systemImage: String?
  let iconColor: Color?

  init(
    title: String,
    description: String? = nil,
    value: String? = nil,
    valueStyle: ValueStyle = .regular,
    systemImage: String? = nil,
    iconColor: Color? = nil
  ) {
    self.title = title
    self.description = description
    self.value = value
    self.valueStyle = valueStyle
    self.systemImage = systemImage
    self.iconColor = iconColor
  }

  var body: some View {
    HStack(alignment: .center) {
      if let systemImage {
        Image(systemName: systemImage)
          .foregroundStyle(iconColor ?? Color.dv(.gray500))
          .accessibilityHidden(true)
      }
      VStack(alignment: .leading, spacing: 2) {
        Text(title)
          .dvFont(.bodyLG)
          .foregroundStyle(Color.dv(.gray900))
        if let description {
          Text(description)
            .dvFont(.captionMDRegular)
            .foregroundStyle(Color.dv(.gray600))
        }
      }
      Spacer(minLength: 12)
      if let value {
        valueText(value)
      }
    }
    .settingsRowLayout()
  }

  @ViewBuilder
  private func valueText(_ value: String) -> some View {
    switch valueStyle {
    case .regular:
      Text(value)
        .dvFont(.captionMDRegular)
        .foregroundStyle(Color.dv(.gray600))
    case .emphasized:
      Text(value)
        .dvFont(.captionLG)
        .foregroundStyle(Color.dv(.gray600))
    }
  }
}

// MARK: - Preview

#Preview("Settings Value Row") {
  Form {
    Section {
      SettingsValueRow(title: "DeVault", value: "1.0.0 (1)")
      SettingsValueRow(title: "Open Settings", value: "⌘,", valueStyle: .emphasized)
    }
  }
  .formStyle(.grouped)
  .scrollContentBackground(.hidden)
  .frame(width: WindowLayoutMetrics.settingsDetailWidth)
  .background(Color.dv(.gray100))
}
