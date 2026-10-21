// Copyright © 2026 Devault. All rights reserved

import Foundation

public protocol DeleteSecretUseCase: Sendable {
    /// Secret을 소프트 삭제한다. deletedAt을 현재 시각으로 세팅하며 실제 데이터는 보존된다.
    /// - Parameter id: 삭제할 Secret의 ID
    /// - Returns: deletedAt이 설정된 Secret
    func softDelete(id: UUID) async throws -> Secret

    /// 소프트 삭제된 Secret을 복구한다. deletedAt을 nil로 되돌린다.
    ///
    /// 보유 수를 늘리므로 생성과 같은 무료 티어 한도 게이트를 지난다 — 자리가 없으면 `EntitlementError.limitReached`를 던진다.
    /// - Parameter id: 복구할 Secret의 ID
    /// - Returns: 복구된 Secret
    func restore(id: UUID) async throws -> Secret

    /// Secret을 영구 삭제한다. 복구 불가.
    /// - Parameter id: 영구 삭제할 Secret의 ID
    func permanentlyDelete(id: UUID) async throws

    /// 컬렉션에 속한 모든 Secret을 소프트 삭제한다(예: Expired 목록을 '삭제됨'으로 이동).
    /// - Parameter collection: 대상 컬렉션
    func softDeleteAll(in collection: SecretQuery.Collection) async throws

    /// 컬렉션에 속한 모든 Secret을 영구 삭제한다(예: Deleted 목록 비우기). 복구 불가.
    /// - Parameter collection: 대상 컬렉션
    func permanentlyDeleteAll(in collection: SecretQuery.Collection) async throws
}
