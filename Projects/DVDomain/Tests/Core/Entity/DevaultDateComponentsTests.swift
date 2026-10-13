// Copyright © 2026 Devault. All rights reserved

import Foundation
import Testing

@testable import DVDomain

@Suite("DevaultDateComponents")
struct DevaultDateComponentsTests {

    @Test("JSON 인코딩/디코딩 라운드트립된다")
    func roundTripsThroughJSON() throws {
        let components = DevaultDateComponents(year: 2026, month: 12, day: 31)
        let data = try JSONEncoder().encode(components)
        let decoded = try JSONDecoder().decode(DevaultDateComponents.self, from: data)
        #expect(decoded == components)
    }

    @Test("같은 연/월/일이면 시간대가 달라도 같은 성분으로 본다")
    func sameComponentsAcrossTimeZones() {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        var seoul = Calendar(identifier: .gregorian)
        seoul.timeZone = TimeZone(identifier: "Asia/Seoul")!

        let date = DateComponents(
            calendar: utc,
            year: 2026, month: 12, day: 31, hour: 12
        ).date!

        let fromUTC = DevaultDateComponents(date: date, calendar: utc)
        let fromSeoul = DevaultDateComponents(date: date, calendar: seoul)

        // 정오(UTC) 기준이라 서울(UTC+9)에서도 같은 날짜로 떨어진다 — 자정 근처라면 갈릴 수 있음(바로 이게 고치려는 버그).
        #expect(fromUTC == fromSeoul)
    }

    @Test("endOfDay는 그 날짜의 23:59:59를 복원한다")
    func endOfDayReconstructsLastSecondOfDay() {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!

        let components = DevaultDateComponents(year: 2026, month: 12, day: 31)
        let reconstructed = components.endOfDay(calendar: utc)!
        let readBack = utc.dateComponents([.year, .month, .day, .hour, .minute, .second], from: reconstructed)

        #expect(readBack.year == 2026)
        #expect(readBack.month == 12)
        #expect(readBack.day == 31)
        #expect(readBack.hour == 23)
        #expect(readBack.minute == 59)
        #expect(readBack.second == 59)
    }
}
