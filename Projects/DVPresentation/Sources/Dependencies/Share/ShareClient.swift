// Copyright © 2026 Devault. All rights reserved

import Foundation

import ComposableArchitecture
import DVDomain

/// 시크릿 공유(.dvt) Export/Import Feature가 공유하는 Client. 계약 Ⓕ — 아직 목(mock) 상태.
@DependencyClient
public struct ShareClient: Sendable {

  /// Export 직전 Touch ID 인증.
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
