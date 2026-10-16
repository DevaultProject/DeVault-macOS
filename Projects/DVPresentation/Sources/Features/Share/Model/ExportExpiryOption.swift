// Copyright © 2026 Devault. All rights reserved

import Foundation

/// Export Sheet의 "Expires in" 드롭다운 옵션.
public enum ExportExpiryOption: CaseIterable, Equatable, Sendable {
  case oneDay
  case threeDays
  case sevenDays
  case thirtyDays
  case never

  /// Export 시점 기준 만료 시각. `.never`는 만료 없음(nil)을 뜻한다.
  public func expiresAt(from now: Date = .now) -> Date? {
    switch self {
    case .oneDay: return Calendar.current.date(byAdding: .day, value: 1, to: now)
    case .threeDays: return Calendar.current.date(byAdding: .day, value: 3, to: now)
    case .sevenDays: return Calendar.current.date(byAdding: .day, value: 7, to: now)
    case .thirtyDays: return Calendar.current.date(byAdding: .day, value: 30, to: now)
    case .never: return nil
    }
  }

  /// Picker에 표시할 옵션 라벨. DVPresentation 모듈의 String Catalog 룩업 대상.
  var displayName: LocalizedStringResource {
    switch self {
    case .oneDay: return .module("1 day")
    case .threeDays: return .module("3 days")
    case .sevenDays: return .module("7 days")
    case .thirtyDays: return .module("30 days")
    case .never: return .module("Never")
    }
  }
}
