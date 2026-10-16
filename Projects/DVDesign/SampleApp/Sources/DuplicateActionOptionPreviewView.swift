// Copyright © 2026 Devault. All rights reserved

import SwiftUI
import DVDesign

struct DuplicateActionOptionPreviewView: View {
    private enum Choice: String, CaseIterable {
        case overwrite = "Overwrite"
        case rename = "Rename"
        case skip = "Skip"

        var description: String {
            switch self {
            case .overwrite: return "Replace the existing secret with the imported secret."
            case .rename: return "Keep both secrets by giving the imported secret a new name."
            case .skip: return "Keep the existing secret and skip this item."
            }
        }
    }

    @State private var selected: Choice = .rename

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                section(title: "인터랙션 — 클릭 시 선택 전환") {
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(Choice.allCases, id: \.self) { choice in
                            DuplicateActionOptionView(
                                title: choice.rawValue,
                                description: choice.description,
                                isSelected: selected == choice
                            ) {
                                selected = choice
                            }
                        }
                    }
                    .frame(width: 340)
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("DuplicateActionOption")
    }

    @ViewBuilder
    private func section<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title).font(.title2).fontWeight(.bold)
            content()
        }
    }
}
