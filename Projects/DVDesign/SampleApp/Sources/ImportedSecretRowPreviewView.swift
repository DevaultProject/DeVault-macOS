// Copyright © 2026 Devault. All rights reserved

import SwiftUI
import DVDesign

struct ImportedSecretRowPreviewView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                section(title: "기본") {
                    labeled("기본") {
                        ImportedSecretRowView(name: "GitHub Token", subTypeText: "Access Token")
                    }
                    labeled("강조 — Preview 화면") {
                        ImportedSecretRowView(name: "GitHub Token", subTypeText: "Access Token", isHighlighted: true)
                    }
                }

                section(title: "상태 문구") {
                    labeled("중복됨") {
                        ImportedSecretRowView(
                            name: "GitHub Token",
                            subTypeText: "Access Token",
                            isHighlighted: true,
                            statusText: "Duplicated"
                        )
                    }
                }

                section(title: "좁은 폭") {
                    labeled("이름 길어짐") {
                        ImportedSecretRowView(
                            name: "Very Long Secret Name That Should Truncate",
                            subTypeText: "API Webhook Secret"
                        )
                        .frame(width: 240)
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("ImportedSecretRow")
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

    @ViewBuilder
    private func labeled<Content: View>(
        _ caption: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(caption).font(.caption).foregroundStyle(.secondary)
            content()
        }
    }
}
