// Copyright © 2026 Devault. All rights reserved

import Foundation

/// Secret 이름 규칙의 단일 소스 (대소문자를 구분)
/// 저장소 중복 쿼리(`secret.name == name`)는 이 함수를 못 부르므로, `comparisonKey == normalized`에 기대어 `==`로 맞춘다.
public enum SecretNameRule {

    public static func normalized(_ rawName: String) -> String? {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? nil : name
    }

    public static func comparisonKey(_ rawName: String) -> String? {
        normalized(rawName)
    }
}
