// Copyright © 2026 Devault. All rights reserved

import Foundation

/// Project 이름 규칙의 단일 소스 (대소문자 무시) — 저장소의 유일성 검사와 비교 키가 어긋나면 합류로 판정하고도 저장이 거부된다.
public enum ProjectNameRule {

    public static func normalized(_ rawName: String) -> String? {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? nil : name
    }

    public static func comparisonKey(_ rawName: String) -> String? {
        normalized(rawName)?.lowercased()
    }
}
