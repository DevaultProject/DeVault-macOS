// Copyright © 2026 Devault. All rights reserved

import Foundation

enum SecretUseCaseHelper {
    /// Secret 초안의 이름을 정규화하고, expiresAt이 있으면 그 날의 23:59:59로 고정한 초안을 반환합니다.
    static func normalizedDraft(_ draft: SecretDraft) throws -> SecretDraft {
        var normalized = draft
        normalized.name = try Self.normalizedName(draft.name)
        normalized.expiresAt = normalized.expiresAt.map(Self.endOfDay)
        return normalized
    }

    /// 변경 요청의 이름과 만료일을 생성 경로(``normalizedDraft(_:)``)와 같은 규칙으로 정규화합니다.
    /// `.unchanged`인 필드는 건드리지 않습니다.
    ///
    /// 두 경로가 갈리면 사용자가 같은 날짜를 골라도 **생성한 시크릿과 수정한 시크릿의 만료 시각이 달라져**,
    /// 만료 임박 표기와 Expired 컬렉션 판정이 하루씩 어긋납니다.
    static func normalizedPatch(_ patch: SecretPatch) throws -> SecretPatch {
        var normalized = patch

        if case .set(let rawName) = normalized.name {
            normalized.name = .set(try Self.normalizedName(rawName))
        }

        // `.set(nil)`은 만료일을 지우는 요청이므로 그대로 둡니다.
        if case .set(let expiresAt?) = normalized.expiresAt {
            normalized.expiresAt = .set(Self.endOfDay(expiresAt))
        }

        return normalized
    }

    /// 생성·수정이 공유하는 이름 규칙. 앞뒤 공백을 제거하고, 남는 것이 없으면 거부합니다.
    private static func normalizedName(_ rawName: String) throws -> String {
        guard let name = comparableName(rawName) else { throw SecretUseCaseError.invalidName }
        return name
    }

    /// 중복 검사가 쓰는 이름. 저장과 같은 trim 규칙을 거쳐야 "저장은 됐는데 중복 검사는 통과"하는 틈이 안 생깁니다. 빈 이름에 던지지 않는 것은 타이핑 도중에도 불리기 때문입니다 — 아직 비교할 것이 없는 상태이지 오류가 아닙니다.
    static func comparableName(_ rawName: String) -> String? {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? nil : name
    }

    private static func endOfDay(_ date: Date) -> Date {
        Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: date) ?? date
    }

    /// patch에 updatedAt이 없으면 전달받은 시각으로 채웁니다.
    static func settingUpdatedAtIfNeeded(_ patch: SecretPatch, now: Date) -> SecretPatch {
        var next = patch
        if case .unchanged = next.updatedAt {
            next.updatedAt = .set(now)
        }
        return next
    }
}
