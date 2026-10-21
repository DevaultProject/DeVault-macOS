// Copyright © 2026 Devault. All rights reserved

import Foundation

import ComposableArchitecture
import DVDomain

/// 시크릿 공유(.dvt) Export/Import Feature가 공유하는 Client. 계약 Ⓕ.
@DependencyClient
public struct ShareClient: Sendable {

  /// Export·Import 직전 Touch ID 인증.
  public var authenticate: @Sendable (_ reason: AuthenticationReason) async throws -> Void

  /// 선택된 시크릿들을 암호화해 `.dvt` 파일로 만든다. `expiresAt`이 `nil`이면 만료 없음.
  ///
  /// 반환된 임시 파일의 **삭제는 호출부 책임이다** — 시크릿 전체가 담겨 있어 공유·저장이 끝나면 지워야 한다.
  public var exportSecrets: @Sendable (
    _ secretIDs: [Secret.ID],
    _ password: String,
    _ expiresAt: Date?
  ) async throws -> URL

  /// `.dvt` 바이트를 열어 내용을 복원한다. 실패는 `DevaultImportError` 4종으로 닫혀 온다.
  public var decryptContainer: @Sendable (
    _ data: Data,
    _ password: String
  ) async throws -> DevaultContainerPayload

  /// 들여올 항목의 (이름, 타입) 중복을 판정한다. **이름을 바꾼 뒤 다시 불러 재판정한다** — `resolutions`의 rename이 그 항목의 이름을 대신한다.
  public var judgeDuplicates: @Sendable (
    _ payload: DevaultContainerPayload,
    _ resolutions: [Int: ImportDuplicateResolution]
  ) async throws -> ImportDuplicateJudgement

  /// 선택을 반영해 실제로 들여온다. 전량-아니면-전무이며, 한도를 넘기면 `EntitlementError`가 올라온다.
  public var importSecrets: @Sendable (
    _ payload: DevaultContainerPayload,
    _ resolutions: [Int: ImportDuplicateResolution],
    _ project: ImportProjectChoice
  ) async throws -> [Secret]
}

extension ShareClient: TestDependencyKey {
  public static let testValue = ShareClient()
  public static let previewValue = ShareClient(
    authenticate: { _ in },
    exportSecrets: { _, _, _ in
      URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("preview.dvt")
    },
    decryptContainer: { _, _ in DevaultContainerPayload(secrets: []) },
    judgeDuplicates: { payload, _ in
      ImportDuplicateJudgement(totalCount: payload.secrets.count, conflicts: [])
    },
    importSecrets: { _, _, _ in [] }
  )
}

extension DependencyValues {
  public var shareClient: ShareClient {
    get { self[ShareClient.self] }
    set { self[ShareClient.self] = newValue }
  }
}
