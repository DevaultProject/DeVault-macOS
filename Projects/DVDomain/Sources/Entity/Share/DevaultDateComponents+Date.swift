// Copyright © 2026 Devault. All rights reserved

import Foundation

extension DevaultDateComponents {
    public init(date: Date, calendar: Calendar = .current) {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        self.init(
            year: components.year ?? 1970,
            month: components.month ?? 1,
            day: components.day ?? 1
        )
    }

    /// 수신 측 `Calendar.current`로 그 날 23:59:59를 복원한다 — 만료는 "그 날이 끝날 때"로 취급한다.
    public func endOfDay(calendar: Calendar = .current) -> Date? {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = 23
        components.minute = 59
        components.second = 59
        return calendar.date(from: components)
    }
}
