// Copyright © 2026 Devault. All rights reserved

import Foundation

/// "만료가 임박했다"를 판단하는 기간 상수의 단일 소스 — 배지 표시와 Notice 탭 쿼리가 공유한다.
/// 한 곳만 바뀌면 나머지가 조용히 어긋나는 걸 막는다.
public enum SecretExpiryPolicy {

    /// 즉시 조치가 필요한 단계로 볼 기간(일).
    public static let criticalWindowDays = 3

    /// 아직 조치할 시간이 있는 예고 단계로 볼 기간(일).
    public static let upcomingWindowDays = 7
}
