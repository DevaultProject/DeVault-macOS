// Copyright © 2026 Devault. All rights reserved

import ComposableArchitecture
import DVDomain
import SwiftUI

// MARK: - CreateSecretView

struct CreateSecretView: View {

    // MARK: - Properties

    @Bindable var store: StoreOf<CreateSecretFeature>

    // MARK: - Body

    var body: some View {
        GeometryReader { proxy in
            // 본문 좌우 여백은 ScrollView 안쪽(`scrollContent`)에 둔다. 바깥에 두면 스크롤 경계가 필드 테두리와 겹쳐 stroke 바깥 절반이 잘린다.
            VStack(spacing: 20) {
                header
                    .padding(.horizontal, FormLayoutMetrics.horizontalPadding)
                scrollContent
                footer
                    .padding(.horizontal, FormLayoutMetrics.horizontalPadding)
            }
            .padding(.vertical, 16)
            // 프레임 상한. 없으면 본문 필드는 제자리인데 footer 버튼만 창 오른쪽 끝까지 밀려난다.
            .formMaxWidth()
            .formLayout(StandaloneFormLayout.layout(for: proxy.size.width))
            .environment(\.isProjectLoading, store.isLoadingProjects)
        }
        // Min: apiKeyToken 3-radio 헤더의 자연 폭(~460pt)이 지배 제약. padding 40 + 여유 포함.
        .frame(minWidth: 520, minHeight: 400)
        .task { await store.send(.task).finish() }
        .alert($store.scope(state: \.alert, action: \.alert))
        .sheet(item: $store.scope(state: \.createProject, action: \.createProject)) { store in
            CreateProjectView(store: store)
        }
    }
}

// MARK: - Subviews

extension CreateSecretView {

    /// FIXED TOP. SecretType 타이틀 + subtype radio 탭바.
    private var header: some View {
        CreateSecretHeaderView(
            secretType: store.secretType,
            selectedSubType: store.selectedSubType,
            onSelectSubType: { subType in
                store.send(.set(\.selectedSubType, subType))
            }
        )
    }

    /// 중간 스크롤 영역. 타입별 분기는 `SecretFormSectionsView`가 맡는다 — 수정 화면과 공유한다.
    private var scrollContent: some View {
        ScrollView {
            SecretFormSectionsView(
                secretType: store.secretType,
                subType: store.selectedSubType,
                meta: $store.meta,
                availableProjects: store.availableProjects,
                serviceCandidates: store.serviceCandidates,
                validationErrors: store.validationErrors,
                detectedServices: store.detectedServices,
                onCreateProject: { store.send(.didTapCreateProject) }
            )
            .padding(.horizontal, FormLayoutMetrics.horizontalPadding)
            // 위아래 스크롤 경계에 닿은 필드 테두리(1pt stroke)가 반쯤 잘리지 않게 띄운다.
            .padding(.vertical, 1)
        }
        .scrollIndicators(.hidden)
        .disabled(store.isSaving)
        .windowBusy(store.isSaving)
    }

    /// FIXED BOTTOM. Cancel + Save 액션 바.
    private var footer: some View {
        FooterActionsView(
            isSaveEnabled: store.isSaveEnabled,
            onCancel: { store.send(.didTapCancel) },
            onSave: { store.send(.didTapSave) }
        )
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

}

// MARK: - Preview

#if DEBUG

private func previewState(
    fill: Bool = false,
    withProjects: Bool = false
) -> CreateSecretFeature.State {
    var state = CreateSecretFeature.State(secretType: .apiKeyToken)
    if withProjects {
        let seed: [Project] = [
            Project(id: UUID(), name: "DrinkiG", createdAt: Date(), updatedAt: Date()),
            Project(id: UUID(), name: "Longlonglong Project Name", createdAt: Date(), updatedAt: Date()),
            Project(id: UUID(), name: "CheerLot", createdAt: Date(), updatedAt: Date()),
            Project(id: UUID(), name: "SipStream", createdAt: Date(), updatedAt: Date()),
        ]
        state.availableProjects = seed
        state.meta.projectIds = Array(seed.prefix(2).map(\.id))
        state.serviceCandidates = ["GitHub", "NameNameName"]
    }
    if fill {
        state.meta.name = "GitHub Access Token"
        state.meta.content = .apiKeyToken(APIKeyTokenFields(value: "ghp_1234567890", authorityScope: "repo:read"))
        state.detectedServices = [.value: "GitHub"]
    }
    return state
}

#Preview("Wide · Empty (Dual)") {
    CreateSecretView(
        store: Store(initialState: previewState()) {
            CreateSecretFeature()
        }
    )
    .previewWidth(.wide)
}

#Preview("Wide · Filled + hint (Dual)") {
    CreateSecretView(
        store: Store(initialState: previewState(fill: true, withProjects: true)) {
            CreateSecretFeature()
        }
    )
    .previewWidth(.wide)
    .frame(height: 700)
}

#Preview("Narrow · Filled (Single, scrollable)") {
    CreateSecretView(
        store: Store(initialState: previewState(fill: true, withProjects: true)) {
            CreateSecretFeature()
        }
    )
    .previewWidth(.narrow)
    .frame(height: 700)
}

#Preview("Medium · Empty (Single)") {
    CreateSecretView(
        store: Store(initialState: previewState()) {
            CreateSecretFeature()
        }
    )
    .previewWidth(.medium)
}

#Preview("OAuth Client · Wide (Dual)") {
    CreateSecretView(
        store: Store(initialState: oauthPreviewState(subType: .oauthClient, fill: true)) {
            CreateSecretFeature()
        }
    )
    .previewWidth(.wide)
    .frame(height: 700)
}

#Preview("OAuth Client · Narrow (Single, scrollable)") {
    CreateSecretView(
        store: Store(initialState: oauthPreviewState(subType: .oauthClient, fill: true)) {
            CreateSecretFeature()
        }
    )
    .previewWidth(.narrow)
    .frame(height: 700)
}

#Preview("Service Account · Wide (Dual)") {
    CreateSecretView(
        store: Store(initialState: oauthPreviewState(subType: .serviceAccount, fill: true)) {
            CreateSecretFeature()
        }
    )
    .previewWidth(.wide)
    .frame(height: 700)
}

#Preview("Service Account · Narrow (Single)") {
    CreateSecretView(
        store: Store(initialState: oauthPreviewState(subType: .serviceAccount, fill: true)) {
            CreateSecretFeature()
        }
    )
    .previewWidth(.narrow)
    .frame(height: 700)
}

#Preview("Database · Wide (Dual)") {
    CreateSecretView(
        store: Store(initialState: databasePreviewState(fill: true)) {
            CreateSecretFeature()
        }
    )
    .previewWidth(.wide)
    .frame(height: 700)
}

#Preview("Database · Narrow (Single)") {
    CreateSecretView(
        store: Store(initialState: databasePreviewState(fill: true)) {
            CreateSecretFeature()
        }
    )
    .previewWidth(.narrow)
    .frame(height: 700)
}

#Preview("SSH Key · Wide (Dual)") {
    CreateSecretView(
        store: Store(initialState: sshPreviewState(subType: .sshKey, fill: true)) {
            CreateSecretFeature()
        }
    )
    .previewWidth(.wide)
    .frame(height: 700)
}

#Preview("SSH Key · Narrow (Single)") {
    CreateSecretView(
        store: Store(initialState: sshPreviewState(subType: .sshKey, fill: true)) {
            CreateSecretFeature()
        }
    )
    .previewWidth(.narrow)
    .frame(height: 700)
}

#Preview("SSL/TLS Cert · Wide (Dual)") {
    CreateSecretView(
        store: Store(initialState: sshPreviewState(subType: .sslTlsCertificate, fill: true)) {
            CreateSecretFeature()
        }
    )
    .previewWidth(.wide)
    .frame(height: 700)
}

#Preview("SSL/TLS Cert · Narrow (Single)") {
    CreateSecretView(
        store: Store(initialState: sshPreviewState(subType: .sslTlsCertificate, fill: true)) {
            CreateSecretFeature()
        }
    )
    .previewWidth(.narrow)
    .frame(height: 700)
}

#Preview("EnvSet · Wide (Dual)") {
    CreateSecretView(
        store: Store(initialState: envSetPreviewState(fill: true)) {
            CreateSecretFeature()
        }
    )
    .previewWidth(.wide)
    .frame(height: 700)
}

#Preview("EnvSet · Narrow (Single)") {
    CreateSecretView(
        store: Store(initialState: envSetPreviewState(fill: true)) {
            CreateSecretFeature()
        }
    )
    .previewWidth(.narrow)
    .frame(height: 700)
}

#Preview("License Key · Wide (Dual)") {
    CreateSecretView(
        store: Store(initialState: etcPreviewState(subType: .licenseKey, fill: true)) {
            CreateSecretFeature()
        }
    )
    .previewWidth(.wide)
}

#Preview("License Key · Narrow (Single)") {
    CreateSecretView(
        store: Store(initialState: etcPreviewState(subType: .licenseKey, fill: true)) {
            CreateSecretFeature()
        }
    )
    .previewWidth(.narrow)
    .frame(height: 700)
}

#Preview("Custom · Wide (Dual)") {
    CreateSecretView(
        store: Store(initialState: etcPreviewState(subType: .custom, fill: true)) {
            CreateSecretFeature()
        }
    )
    .previewWidth(.wide)
}

#Preview("Custom · Narrow (Single)") {
    CreateSecretView(
        store: Store(initialState: etcPreviewState(subType: .custom, fill: true)) {
            CreateSecretFeature()
        }
    )
    .previewWidth(.narrow)
    .frame(height: 700)
}

private func etcPreviewState(
    subType: CreatableSecretSubType,
    fill: Bool = false
) -> CreateSecretFeature.State {
    var state = CreateSecretFeature.State(secretType: .etc)
    state.selectedSubType = subType

    let seed: [Project] = [
        Project(id: UUID(), name: "DrinkiG", createdAt: Date(), updatedAt: Date()),
    ]
    state.availableProjects = seed
    state.meta.projectIds = Array(seed.prefix(1).map(\.id))

    guard fill else {
        state.meta.content = .default(for: .etc, subType: subType)
        return state
    }

    state.meta.name = subType == .licenseKey ? "JetBrains License" : "Legacy Custom Secret"
    switch subType {
    case .licenseKey:
        state.meta.content = .licenseKey(
            LicenseKeyFields(
                licenseKey: "AAAA-BBBB-CCCC-DDDD-EEEE",
                licenseTier: .team,
                registrationEmail: "team@example.com",
                orderNumber: "ORD-2026-0042",
                website: "https://jetbrains.com"
            )
        )
    case .custom:
        state.meta.content = .custom(CustomFields(value: "abc123-legacy-value"))
    default:
        state.meta.content = .default(for: .etc, subType: subType)
    }
    return state
}

private func sshPreviewState(
    subType: CreatableSecretSubType,
    fill: Bool = false
) -> CreateSecretFeature.State {
    var state = CreateSecretFeature.State(secretType: .sshAndCredentials)
    state.selectedSubType = subType

    let seed: [Project] = [
        Project(id: UUID(), name: "DrinkiG", createdAt: Date(), updatedAt: Date()),
    ]
    state.availableProjects = seed
    state.meta.projectIds = Array(seed.prefix(1).map(\.id))

    guard fill else {
        state.meta.content = .default(for: .sshAndCredentials, subType: subType)
        return state
    }

    state.meta.name = subType == .sshKey ? "Bastion SSH Key" : "example.com TLS"
    switch subType {
    case .sshKey:
        state.meta.content = .sshKey(
            SSHKeyFields(
                privateKey: "-----BEGIN OPENSSH PRIVATE KEY-----\n...",
                passphrase: "secret-phrase",
                publicKey: "ssh-rsa AAAA...",
                host: "bastion.example.com",
                username: "ubuntu"
            )
        )
    case .sslTlsCertificate:
        state.meta.content = .sslTlsCertificate(
            SSLCertFields(
                certificate: "-----BEGIN CERTIFICATE-----\n...",
                sslPrivateKey: "-----BEGIN PRIVATE KEY-----\n...",
                certificateChain: "-----BEGIN CERTIFICATE-----\n...",
                renewCommand: "certbot renew --cert-name example.com"
            )
        )
    default:
        state.meta.content = .default(for: .sshAndCredentials, subType: subType)
    }
    return state
}

private func envSetPreviewState(fill: Bool = false) -> CreateSecretFeature.State {
    var state = CreateSecretFeature.State(secretType: .environmentVariableSet)

    let seed: [Project] = [
        Project(id: UUID(), name: "DrinkiG", createdAt: Date(), updatedAt: Date()),
    ]
    state.availableProjects = seed
    state.meta.projectIds = Array(seed.prefix(1).map(\.id))

    guard fill else { return state }

    state.meta.name = "Backend .env"
    state.meta.content = .envSet(
        EnvSetFields(envContent: "DATABASE_URL=postgres://...\nSECRET_KEY=abc123")
    )
    return state
}

private func databasePreviewState(fill: Bool = false) -> CreateSecretFeature.State {
    var state = CreateSecretFeature.State(secretType: .database)

    let seed: [Project] = [
        Project(id: UUID(), name: "DrinkiG", createdAt: Date(), updatedAt: Date()),
        Project(id: UUID(), name: "CheerLot", createdAt: Date(), updatedAt: Date()),
    ]
    state.availableProjects = seed
    state.meta.projectIds = Array(seed.prefix(1).map(\.id))

    guard fill else { return state }

    state.meta.name = "Production PostgreSQL"
    state.meta.content = .database(
        DatabaseFields(
            linkString: "postgres://user:pass@db.example.com:5432/main",
            isSSLRequired: true
        )
    )
    return state
}

private func oauthPreviewState(
    subType: CreatableSecretSubType,
    fill: Bool = false
) -> CreateSecretFeature.State {
    var state = CreateSecretFeature.State(secretType: .oauth)
    state.selectedSubType = subType

    let seed: [Project] = [
        Project(id: UUID(), name: "DrinkiG", createdAt: Date(), updatedAt: Date()),
        Project(id: UUID(), name: "CheerLot", createdAt: Date(), updatedAt: Date()),
    ]
    state.availableProjects = seed
    state.meta.projectIds = Array(seed.prefix(1).map(\.id))

    guard fill else {
        state.meta.content = .default(for: .oauth, subType: subType)
        return state
    }

    state.meta.name = "Sample OAuth Secret"
    switch subType {
    case .oauthClient:
        state.meta.content = .oauthClient(
            OAuthClientFields(
                clientId: "Iv1.abc123",
                clientSecret: "ghs_secret456",
                redirectUri: "https://app.example/oauth/callback",
                scopes: "read:user, write:issue"
            )
        )
    case .serviceAccount:
        state.meta.content = .serviceAccount(
            ServiceAccountFields(
                credentialJSON: #"{"type": "service_account", "project_id": "my-proj"}"#,
                authority: "organization-admin"
            )
        )
    default:
        state.meta.content = .default(for: .oauth, subType: subType)
    }
    return state
}

#endif
