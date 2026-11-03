// Copyright © 2026 Devault. All rights reserved

import Foundation
import Testing

@testable import DVDomain

@Suite("ExportFileName")
struct ExportFileNameTests {

    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    private func make(_ names: [String], project: String? = nil, now: Date? = nil) -> String {
        ExportFileName.make(
            secretNames: names,
            projectName: project,
            now: now ?? date(2026, 11, 3, 15, 30),
            calendar: calendar
        )
    }

    @Test("시크릿이 하나면 그 이름을 쓴다")
    func usesSecretNameForSingleSecret() {
        #expect(make(["GitHub Token"]) == "GitHub Token.dvt")
    }

    @Test("시크릿이 하나면 프로젝트가 있어도 시크릿 이름이 우선한다")
    func singleSecretBeatsProjectName() {
        #expect(make(["GitHub Token"], project: "DrinkiG") == "GitHub Token.dvt")
    }

    @Test("여러 시크릿이 같은 프로젝트면 프로젝트 이름을 쓴다")
    func usesProjectNameForSharedProject() {
        #expect(make(["A", "B"], project: "DrinkiG") == "DrinkiG.dvt")
    }

    @Test("그 외에는 날짜와 시각을 붙인 기본 이름을 쓴다")
    func usesTimestampedNameOtherwise() {
        #expect(make(["A", "B"]) == "DeVault 2026-11-03 15.30.dvt")
    }

    @Test("기본 달력은 그레고리력이다 — 불기·연호 달력을 쓰는 지역에서도 연도가 같다")
    func defaultCalendarIsGregorian() {
        #expect(ExportFileName.localGregorianCalendar.identifier == .gregorian)
    }

    @Test("월·일·시·분이 한 자리여도 0으로 채운다")
    func padsTimestampParts() {
        #expect(make(["A", "B"], now: date(2026, 1, 5, 3, 7)) == "DeVault 2026-01-05 03.07.dvt")
    }

    @Test("경로에 쓸 수 없는 문자는 하이픈으로 바꾼다")
    func replacesForbiddenCharacters() {
        #expect(make(["a/b:c\\d"]) == "a-b-c-d.dvt")
        #expect(make(["a\tb"]) == "a-b.dvt")
    }

    @Test("앞뒤 공백과 앞의 점은 지운다 — 숨김 파일이 되지 않게")
    func trimsWhitespaceAndLeadingDots() {
        #expect(make(["  ..hidden  "]) == "hidden.dvt")
        #expect(make([". .hidden"]) == "hidden.dvt")
    }

    @Test("정리하고 남는 것이 없으면 복수 시크릿과 같은 기본 이름을 쓴다")
    func fallsBackToTimestampedNameWhenNothingRemains() {
        let expected = "DeVault 2026-11-03 15.30.dvt"

        #expect(make(["   "]) == expected)
        #expect(make(["..."]) == expected)
        #expect(make([". . ."]) == expected)
        #expect(make(["A", "B"], project: "  ") == expected)
    }

    @Test("긴 이름은 글자 중간에서 끊지 않고 200바이트 안으로 줄인다")
    func truncatesByBytesWithoutSplittingCharacters() {
        let name = make([String(repeating: "가", count: 100)])
        let base = String(name.dropLast(".dvt".count))

        #expect(base.utf8.count <= 200)
        #expect(base == String(repeating: "가", count: 66))
    }
}
