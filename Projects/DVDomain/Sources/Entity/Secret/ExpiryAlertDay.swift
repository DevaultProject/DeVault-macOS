// Copyright © 2026 Devault. All rights reserved

/// Secret 만료 알림을 발송할 시점입니다.
public enum ExpiryAlertDay: Int, CaseIterable, Hashable, Identifiable, Sendable {
    case thirtyDaysBefore = 30
    case sevenDaysBefore = 7
    case threeDaysBefore = 3
    case expirationDay = 0

    public var id: Int { rawValue }

    /// Settings에서 최초로 선택되는 전체 알림 시점.
    public static var defaultSelection: [ExpiryAlertDay] { allCases }
}
