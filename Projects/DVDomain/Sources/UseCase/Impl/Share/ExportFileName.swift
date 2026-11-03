// Copyright © 2026 Devault. All rights reserved

import Foundation

/// Export한 `.dvt`의 파일 이름. Import Preview의 분기(시크릿 1개 → 프로젝트 → 그 외)와 같은 순서로 정한다.
enum ExportFileName {

    static let fileExtension = "dvt"

    private static let fallbackName = "DeVault"
    private static let forbiddenCharacters: Set<Character> = ["/", ":", "\\"]
    /// 파일 시스템의 255바이트 한도에서 확장자와 여유를 남긴다.
    private static let maxBaseNameByteCount = 200

    static func make(
        secretNames: [String],
        projectName: String?,
        now: Date,
        calendar: Calendar = .current
    ) -> String {
        let base: String
        if secretNames.count == 1 {
            base = sanitized(secretNames[0])
        } else if let projectName {
            base = sanitized(projectName)
        } else {
            base = "\(fallbackName) \(timestamp(now, calendar: calendar))"
        }
        return "\(base.isEmpty ? fallbackName : base).\(fileExtension)"
    }

    private static func sanitized(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        var replaced = String(trimmed.map { character -> Character in
            let isControl = character.unicodeScalars.contains { CharacterSet.controlCharacters.contains($0) }
            return forbiddenCharacters.contains(character) || isControl ? "-" : character
        })
        while replaced.hasPrefix(".") { replaced.removeFirst() }
        return truncated(replaced.trimmingCharacters(in: .whitespaces))
    }

    /// 글자 중간에서 끊지 않도록 글자 단위로 바이트를 센다.
    private static func truncated(_ name: String) -> String {
        var result = ""
        var byteCount = 0
        for character in name {
            let size = String(character).utf8.count
            if byteCount + size > maxBaseNameByteCount { break }
            result.append(character)
            byteCount += size
        }
        return result.trimmingCharacters(in: .whitespaces)
    }

    /// (`2024-04-24 14.22.18`)과 같은 모양 — 파일 이름에는 `:`를 못 써서 시각을 점으로 나눈다.
    private static func timestamp(_ date: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        return String(
            format: "%04ld-%02ld-%02ld %02ld.%02ld",
            parts.year ?? 0, parts.month ?? 0, parts.day ?? 0, parts.hour ?? 0, parts.minute ?? 0
        )
    }
}
