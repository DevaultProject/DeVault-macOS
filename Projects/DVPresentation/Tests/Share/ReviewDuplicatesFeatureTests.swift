// Copyright © 2026 Devault. All rights reserved

import ComposableArchitecture
import DVDomain
import Foundation
import Testing

@testable import DVPresentation

@MainActor
@Suite("ReviewDuplicatesFeature")
struct ReviewDuplicatesFeatureTests {

  private func makeJudgement() -> ImportDuplicateJudgement {
    ImportDuplicateJudgement(
      totalCount: 3,
      conflicts: [
        ImportDuplicateConflict(
          index: 0,
          name: "GitHub Token",
          secretType: .apiKeyToken,
          subType: .accessToken,
          target: .existingSecret(id: UUID())
        ),
        ImportDuplicateConflict(
          index: 1,
          name: "Staging DB",
          secretType: .database,
          subType: nil,
          target: .itemInFile(index: 0)
        )
      ]
    )
  }

  @Test("초기 선택은 첫 번째 충돌이다 — 마스터·디테일 레이아웃의 오른쪽 패널 기본값")
  func initialSelectionIsFirstConflict() async {
    let store = TestStore(initialState: ReviewDuplicatesFeature.State(judgement: makeJudgement())) {
      ReviewDuplicatesFeature()
    }

    #expect(store.state.selectedConflictIndex == 0)
    #expect(store.state.selectedConflict?.name == "GitHub Token")
  }

  @Test("didSelectConflict는 오른쪽 액션 패널 대상을 바꾼다")
  func selectConflictSwitchesDetailPanel() async {
    let store = TestStore(initialState: ReviewDuplicatesFeature.State(judgement: makeJudgement())) {
      ReviewDuplicatesFeature()
    }

    await store.send(.didSelectConflict(index: 1)) { $0.selectedConflictIndex = 1 }
    #expect(store.state.selectedConflict?.name == "Staging DB")
  }

  @Test("선택 없으면 didTapContinue는 아무 것도 하지 않는다")
  func continueBlockedUntilAllResolved() async {
    let store = TestStore(initialState: ReviewDuplicatesFeature.State(judgement: makeJudgement())) {
      ReviewDuplicatesFeature()
    }

    #expect(!store.state.canContinue)
    await store.send(.didTapContinue)
  }

  @Test("모두 선택하면 resolved delegate로 알린다")
  func continueSendsResolvedWhenAllResolved() async {
    let store = TestStore(initialState: ReviewDuplicatesFeature.State(judgement: makeJudgement())) {
      ReviewDuplicatesFeature()
    }

    await store.send(.didSelectOverwrite(index: 0)) { $0.resolutions[0] = .overwrite }
    await store.send(.didSelectSkip(index: 1)) { $0.resolutions[1] = .skip }
    #expect(store.state.canContinue)

    await store.send(.didTapContinue)
    await store.receive(.delegate(.resolved([0: .overwrite, 1: .skip])))
  }

  @Test("Rename 선택 후 빈 이름이면 canContinue가 false다")
  func renameWithBlankNameBlocksContinue() async {
    let store = TestStore(initialState: ReviewDuplicatesFeature.State(judgement: makeJudgement())) {
      ReviewDuplicatesFeature()
    }

    await store.send(.didSelectOverwrite(index: 0)) { $0.resolutions[0] = .overwrite }
    await store.send(.didSelectRename(index: 1)) { $0.resolutions[1] = .rename("Staging DB (1)") }
    await store.send(.didChangeRenameText(index: 1, text: "   ")) { $0.resolutions[1] = .rename("   ") }

    #expect(!store.state.canContinue)
  }

  @Test("Rename을 고르면 원래 이름 뒤에 (1)을 붙인 이름이 기본값이다")
  func renameDefaultsToNumberedName() async {
    let store = TestStore(initialState: ReviewDuplicatesFeature.State(judgement: makeJudgement())) {
      ReviewDuplicatesFeature()
    }

    await store.send(.didSelectRename(index: 0)) { $0.resolutions[0] = .rename("GitHub Token (1)") }
  }

  @Test("다른 rename 항목이 이미 쓰는 번호는 건너뛴다")
  func renameDefaultSkipsNumbersTakenByOtherRenames() async {
    let judgement = ImportDuplicateJudgement(
      totalCount: 2,
      conflicts: [
        ImportDuplicateConflict(index: 0, name: "Key", secretType: .apiKeyToken, subType: .apiKey, target: .existingSecret(id: UUID())),
        ImportDuplicateConflict(index: 1, name: "Key", secretType: .apiKeyToken, subType: .apiKey, target: .itemInFile(index: 0)),
      ]
    )
    let store = TestStore(initialState: ReviewDuplicatesFeature.State(judgement: judgement)) {
      ReviewDuplicatesFeature()
    }

    await store.send(.didSelectRename(index: 0)) { $0.resolutions[0] = .rename("Key (1)") }
    await store.send(.didSelectRename(index: 1)) { $0.resolutions[1] = .rename("Key (2)") }
  }

  @Test("renameConflictsFound는 충돌 칸을 표시하고 첫 충돌 칸으로 옮겨 흔든다")
  func renameConflictsFoundMarksSelectsAndShakes() async {
    let store = TestStore(initialState: ReviewDuplicatesFeature.State(judgement: makeJudgement())) {
      ReviewDuplicatesFeature()
    }

    await store.send(.renameConflictsFound([1])) {
      $0.renameConflicts = [1]
      $0.selectedConflictIndex = 1
      $0.shakeCount = 1
    }
  }

  @Test("이름을 고치거나 다른 선택을 하면 그 칸의 충돌 표시가 풀린다")
  func editingOrSwitchingClearsRenameConflict() async {
    var initial = ReviewDuplicatesFeature.State(judgement: makeJudgement())
    initial.resolutions = [0: .rename("A"), 1: .rename("B")]
    initial.renameConflicts = [0, 1]
    let store = TestStore(initialState: initial) {
      ReviewDuplicatesFeature()
    }

    await store.send(.didChangeRenameText(index: 0, text: "A2")) {
      $0.resolutions[0] = .rename("A2")
      $0.renameConflicts = [1]
    }
    await store.send(.didSelectSkip(index: 1)) {
      $0.resolutions[1] = .skip
      $0.renameConflicts = []
    }
  }

  @Test("slotsConsumed — skip은 슬롯을 안 쓰고 rename은 쓴다")
  func importCountReflectsSlotUsage() async {
    let store = TestStore(initialState: ReviewDuplicatesFeature.State(judgement: makeJudgement())) {
      ReviewDuplicatesFeature()
    }

    await store.send(.didSelectOverwrite(index: 0)) { $0.resolutions[0] = .overwrite }
    await store.send(.didSelectSkip(index: 1)) { $0.resolutions[1] = .skip }

    #expect(store.state.importCount == 1)
  }

  @Test("didTapCancel은 cancelled delegate로 알린다")
  func cancelSendsDelegate() async {
    let store = TestStore(initialState: ReviewDuplicatesFeature.State(judgement: makeJudgement())) {
      ReviewDuplicatesFeature()
    }

    await store.send(.didTapCancel)
    await store.receive(.delegate(.cancelled))
  }
}
