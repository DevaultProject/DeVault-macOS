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

    @Test("절대 시각은 기기마다 달라도, 같은 성분을 각자 복원하면 같은 날짜로 재추출된다")
    func sameComponentsSurviveRoundTripAcrossTimeZones() {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        var seoul = Calendar(identifier: .gregorian)
        seoul.timeZone = TimeZone(identifier: "Asia/Seoul")!

        let components = DevaultDateComponents(year: 2026, month: 12, day: 31)
        let utcDate = components.endOfDay(calendar: utc)!
        let seoulDate = components.endOfDay(calendar: seoul)!

        // 기기마다 복원하는 절대 시각 자체는 다르다(시간대 차이만큼).
        #expect(utcDate != seoulDate)
        // 그래도 각자 자기 시간대로 다시 추출하면 원래 날짜 그대로다 — 이게 Export/Import 양쪽이 실제로 기대는 속성.
        #expect(DevaultDateComponents(date: utcDate, calendar: utc) == components)
        #expect(DevaultDateComponents(date: seoulDate, calendar: seoul) == components)
    }

    @Test("같은 순간이라도 캘린더 체계가 다르면 연도 성분이 달라진다 — 그래서 기본값을 그레고리력에 고정해야 한다")
    func calendarSystemAffectsYearComponent() {
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = TimeZone(identifier: "UTC")!
        var buddhist = Calendar(identifier: .buddhist)
        buddhist.timeZone = TimeZone(identifier: "UTC")!

        let instant = gregorian.date(from: DateComponents(year: 2026, month: 12, day: 31))!

        let gregorianComponents = DevaultDateComponents(date: instant, calendar: gregorian)
        let buddhistComponents = DevaultDateComponents(date: instant, calendar: buddhist)

        #expect(buddhistComponents.year - gregorianComponents.year == 543)
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
