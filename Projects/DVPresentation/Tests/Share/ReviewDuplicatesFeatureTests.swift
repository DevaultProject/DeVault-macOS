// Copyright © 2026 Devault. All rights reserved

import ComposableArchitecture
import DVDomain
import Foundation
import Testing

@testable import DVPresentation

@MainActor
@Suite("ReviewDuplicatesFeature")
struct ReviewDuplicatesFeatureTests {

  /// 0: 금고와 겹침(기본 Overwrite), 1: 파일 안 중복(기본 Rename).
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

  /// 0·2: 금고와 겹침(기본 Overwrite), 1: 파일 안 중복(기본 Rename) — 가운데 칸이 Rename이다.
  private func makeThreeConflictJudgement() -> ImportDuplicateJudgement {
    ImportDuplicateJudgement(
      totalCount: 3,
      conflicts: [
        ImportDuplicateConflict(index: 0, name: "A", secretType: .apiKeyToken, subType: .apiKey, target: .existingSecret(id: UUID())),
        ImportDuplicateConflict(index: 1, name: "B", secretType: .apiKeyToken, subType: .apiKey, target: .itemInFile(index: 0)),
        ImportDuplicateConflict(index: 2, name: "C", secretType: .apiKeyToken, subType: .apiKey, target: .existingSecret(id: UUID())),
      ]
    )
  }

  private func makeStore(_ judgement: ImportDuplicateJudgement) -> TestStoreOf<ReviewDuplicatesFeature> {
    TestStore(initialState: ReviewDuplicatesFeature.State(judgement: judgement)) {
      ReviewDuplicatesFeature()
    }
  }

  // MARK: - Initial state

  @Test("초기 선택은 첫 번째 충돌이다 — 현재 검토 중인 칸")
  func initialSelectionIsFirstConflict() async {
    let store = makeStore(makeJudgement())

    #expect(store.state.selectedConflictIndex == 0)
    #expect(store.state.selectedConflict?.name == "GitHub Token")
  }

  @Test("맨 위 옵션이 미리 골라져 있다 — 금고와 겹치면 Overwrite, 파일 안 중복이면 Rename")
  func topOptionIsPreselected() async {
    let store = makeStore(makeJudgement())

    #expect(store.state.resolutions == [0: .overwrite, 1: .rename("Staging DB (1)")])
    #expect(store.state.canContinue)
  }

  // MARK: - Navigation

  @Test("Next는 선택이 유효한 칸에서 다음 칸으로 이동한다 — Overwrite·Skip은 이름 확인 없이")
  func nextMovesWithoutCheckForNonRename() async {
    let store = makeStore(makeThreeConflictJudgement())

    await store.send(.didTapNext) { $0.selectedConflictIndex = 1 }
  }

  @Test("Prev는 이전 칸으로 이동하고 첫 칸에서는 아무 것도 하지 않는다")
  func previousMovesBackAndStopsAtFirst() async {
    let store = makeStore(makeThreeConflictJudgement())

    #expect(!store.state.canGoBack)
    await store.send(.didTapPrevious)

    await store.send(.didTapNext) { $0.selectedConflictIndex = 1 }
    #expect(store.state.canGoBack)
    await store.send(.didTapPrevious) { $0.selectedConflictIndex = 0 }
  }

  @Test("Rename 칸의 Next는 이동하지 않고 이름 확인을 요청하며, 통과하면 다음 칸으로 이동한다")
  func nextOnRenameRequestsCheckThenMovesOnPass() async {
    let store = makeStore(makeThreeConflictJudgement())
    let resolutions: [Int: ImportDuplicateResolution] = [0: .overwrite, 1: .rename("B (1)"), 2: .overwrite]

    await store.send(.didTapNext) { $0.selectedConflictIndex = 1 }
    await store.send(.didTapNext) { $0.isChecking = true }
    await store.receive(.delegate(.renameCheckRequested(resolutions)))

    await store.send(.renameCheckPassed) {
      $0.isChecking = false
      $0.selectedConflictIndex = 2
    }
  }

  @Test("이름 확인 중에는 Next·Prev가 막힌다")
  func navigationBlockedWhileChecking() async {
    var initial = ReviewDuplicatesFeature.State(judgement: makeThreeConflictJudgement())
    initial.selectedConflictIndex = 1
    initial.isChecking = true
    let store = TestStore(initialState: initial) {
      ReviewDuplicatesFeature()
    }

    #expect(!store.state.canAdvance)
    #expect(!store.state.canGoBack)
    await store.send(.didTapNext)
    await store.send(.didTapPrevious)
  }

  @Test("마지막 칸의 Next(Done)는 resolved delegate로 알린다")
  func nextOnLastConflictSendsResolved() async {
    let store = makeStore(makeJudgement())

    await store.send(.didTapNext) { $0.selectedConflictIndex = 1 }
    #expect(store.state.isLastConflict)

    await store.send(.didTapNext) { $0.isChecking = true }
    await store.receive(.delegate(.resolved([0: .overwrite, 1: .rename("Staging DB (1)")])))
  }

  @Test("Rename 칸의 이름이 비어 있으면 Next·Done이 막힌다")
  func blankRenameBlocksNext() async {
    let store = makeStore(makeThreeConflictJudgement())

    await store.send(.didTapNext) { $0.selectedConflictIndex = 1 }
    await store.send(.didChangeRenameText(index: 1, text: "   ")) { $0.resolutions[1] = .rename("   ") }

    #expect(!store.state.canAdvance)
    #expect(!store.state.canContinue)
    await store.send(.didTapNext)
  }

  // MARK: - Rename

  @Test("Rename을 고르면 원래 이름 뒤에 (1)을 붙인 이름이 기본값이다")
  func renameDefaultsToNumberedName() async {
    let store = makeStore(makeJudgement())

    await store.send(.didSelectRename(index: 0)) { $0.resolutions[0] = .rename("GitHub Token (1)") }
  }

  @Test("이미 Rename이면 다시 골라도 입력해 둔 이름을 지우지 않는다")
  func reselectingRenameKeepsTypedName() async {
    let store = makeStore(makeJudgement())

    await store.send(.didChangeRenameText(index: 1, text: "My Name")) { $0.resolutions[1] = .rename("My Name") }
    await store.send(.didSelectRename(index: 1))
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
    let store = makeStore(judgement)

    // 파일 안 중복 칸이 기본으로 "Key (1)"을 이미 쓰고 있다.
    #expect(store.state.resolutions[1] == .rename("Key (1)"))
    await store.send(.didSelectRename(index: 0)) { $0.resolutions[0] = .rename("Key (2)") }
  }

  @Test("renameConflictsFound는 충돌 칸을 표시하고 첫 충돌 칸으로 옮겨 흔든다")
  func renameConflictsFoundMarksSelectsAndShakes() async {
    var initial = ReviewDuplicatesFeature.State(judgement: makeJudgement())
    initial.isChecking = true
    let store = TestStore(initialState: initial) {
      ReviewDuplicatesFeature()
    }

    await store.send(.renameConflictsFound([1])) {
      $0.isChecking = false
      $0.renameConflicts = [1]
      $0.selectedConflictIndex = 1
      $0.shakeCount = 1
    }
  }

  @Test("이름 확인이 실패하면 확인 중 상태만 푼다")
  func renameCheckFailedClearsChecking() async {
    var initial = ReviewDuplicatesFeature.State(judgement: makeJudgement())
    initial.isChecking = true
    let store = TestStore(initialState: initial) {
      ReviewDuplicatesFeature()
    }

    await store.send(.renameCheckFailed) { $0.isChecking = false }
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

  // MARK: - Counters

  @Test("카운터는 현재 칸까지 검토한 충돌만 센다 — 덮어쓰기도 가져오는 것으로 센다")
  func countersFollowReviewProgress() async {
    let store = makeStore(makeJudgement())

    // 첫 칸(기본 Overwrite)만 검토한 상태.
    #expect(store.state.importCount == 1)
    #expect(store.state.skippedCount == 0)

    await store.send(.didTapNext) { $0.selectedConflictIndex = 1 }
    #expect(store.state.importCount == 2)

    await store.send(.didSelectSkip(index: 1)) { $0.resolutions[1] = .skip }
    #expect(store.state.importCount == 1)
    #expect(store.state.skippedCount == 1)

    // 이전 칸으로 돌아가면 아직 검토하지 않은 칸은 세지 않는다.
    await store.send(.didTapPrevious) { $0.selectedConflictIndex = 0 }
    #expect(store.state.importCount == 1)
    #expect(store.state.skippedCount == 0)
  }

  @Test("didTapCancel은 cancelled delegate로 알린다")
  func cancelSendsDelegate() async {
    let store = makeStore(makeJudgement())

    await store.send(.didTapCancel)
    await store.receive(.delegate(.cancelled))
  }
}
