// Copyright © 2026 Devault. All rights reserved

import Foundation

extension DevaultDateComponents {
    /// `calendar` 기본값은 기기 로케일에 좌우되지 않도록 그레고리력으로 고정한다.
    public init(date: Date, calendar: Calendar = Calendar(identifier: .gregorian)) {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        // 명시 요청한 컴포넌트는 항상 채워진다.
        self.init(
            year: components.year!,
            month: components.month!,
            day: components.day!
        )
    }

    /// 그 날 23:59:59를 복원한다 — 만료는 "그 날이 끝날 때"로 취급한다.
    public func endOfDay(calendar: Calendar = Calendar(identifier: .gregorian)) -> Date? {
        let components = DateComponents(year: year, month: month, day: day, hour: 23, minute: 59, second: 59)
        return calendar.date(from: components)
    }
}
