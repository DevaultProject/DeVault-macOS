// Copyright © 2026 Devault. All rights reserved

import Foundation
import Testing

@testable import DVDomain

@Suite("ImportDuplicateJudgement — 슬롯 소모 계산")
struct ImportDuplicateJudgementTests {

    private func conflict(
        index: Int,
        target: ImportDuplicateConflict.Target = .existingSecret(id: UUID())
    ) -> ImportDuplicateConflict {
        ImportDuplicateConflict(
            index: index,
            name: "Secret \(index)",
            secretType: .apiKeyToken,
            subType: .apiKey,
            target: target
        )
    }

    @Test("충돌이 없으면 전 항목이 슬롯을 소모한다")
    func allItemsConsumeWithoutConflicts() {
        let judgement = ImportDuplicateJudgement(totalCount: 5, conflicts: [])
        #expect(judgement.slotsConsumed(by: [:]) == 5)
    }

    @Test("overwrite·skip은 슬롯을 소모하지 않고 rename은 1을 소모한다")
    func resolutionsDriveSlotConsumption() {
        let judgement = ImportDuplicateJudgement(
            totalCount: 5,
            conflicts: [conflict(index: 0), conflict(index: 1), conflict(index: 2)]
        )
        let slots = judgement.slotsConsumed(by: [
            0: .overwrite,
            1: .skip,
            2: .rename("New Name"),
        ])
        #expect(slots == 3)
    }

    @Test("선택하지 않은 충돌은 보수적으로 슬롯 1로 센다")
    func unresolvedConflictCountsAsOne() {
        let judgement = ImportDuplicateJudgement(
            totalCount: 4,
            conflicts: [conflict(index: 0), conflict(index: 1)]
        )
        #expect(judgement.slotsConsumed(by: [1: .skip]) == 3)
        #expect(judgement.slotsConsumed(by: [:]) == 4)
    }

    @Test("파일 내부 충돌(itemInFile)도 같은 계산 규칙을 따른다")
    func itemInFileConflictFollowsSameRule() {
        let judgement = ImportDuplicateJudgement(
            totalCount: 3,
            conflicts: [conflict(index: 2, target: .itemInFile(index: 0))]
        )
        #expect(judgement.slotsConsumed(by: [2: .skip]) == 2)
        #expect(judgement.slotsConsumed(by: [2: .rename("Other")]) == 3)
    }

    @Test("충돌에 없는 index의 선택은 계산에 영향을 주지 않는다")
    func unknownIndexResolutionIsIgnored() {
        let judgement = ImportDuplicateJudgement(totalCount: 3, conflicts: [conflict(index: 0)])
        #expect(judgement.slotsConsumed(by: [0: .skip, 9: .skip]) == 2)
    }

    @Test("index가 중복된 판정에서도 한 항목은 한 번만 차감한다")
    func duplicatedConflictIndexIsCountedOnce() {
        // 유일성은 계약이지만, 깨졌을 때 게이트가 느슨해지는 쪽으로 틀리면 안 된다.
        let judgement = ImportDuplicateJudgement(
            totalCount: 3,
            conflicts: [
                conflict(index: 1),
                conflict(index: 1, target: .itemInFile(index: 0)),
            ]
        )
        #expect(judgement.slotsConsumed(by: [1: .skip]) == 2)
    }

    @Test("망가진 판정이 들어와도 음수를 돌려주지 않는다")
    func neverReturnsNegative() {
        // 음수가 새면 canImportSecrets(count:)의 `existing + count <= 15`가 한도 초과 상태에서 통과한다.
        let judgement = ImportDuplicateJudgement(totalCount: 0, conflicts: [conflict(index: 0)])
        #expect(judgement.slotsConsumed(by: [0: .skip]) == 0)
    }
}
