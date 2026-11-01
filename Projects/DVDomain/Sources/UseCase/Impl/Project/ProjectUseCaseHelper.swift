// Copyright © 2026 Devault. All rights reserved

import Foundation

enum ProjectUseCaseHelper {
    /// Project 이름의 앞뒤 공백을 제거하고 기본 필수값을 검증합니다.
    static func normalizedName(_ name: String) throws -> String {
        guard let normalizedName = ProjectNameRule.normalized(name) else {
            throw ProjectUseCaseError.invalidName
        }
        return normalizedName
    }
}
