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
    /// 왼쪽 목록에서 지금 상세(오른쪽 액션 패널)를 보여주는 충돌 — 마스터·디테일 레이아웃.
    public internal(set) var selectedConflictIndex: Int?
    /// 계속하기에서 바꾼 이름이 또 겹친다고 확인된 rename 항목. 이름을 고치거나 다른 선택을 하면 풀린다.
    public internal(set) var renameConflicts: Set<Int> = []
    public internal(set) var shakeCount = 0

    public init(judgement: ImportDuplicateJudgement) {
      self.judgement = judgement
      self.selectedConflictIndex = judgement.conflicts.first?.index
    }

    public var selectedConflict: ImportDuplicateConflict? {
      judgement.conflicts.first { $0.index == selectedConflictIndex }
    }

    /// "N to import" 카운터 — 선택을 반영했을 때 실제로 생성될 시크릿 수.
    public var importCount: Int {
      judgement.slotsConsumed(by: resolutions)
    }

    /// "M skipped" 카운터.
    public var skippedCount: Int {
      resolutions.values.count { $0 == .skip }
    }

    /// 모든 충돌에 선택이 있어야 계속할 수 있다 — 빈 이름 rename은 화면이 먼저 막는다.
    public var canContinue: Bool {
      judgement.conflicts.allSatisfy { conflict in
        switch resolutions[conflict.index] {
        case .rename(let name):
          return SecretNameRule.normalized(name) != nil
        case .overwrite, .skip:
          return true
        case nil:
          return false
        }
      }
    }

    /// 원래 이름 뒤에 ` (n)`을 붙인 기본 이름. 같은 파일에서 다른 rename 항목이 이미 쓰는 번호는 건너뛴다.
    /// 금고에 이미 있는 이름과 겹치는지는 계속하기에서 확인한다.
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
  }

  // MARK: - Action

  public enum Action: Equatable {

    // MARK: - View

    case didSelectConflict(index: Int)
    case didSelectOverwrite(index: Int)
    case didSelectSkip(index: Int)
    case didSelectRename(index: Int)
    case didChangeRenameText(index: Int, text: String)
    case didTapContinue
    case didTapCancel

    // MARK: - Internal

    case renameConflictsFound(Set<Int>)

    // MARK: - Delegate

    case delegate(Delegate)

    public enum Delegate: Equatable {
      case resolved([Int: ImportDuplicateResolution])
      case cancelled
    }
  }

  // MARK: - Init

  public init() {}

  // MARK: - Body

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case let .didSelectConflict(index):
        state.selectedConflictIndex = index
        return .none

      case let .didSelectOverwrite(index):
        state.resolutions[index] = .overwrite
        state.renameConflicts.remove(index)
        return .none

      case let .didSelectSkip(index):
        state.resolutions[index] = .skip
        state.renameConflicts.remove(index)
        return .none

      case let .didSelectRename(index):
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

      case let .renameConflictsFound(indices):
        state.renameConflicts = indices
        // 고칠 칸으로 옮겨 흔든다 — 목록 순서상 첫 번째 칸이다.
        if let first = state.judgement.conflicts.first(where: { indices.contains($0.index) }) {
          state.selectedConflictIndex = first.index
        }
        state.shakeCount += 1
        return .none

      case .didTapContinue:
        guard state.canContinue else { return .none }
        return .send(.delegate(.resolved(state.resolutions)))

      case .didTapCancel:
        return .send(.delegate(.cancelled))

      case .delegate:
        return .none
      }
    }
  }
}
