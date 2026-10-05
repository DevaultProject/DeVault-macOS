// Copyright © 2026 Devault. All rights reserved

import DVDesign
import DVDomain
import SwiftUI

/// `CreatableSecretType.etc`의 `.licenseKey` 서브타입 폼 섹션.
/// Figma상 Environment 필드 없음 (LicenseTier "Type"이 오른쪽 페어 슬롯 차지) — common env 바인딩 제외.
struct LicenseKeySectionView: View, CreateSecretSectionHintProviding {

    // MARK: - Common Fields (Environment 없음 — Type이 대체)

    @Binding var name: String
    @Binding var projectIds: [Project.ID]
    @Binding var service: String
    @Binding var expireDate: Date?
    @Binding var memo: String

    // MARK: - Type-Specific

    /// `LicenseKeyFields`: `.licenseKey`(required) + `.licenseTier` + `.registrationEmail`(Support Email)
    /// + `.orderNumber` + `.website`.
    @Binding var licenseKey: LicenseKeyFields

    // MARK: - Context

    let availableProjects: [Project]
    let serviceCandidates: [String]
    let validationErrors: [SecretMetaFields.FieldID: String]
    let detectedServices: [SecretMetaFields.FieldID: String]

    // MARK: - Callbacks

    let onCreateProject: () -> Void

    // MARK: - Body

    var body: some View {
        FormSectionScaffold(
            name: $name,
            nameWarning: validationErrors[.name],
            memo: $memo
        ) {
            LabeledTextFieldView(
                // "License Key"는 서브타입 선택 버튼과 String Catalog 키가 겹쳐 별도 키로 분리한다.
                label: .module("License Key Value"),
                placeholder: .module("e.g XXXXX-XXXXX-XXXXX-XXXXX"),
                text: $licenseKey.licenseKey,
                isRequired: true,
                isSecure: true,
                sizeMode: .fullWidth,
                trailingHint: hintFor(.licenseKey)
            )

            AdaptiveFieldRow {
                ProjectFieldView(
                    projectIds: $projectIds,
                    availableProjects: availableProjects,
                    onCreateProject: onCreateProject,
                    sizeMode: .paired
                )
            } right: {
                ServicesFieldView(
                    suggestedChips: serviceCandidates,
                    input: $service
                )
            }

            AdaptiveFieldRow {
                ExpireDateFieldView(expireDate: $expireDate)
            } right: {
                LicenseTierFieldView(tier: $licenseKey.licenseTier)
            }

            LabeledTextFieldView(
                label: .module("Support Email"),
                placeholder: .module("e.g support@example.com"),
                text: $licenseKey.registrationEmail,
                sizeMode: .fullWidth
            )

            LabeledTextFieldView(
                label: .module("Website"),
                placeholder: .module("e.g https://example.com"),
                text: $licenseKey.website,
                sizeMode: .fullWidth
            )

            LabeledTextFieldView(
                label: .module("Order Number"),
                placeholder: .module("e.g ORD-2026-0001"),
                text: $licenseKey.orderNumber,
                sizeMode: .fullWidth
            )

        }
    }

}

// MARK: - Preview

#if DEBUG

private let previewProjects: [Project] = [
    Project(id: UUID(), name: "DrinkiG",     createdAt: Date(), updatedAt: Date()),
    Project(id: UUID(), name: "CheerLot",    createdAt: Date(), updatedAt: Date()),
]

#Preview("Empty · Dual (Wide)") {
    LicenseKeySectionPreview()
        .padding(24)
        .formLayout(.dual)
        .previewWidth(.wide)
}

#Preview("Filled · Dual (Wide)") {
    LicenseKeySectionPreview(
        name: "JetBrains License",
        licenseKey: "AAAA-BBBB-CCCC-DDDD-EEEE",
        licenseTier: .team,
        registrationEmail: "team@example.com",
        website: "https://jetbrains.com",
        orderNumber: "ORD-2026-0042",
        selectedProjectIds: Array(previewProjects.prefix(1).map(\.id)),
        candidates: ["JetBrains"]
    )
    .padding(24)
    .formLayout(.dual)
    .previewWidth(.wide)
}

#Preview("Filled · Single (Narrow)") {
    LicenseKeySectionPreview(
        name: "JetBrains License",
        licenseKey: "AAAA-BBBB-CCCC-DDDD-EEEE",
        licenseTier: .team,
        registrationEmail: "team@example.com",
        selectedProjectIds: Array(previewProjects.prefix(1).map(\.id))
    )
    .padding(24)
    .formLayout(.single)
    .previewWidth(.narrow)
}

#Preview("Validation errors · Dual") {
    LicenseKeySectionPreview(
        errors: [.name: "Required", .licenseKey: "Required"]
    )
    .padding(24)
    .formLayout(.dual)
    .previewWidth(.wide)
}

private struct LicenseKeySectionPreview: View {

    @State var name: String
    @State var licenseKey: String
    @State var licenseTier: LicenseTier
    @State var registrationEmail: String
    @State var website: String
    @State var orderNumber: String
    @State var projectIds: [Project.ID]
    @State var service: String
    @State var expireDate: Date? = nil
    @State var memo: String = ""

    let candidates: [String]
    let errors: [SecretMetaFields.FieldID: String]

    init(
        name: String = "",
        licenseKey: String = "",
        licenseTier: LicenseTier = .individual,
        registrationEmail: String = "",
        website: String = "",
        orderNumber: String = "",
        selectedProjectIds: [Project.ID] = [],
        service: String = "",
        candidates: [String] = [],
        errors: [SecretMetaFields.FieldID: String] = [:]
    ) {
        _name = State(initialValue: name)
        _licenseKey = State(initialValue: licenseKey)
        _licenseTier = State(initialValue: licenseTier)
        _registrationEmail = State(initialValue: registrationEmail)
        _website = State(initialValue: website)
        _orderNumber = State(initialValue: orderNumber)
        _projectIds = State(initialValue: selectedProjectIds)
        _service = State(initialValue: service)
        self.candidates = candidates
        self.errors = errors
    }

    var body: some View {
        ScrollView {
            LicenseKeySectionView(
                name: $name,
                projectIds: $projectIds,
                service: $service,
                expireDate: $expireDate,
                memo: $memo,
                licenseKey: licenseKeyBinding,
                availableProjects: previewProjects,
                serviceCandidates: candidates,
                validationErrors: errors,
                detectedServices: [:],
                onCreateProject: {}
            )
            .padding(16)
        }
    }

    private var licenseKeyBinding: Binding<LicenseKeyFields> {
        Binding(
            get: {
                LicenseKeyFields(
                    licenseKey: licenseKey,
                    licenseTier: licenseTier,
                    registrationEmail: registrationEmail,
                    orderNumber: orderNumber,
                    website: website
                )
            },
            set: {
                licenseKey = $0.licenseKey
                licenseTier = $0.licenseTier
                registrationEmail = $0.registrationEmail
                orderNumber = $0.orderNumber
                website = $0.website
            }
        )
    }
}

#endif
