// Copyright © 2026 Devault. All rights reserved

import Foundation

import ComposableArchitecture
import DVDomain

/// SecretList / SecretDetail / CreateProject Feature가 공유하는 Secret·Project Client.
/// Live 조립은 Devault(App 타겟)에서 각 UseCase를 wrap한다.
@DependencyClient
public struct SecretClient: Sendable {

  // MARK: - Secret

  public var fetchByQuery: @Sendable (_ query: SecretQuery) async throws -> [Secret]
  /// 무료 한도(15개) 사용량 표시에 쓴다.
  public var totalCountExcludingTrash: @Sendable () async throws -> Int
  public var softDelete: @Sendable (_ id: Secret.ID) async throws -> Secret
  public var restore: @Sendable (_ id: Secret.ID) async throws -> Secret
  public var permanentlyDelete: @Sendable (_ id: Secret.ID) async throws -> Void
  /// 컬렉션 전체를 소프트 삭제한다(예: Expired 목록을 '삭제됨'으로 이동).
  public var softDeleteAll: @Sendable (_ collection: SecretQuery.Collection) async throws -> Void
  /// 컬렉션 전체를 영구 삭제한다(예: Deleted 목록 비우기). 복구 불가.
  public var permanentlyDeleteAll: @Sendable (_ collection: SecretQuery.Collection) async throws -> Void
  /// 생체인증 후 Secret의 암호화된 payload를 복호화해 `CreateSecretPayload`로 반환한다.
  /// secretType/subType에 따라 적절한 도메인 payload 타입으로 dispatch하고 metadata JSON을 병합한다.
  /// - Parameter reason: 시스템 인증 시트에 표시할 사유(`AuthenticationReason`) —
  ///   같은 복호화라도 열람과 수정 진입은 사용자가 누른 버튼이 달라 문장이 달라야 한다.
  public var revealPayload: @Sendable (_ secret: Secret, _ reason: AuthenticationReason) async throws -> CreateSecretPayload
  /// Copy가 자체 인증 정책을 적용하도록 Reveal 인증 없이 payload를 복호화한다.
  /// 반환값은 화면에 공개하지 않고 민감 값 Copy 흐름에서만 사용한다.
  public var loadPayloadForCopy: @Sendable (_ secret: Secret) async throws -> CreateSecretPayload
  /// payload 복호화가 없으므로 **생체인증을 타지 않는다**(`PatchSecretUseCase.updateSimple`).
  public var setLiked: @Sendable (_ id: Secret.ID, _ liked: Bool) async throws -> Secret

  /// 공통 필드·프로젝트 연결과 함께 `change`가 가리키는 것만 다시 쓴다. `PatchSecretUseCase`의 overload 4개를
  /// 그대로 노출하지 않는 이유는 그것들이 제네릭이라 `@DependencyClient`의 저장 프로퍼티에 담기지 않기
  /// 때문이다 — 생성 경로가 `dispatchCreateSecret`으로 같은 문제를 푼 것과 같은 형태로, Live가 `change`를
  /// 보고 overload를 고른다.
  ///
  /// **이 호출 자체는 인증을 타지 않는다** — 암호화만 하고 복호화는 하지 않기 때문이다.
  /// 다만 진입 시점의 인증이 저장 시점까지 열려 있다는 보장은 없으므로, 창이 닫혀 있으면
  /// 화면이 직전에 `authenticate`를 먼저 부른다(`SecretDetailFeature.handleSave`).
  ///
  /// - Parameter patch: 공통 필드. 바뀐 것만 `.set`, 나머지는 `.unchanged`. 이름 trim과
  ///   만료일 23:59:59 고정은 도메인(`PatchSecretUseCase`)이 수행하므로 화면에서 맞출 필요가 없다.
  /// - Parameter projectIds: 연결이 **바뀐 경우에만** `.set`으로 최종 목록 전체를 전달한다.
  ///   바뀌지 않았으면 `.unchanged` — `.set`은 목록이 같아도 연결을 다시 조정하는 write를 일으킨다.
  public var updateSecret: @Sendable (
    _ id: Secret.ID,
    _ patch: SecretPatch,
    _ change: SecretContentChange,
    _ projectIds: PatchField<[Project.ID]>
  ) async throws -> Secret
  /// `Secret` 엔티티에는 프로젝트 정보가 없어 별도 조회가 필요하다.
  public var fetchLinkedProjects: @Sendable (_ secretID: Secret.ID) async throws -> [Project]

  // MARK: - Reveal / Copy

  /// 복호화는 하지 않는다. `revealPayload`가 인증과 복호화를 함께 하므로 첫 reveal에는 그쪽을 쓴다. 이미 복호화된
  /// payload를 들고 있는데 인증 창만 만료된 경우, 다시 복호화할 이유가 없어 이 액션이 필요하다.
  public var authenticate: @Sendable (_ reason: AuthenticationReason) async throws -> Void

  /// 민감 값을 클립보드에 복사한다(`ClipboardCopyPolicy.sensitive`). 설정에 따른 인증,
  /// 설정된 시간 뒤 자동 정리, 반복 복사 감지가 함께 수행된다.
  public var copySensitiveValue: @Sendable (_ value: String) async throws -> Void

  /// 인증도 자동 정리도 반복 감지도 없다(`ClipboardCopyPolicy.plain`). metadata에서 오는 평문(Redirect URL·Public Key·Host 등)은
  /// 비밀이 아니라 민감 값 정책을 적용할 대상이 아니다. 클립보드가 비면 붙여넣으려던 값이 사라지고, 반복 복사가 비정상 접근
  /// 카운터에 쌓이면 하지도 않은 일로 보안 경고가 뜬다.
  public var copyPlainValue: @Sendable (_ value: String) async throws -> Void

  // MARK: - Project

  public var fetchProjects: @Sendable () async throws -> [Project]
  public var createProject: @Sendable (_ name: String) async throws -> Project
  public var linkProject: @Sendable (_ secretID: Secret.ID, _ projectID: Project.ID) async throws -> Void
}

extension SecretClient: TestDependencyKey {
  public static let testValue = SecretClient()
  public static let previewValue = dummyClient()
}

private extension SecretClient {
  static func dummyClient() -> SecretClient {
    SecretClient(
      fetchByQuery: { query in
        let filtered: [Secret]
        switch query.collection {
        case .notice(let referenceDate):
          let windowEnd = SecretQuery.Collection.noticeWindowEnd(from: referenceDate)
          filtered = [Secret].preview.filter {
            guard let expiresAt = $0.expiresAt else { return false }
            return $0.deletedAt == nil && expiresAt >= referenceDate && expiresAt <= windowEnd
          }
        case .expired(let referenceDate):
          filtered = [Secret].preview.filter {
            $0.deletedAt == nil && ($0.expiresAt.map { $0 < referenceDate } ?? false)
          }
        case .deleted:
          filtered = [Secret].preview.filter { $0.deletedAt != nil }
        case .liked:
          filtered = [Secret].preview.filter { $0.deletedAt == nil && $0.liked }
        case .project(let id):
          filtered = [Secret].preview(in: id)
        case .all:
          filtered = [Secret].preview.filter { $0.deletedAt == nil }
        }
        return sorted(filtered, by: query.sort)
      },
      totalCountExcludingTrash: { [Secret].preview.filter { $0.deletedAt == nil }.count },
      softDelete: { _ in .preview },
      restore: { _ in .preview },
      permanentlyDelete: { _ in },
      softDeleteAll: { _ in },
      permanentlyDeleteAll: { _ in },
      // live와 case 구성이 1:1로 일치해야 한다 — 한쪽만 바뀌면 프리뷰가 실제와 다른 payload 타입을 조용히 반환한다.
      revealPayload: { secret, _ in
          switch (secret.secretType, secret.subType) {
          case (.apiKeyToken, .apiKey), (.apiKeyToken, nil):
              return .apiKey(
                APIKeyPayload(value: "preview_api_key"),
                APIKeyMetadata(scope: "repo:read")
              )
          case (.apiKeyToken, .accessToken):
              return .accessToken(
                APIKeyPayload(value: "preview_access_token"),
                APIKeyMetadata(scope: "user:email")
              )
          case (.apiKeyToken, .webhookSecret):
              return .webhookSecret(
                APIKeyPayload(value: "preview_webhook_secret"),
                APIKeyMetadata(scope: "push, pull_request")
              )
          case (.oauth, .oauthClient), (.oauth, nil):
              return .oauthClient(
                OAuthClientPayload(clientId: "preview_id", clientSecret: "preview_secret"),
                OAuthClientMetadata(
                    redirectUri: "https://preview.devault.app/oauth/callback",
                    scopes: "openid, profile, email"
                )
              )
          case (.oauth, .serviceAccount):
              return .serviceAccount(
                ServiceAccountPayload(
                    credentialJSON: """
                    {
                      "type": "service_account",
                      "project_id": "devault-preview",
                      "client_email": "preview-bot@devault-preview.iam.gserviceaccount.com"
                    }
                    """
                ),
                ServiceAccountMetadata(authority: "organization-admin")
              )
          case (.database, _):
              return .database(
                DatabasePayload(linkString: "postgresql://preview:5432/db"),
                DatabaseMetadata(sslRequired: true)
              )
          case (.sshAndCredentials, .sshKey), (.sshAndCredentials, nil):
              return .sshKey(
                SSHKeyPayload(
                    privateKey: "-----BEGIN RSA PRIVATE KEY-----\npreview\n-----END RSA PRIVATE KEY-----",
                    passphrase: nil
                ),
                SSHKeyMetadata(
                    publicKey: "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABpreview deploy@preview",
                    host: "deploy.preview.internal",
                    username: "deploy"
                )
              )
          case (.sshAndCredentials, .sslTlsCertificate):
              return .sslTlsCertificate(
                SSLCertPayload(
                    certificate: "-----BEGIN CERTIFICATE-----\npreview\n-----END CERTIFICATE-----",
                    privateKey: "-----BEGIN PRIVATE KEY-----\npreview\n-----END PRIVATE KEY-----",
                    certificateChain: "-----BEGIN CERTIFICATE-----\npreview-intermediate\n-----END CERTIFICATE-----"
                ),
                SSLCertMetadata(renewCommand: "certbot renew --cert-name preview.devault.app")
              )
          case (.environmentVariableSet, _):
              return .environmentVariableSet(EnvSetPayload(content: "KEY=value\nOTHER=123"))
          case (.etc, .licenseKey), (.etc, nil):
              return .licenseKey(
                LicenseKeyPayload(licenseKey: "PREVIEW-LICENSE-1234"),
                LicenseKeyMetadata(
                    licenseType: "team",
                    registrationEmail: "support@preview.devault.app",
                    orderNumber: "DV-2026-000123",
                    website: "https://preview.devault.app"
                )
              )
          case (.etc, .custom):
              return .custom(CustomPayload(value: "preview_custom_value"))
          default:
              assertionFailure("Unexpected (secretType, subType) combination: \(secret.secretType), \(String(describing: secret.subType))")
              throw SecretUseCaseError.unexpected
          }
      },
      loadPayloadForCopy: { secret in
        // 프리뷰는 인증을 타지 않으므로 문구가 무엇이든 결과가 같다.
        try await dummyClient().revealPayload(secret, .revealSecret)
      },
      setLiked: { _, liked in
          var secret = Secret.preview
          secret.liked = liked
          return secret
      },
      // 편집한 값이 프리뷰에서도 화면에 반영되도록 patch를 실제로 적용해 돌려준다.
      // payload·metadata는 프리뷰에서 확인할 대상이 아니라 건드리지 않는다.
      updateSecret: { id, patch, _, _ in
          var secret = Secret.preview
          secret.id = id
          if case .set(let name) = patch.name { secret.name = name }
          if case .set(let service) = patch.service { secret.service = service }
          if case .set(let environment) = patch.environment { secret.environment = environment }
          if case .set(let expiresAt) = patch.expiresAt { secret.expiresAt = expiresAt }
          if case .set(let memo) = patch.memo { secret.memo = memo }
          secret.updatedAt = .now
          return secret
      },
      fetchLinkedProjects: { _ in Array([Project].preview.prefix(1)) },
      // 프리뷰는 인증 시트를 띄울 수 없으므로 즉시 통과시킨다.
      authenticate: { _ in },
      copySensitiveValue: { _ in },
      copyPlainValue: { _ in },
      fetchProjects: { .preview },
      createProject: { name in
          Project(id: UUID(), name: name, createdAt: .now, updatedAt: .now)
      },
      linkProject: { _, _ in }
    )
  }

  static func sorted(_ secrets: [Secret], by sort: SecretQuery.Sort) -> [Secret] {
    switch sort.key {
    case .time:
      switch sort.direction {
      case .ascending: return secrets.sorted { $0.updatedAt < $1.updatedAt }
      case .descending: return secrets.sorted { $0.updatedAt > $1.updatedAt }
      }
    case .expiry:
      // 만료일 없는 항목은 방향과 무관하게 맨 뒤로 — 실제 InMemorySecretQueryFilter와 같은 규칙.
      let withExpiry = secrets.filter { $0.expiresAt != nil }
      let withoutExpiry = secrets.filter { $0.expiresAt == nil }
      let sortedByExpiry = withExpiry.sorted { lhs, rhs in
        guard let lhsExpiresAt = lhs.expiresAt, let rhsExpiresAt = rhs.expiresAt else { return false }
        switch sort.direction {
        case .ascending: return lhsExpiresAt < rhsExpiresAt
        case .descending: return lhsExpiresAt > rhsExpiresAt
        }
      }
      return sortedByExpiry + withoutExpiry
    case .name:
      switch sort.direction {
      case .ascending: return secrets.sorted { $0.name < $1.name }
      case .descending: return secrets.sorted { $0.name > $1.name }
      }
    }
  }
}

extension DependencyValues {
  public var secretClient: SecretClient {
    get { self[SecretClient.self] }
    set { self[SecretClient.self] = newValue }
  }
}
