// Copyright © 2026 Devault. All rights reserved

import Foundation

import DVDesign
import DVDomain

/// 만료 임박 표기 정책의 단일 정의부 — 목록과 조회 화면이 함께 쓴다.
/// "이미 지난 것을 뺄지"는 소비처(`SecretListView.row(for:)`) 몫이다 — 여기서 걸러내면
/// 조회 화면도 강제로 끌려간다.
enum SecretExpiryStatus: Equatable {

    case expired

    /// 아직 안 지났고 ``criticalWindow`` 이내에 만료된다 — 즉시 조치가 필요한 단계.
    case critical

    /// ``upcomingWindow`` 이내에 만료된다 — 아직 조치할 시간이 있는 예고 단계.
    case upcoming

    /// 하루를 고정 86,400초로 계산한다 — 캘린더 일수(DST·타임존 경계)는 따지지 않는다.
    private static let secondsPerDay: TimeInterval = 86_400

    static let criticalWindow: TimeInterval = TimeInterval(SecretExpiryPolicy.criticalWindowDays) * secondsPerDay

    /// 남은 기간이 ``criticalWindow`` 초과이면서 이 값 이하면 ``upcoming``.
    /// Notice 탭(`SecretQuery.Collection.noticeWindowDays`)도 같은 값을 파생시켜 쓴다.
    static let upcomingWindow: TimeInterval = TimeInterval(SecretExpiryPolicy.upcomingWindowDays) * secondsPerDay

    /// 만료일이 없거나 ``upcomingWindow``보다 멀면 `nil`.
    init?(expiresAt: Date?, now: Date = .now) {
        guard let expiresAt else { return nil }

        if expiresAt <= now {
            self = .expired
        } else if expiresAt <= now.addingTimeInterval(Self.criticalWindow) {
            self = .critical
        } else if expiresAt <= now.addingTimeInterval(Self.upcomingWindow) {
            self = .upcoming
        } else {
            return nil
        }
    }

    /// 목록 행과 조회 필드가 이 하나를 통해 같은 아이콘·색을 얻는다.
    var emphasis: DVExpiryEmphasis {
        switch self {
        case .expired, .critical: return .danger
        case .upcoming: return .warning
        }
    }

    /// 아이콘·색만으로는 "며칠 남았는지"가 전달되지 않는다.
    var tooltipText: String {
        switch self {
        case .expired:
            return String.module("Expired")
        case .critical:
            return String.module("Expires within \(SecretExpiryPolicy.criticalWindowDays) days")
        case .upcoming:
            return String.module("Expires within \(SecretExpiryPolicy.upcomingWindowDays) days")
        }
    }
}
