// Copyright © 2026 Devault. All rights reserved

import Testing
import Foundation

@testable import DVDomain

@Suite("ProjectNameRule")
struct ProjectNameRuleTests {

    @Test("앞뒤 공백과 개행을 제거한다")
    func trimsWhitespaceAndNewlines() {
        #expect(ProjectNameRule.normalized("  DrinkiG \n") == "DrinkiG")
    }

    @Test("공백뿐이거나 비어 있으면 nil이다")
    func returnsNilWhenNothingRemains() {
        #expect(ProjectNameRule.normalized("") == nil)
        #expect(ProjectNameRule.normalized(" \n\t ") == nil)
        #expect(ProjectNameRule.comparisonKey(" \n ") == nil)
    }

    @Test("대소문자만 다른 이름은 같은 비교 키를 갖는다")
    func comparisonKeyIgnoresCase() {
        #expect(ProjectNameRule.comparisonKey("DrinkiG") == ProjectNameRule.comparisonKey("drinkig"))
    }

    @Test("공백만 다른 이름도 같은 비교 키를 갖는다")
    func comparisonKeyIgnoresSurroundingWhitespace() {
        #expect(ProjectNameRule.comparisonKey(" DrinkiG ") == ProjectNameRule.comparisonKey("drinkig"))
    }

    @Test("다른 이름은 다른 비교 키를 갖는다")
    func comparisonKeyDistinguishesDifferentNames() {
        #expect(ProjectNameRule.comparisonKey("Side") != ProjectNameRule.comparisonKey("Side2"))
    }
}

@Suite("SecretNameRule")
struct SecretNameRuleTests {

    @Test("앞뒤 공백과 개행을 제거한다")
    func trimsWhitespaceAndNewlines() {
        #expect(SecretNameRule.normalized("  GitHub \n") == "GitHub")
    }

    @Test("공백뿐이거나 비어 있으면 nil이다")
    func returnsNilWhenNothingRemains() {
        #expect(SecretNameRule.normalized("") == nil)
        #expect(SecretNameRule.normalized(" \n\t ") == nil)
        #expect(SecretNameRule.comparisonKey(" \n ") == nil)
    }

    @Test("대소문자만 다른 이름은 다른 비교 키를 갖는다")
    func comparisonKeyIsCaseSensitive() {
        #expect(SecretNameRule.comparisonKey("GitHub") != SecretNameRule.comparisonKey("github"))
    }

    // 저장소 중복 쿼리가 `==`에 기대므로, 이 동치가 깨지면 쿼리도 같이 고쳐야 한다.
    @Test("비교 키는 정규화된 이름과 같다")
    func comparisonKeyEqualsNormalized() {
        for raw in ["GitHub", "  GitHub ", "git hub", "한글 이름\n", ""] {
            #expect(SecretNameRule.comparisonKey(raw) == SecretNameRule.normalized(raw))
        }
    }
}
