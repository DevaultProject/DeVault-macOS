// Copyright © 2026 Devault. All rights reserved

import Foundation

import ComposableArchitecture
import DVDomain

/// 시크릿 공유(.dvt) Export/Import Feature가 공유하는 Client. 계약 Ⓕ — Live 조립은
/// Devault(App 타겟)에서 `ExportSecretsUseCase`/`ImportSecretsUseCase`를 wrap한다.
///
/// 백엔드 레인(`ExportSecretsUseCase`)이 아직 develop에 머지되지 않아, 지금은 소비 측(Export
/// Sheet)이 먼저 착수할 수 있도록 시그니처만 정의한 목(mock) 상태다. 실구현 교체 시 메서드
/// 시그니처는 유지하고 본문만 Live로 바꾼다.
@DependencyClient
public struct ShareClient: Sendable {

  /// Export 직전 Touch ID 인증. `AuthenticateUseCase`를 공유 싱글턴 actor로 경유해야 하므로
  /// Feature가 직접 `AuthenticateUseCase`를 들지 않고 이 Client를 통해서만 호출한다.
  public var authenticate: @Sendable (_ reason: AuthenticationReason) async throws -> Void

  /// 선택된 시크릿들을 암호화해 `.dvt` 파일로 만든다. `expiresAt`이 `nil`이면 만료 없음.
  public var exportSecrets: @Sendable (
    _ secretIDs: [Secret.ID],
    _ password: String,
    _ expiresAt: Date?
  ) async throws -> URL
}

extension ShareClient: TestDependencyKey {
  public static let testValue = ShareClient()
  public static let previewValue = ShareClient(
    authenticate: { _ in },
    exportSecrets: { _, _, _ in
      URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("preview.dvt")
    }
  )
}

extension DependencyValues {
  public var shareClient: ShareClient {
    get { self[ShareClient.self] }
    set { self[ShareClient.self] = newValue }
  }
}
