// Copyright © 2026 Devault. All rights reserved

/// `DateComponents`(18개 Optional) 대신 year/month/day 3개만 존재하게 해, 시각이 끼어들 가능성 자체를 없앤다.
public struct DevaultDateComponents: Equatable, Sendable, Codable {
    public var year: Int
    public var month: Int
    public var day: Int

    public init(
        year: Int,
        month: Int,
        day: Int
    ) {
        self.year = year
        self.month = month
        self.day = day
    }
}
