// Copyright © 2026 Devault. All rights reserved

import Foundation

/// 필터 카드 5종과 프로젝트 행 각각의 개수를 한 번의 조회로 함께 받아온다.
public struct SecretCounts: Equatable, Sendable {

  // MARK: - Properties

  public let byFilter: [SidebarFilter: Int]
  public let byProject: [ProjectItem.ID: Int]

  // MARK: - Init

  public init(
    byFilter: [SidebarFilter: Int] = [:],
    byProject: [ProjectItem.ID: Int] = [:]
  ) {
    self.byFilter = byFilter
    self.byProject = byProject
  }

  // MARK: - Lookup

  /// 조회되지 않은 항목은 0으로 취급한다.
  /// "아직 로드 전"과 "0건"의 구분은 `LoadingState`가 담당하므로 여기서는 값만 꺼낸다.
  public func count(for filter: SidebarFilter) -> Int {
    byFilter[filter] ?? 0
  }

  public func count(forProject id: ProjectItem.ID) -> Int {
    byProject[id] ?? 0
  }
}
