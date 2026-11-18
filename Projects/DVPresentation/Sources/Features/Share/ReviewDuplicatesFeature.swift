// Copyright © 2026 Devault. All rights reserved

import Foundation

import ComposableArchitecture
import DVDomain

// MARK: - ReviewDuplicatesFeature

@Reducer
public struct ReviewDuplicatesFeature {

  // MARK: - State

  @ObservableState
  public struct State: Equatable {
    public let judgement: ImportDuplicateJudgement
    public internal(set) var resolutions: [Int: ImportDuplicateResolution] = [:]
    /// 지금 검토 중인 충돌 — 목록에서 선택 표시되고 오른쪽 액션 패널이 이 충돌을 보여준다.
    public internal(set) var selectedConflictIndex: Int?
    /// 바꾼 이름이 또 겹친다고 확인된 rename 항목. 이름을 고치거나 다른 선택을 하면 풀린다.
    public internal(set) var renameConflicts: Set<Int> = []
    public internal(set) var shakeCount = 0
    /// Next·Done에서 바꾼 이름을 확인하는 중. 연타로 이동이 겹치지 않게 막는다.
    public internal(set) var isChecking = false

    public init(judgement: ImportDuplicateJudgement) {
      self.judgement = judgement
      self.selectedConflictIndex = judgement.conflicts.first?.index
      // 화면의 맨 위 옵션을 기본으로 고른다.
      for conflict in judgement.conflicts {
        if conflict.target.isExistingSecret {
          resolutions[conflict.index] = .overwrite
        } else {
          resolutions[conflict.index] = .rename(suggestedRename(for: conflict.name, excluding: conflict.index))
        }
      }
    }

    public var selectedConflict: ImportDuplicateConflict? {
      judgement.conflicts.first { $0.index == selectedConflictIndex }
    }

    /// "N to import" 카운터 — 현재 칸까지 검토한 충돌 중 Skip하지 않은 수.
    public var importCount: Int {
      reviewedConflicts.count { resolutions[$0.index] != .skip }
    }

    /// "M skipped" 카운터 — 현재 칸까지 검토한 충돌 중 Skip한 수.
    public var skippedCount: Int {
      reviewedConflicts.count { resolutions[$0.index] == .skip }
    }

    private var currentPosition: Int? {
      judgement.conflicts.firstIndex { $0.index == selectedConflictIndex }
    }

    private var reviewedConflicts: ArraySlice<ImportDuplicateConflict> {
      guard let position = currentPosition else { return [] }
      return judgement.conflicts[...position]
    }

    public var isFirstConflict: Bool { currentPosition == 0 }

    public var isLastConflict: Bool { currentPosition == judgement.conflicts.count - 1 }

    public var canGoBack: Bool { !isFirstConflict && !isChecking }

    /// Next(마지막 칸은 Done)를 누를 수 있는지. 마지막 칸에서는 모든 충돌이 유효해야 한다.
    public var canAdvance: Bool {
      guard !isChecking else { return false }
      if isLastConflict { return canContinue }
      return selectedConflictIndex.map { Self.isValid(resolutions[$0]) } ?? false
    }

    /// 모든 충돌의 선택이 유효해야 끝낼 수 있다 — 빈 이름 rename은 화면이 먼저 막는다.
    public var canContinue: Bool {
      judgement.conflicts.allSatisfy { Self.isValid(resolutions[$0.index]) }
    }

    private static func isValid(_ resolution: ImportDuplicateResolution?) -> Bool {
      switch resolution {
      case .rename(let name):
        return SecretNameRule.normalized(name) != nil
      case .overwrite, .skip:
        return true
      case nil:
        return false
      }
    }

    /// 원래 이름 뒤에 ` (n)`을 붙인 기본 이름. 같은 파일에서 다른 rename 항목이 이미 쓰는 번호는 건너뛴다.
    /// 금고에 이미 있는 이름과 겹치는지는 Next·Done에서 확인한다.
    func suggestedRename(for originalName: String, excluding index: Int) -> String {
      let taken = Set(resolutions.compactMap { key, resolution -> String? in
        guard key != index, let name = resolution.renamedName else { return nil }
        return SecretNameRule.comparisonKey(name)
      })
      var number = 1
      while taken.contains(SecretNameRule.comparisonKey("\(originalName) (\(number))") ?? "") {
        number += 1
      }
      return "\(originalName) (\(number))"
    }

    fileprivate mutating func moveSelection(by offset: Int) {
      guard let position = currentPosition else { return }
      let target = position + offset
      guard judgement.conflicts.indices.contains(target) else { return }
      selectedConflictIndex = judgement.conflicts[target].index
    }
  }

  // MARK: - Action

  public enum Action: Equatable {

    // MARK: - View

    case didSelectOverwrite(index: Int)
    case didSelectSkip(index: Int)
    case didSelectRename(index: Int)
    case didChangeRenameText(index: Int, text: String)
    case didTapPrevious
    case didTapNext
    case didTapCancel

    // MARK: - Internal

    case renameCheckPassed
    case renameConflictsFound(Set<Int>)
    /// 확인·가져오기가 실패하거나 취소돼 이 화면에 머문다.
    case checkEnded

    // MARK: - Delegate

    case delegate(Delegate)

    public enum Delegate: Equatable {
      case resolved([Int: ImportDuplicateResolution])
      case renameCheckRequested([Int: ImportDuplicateResolution])
      case cancelled
    }
  }

  // MARK: - Init

  public init() {}

  // MARK: - Body

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case let .didSelectOverwrite(index):
        state.resolutions[index] = .overwrite
        state.renameConflicts.remove(index)
        return .none

      case let .didSelectSkip(index):
        state.resolutions[index] = .skip
        state.renameConflicts.remove(index)
        return .none

      case let .didSelectRename(index):
        // 이미 Rename이면 다시 눌러도 입력해 둔 이름을 지우지 않는다.
        if case .rename = state.resolutions[index] { return .none }
        let originalName = state.judgement.conflicts.first { $0.index == index }?.name ?? ""
        state.resolutions[index] = .rename(state.suggestedRename(for: originalName, excluding: index))
        state.renameConflicts.remove(index)
        return .none

      case let .didChangeRenameText(index, text):
        // Rename을 고른 상태에서만 텍스트를 반영한다 — 다른 선택 중에는 무시.
        guard case .rename = state.resolutions[index] else { return .none }
        state.resolutions[index] = .rename(text)
        state.renameConflicts.remove(index)
        return .none

      case .didTapPrevious:
        guard state.canGoBack else { return .none }
        state.moveSelection(by: -1)
        return .none

      case .didTapNext:
        guard state.canAdvance, let index = state.selectedConflictIndex else { return .none }
        if state.isLastConflict {
          state.isChecking = true
          return .send(.delegate(.resolved(state.resolutions)))
        }
        // 이름을 바꾼 칸만 겹치는지 확인한다 — Overwrite·Skip은 이름 충돌을 만들지 않는다.
        if case .rename = state.resolutions[index] {
          state.isChecking = true
          return .send(.delegate(.renameCheckRequested(state.resolutions)))
        }
        state.moveSelection(by: 1)
        return .none

      case .renameCheckPassed:
        state.isChecking = false
        state.moveSelection(by: 1)
        return .none

      case let .renameConflictsFound(indices):
        state.isChecking = false
        state.renameConflicts = indices
        // 고칠 칸으로 옮겨 흔든다 — 목록 순서상 첫 번째 칸이다.
        if let first = state.judgement.conflicts.first(where: { indices.contains($0.index) }) {
          state.selectedConflictIndex = first.index
        }
        state.shakeCount += 1
        return .none

      case .checkEnded:
        state.isChecking = false
        return .none

      case .didTapCancel:
        return .send(.delegate(.cancelled))

      case .delegate:
        return .none
      }
    }
  }
}

// MARK: - Target

extension ImportDuplicateConflict.Target {
  var isExistingSecret: Bool {
    if case .existingSecret = self { return true }
    return false
  }
}
