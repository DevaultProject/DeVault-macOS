// Copyright © 2026 Devault. All rights reserved

import Foundation

/// 짧은 시간 안에 반복되는 접근을 비정상으로 판단하는 슬라이딩 윈도 카운터입니다.
/// `Date`(벽시계)는 NTP 보정·DST로 시각이 튈 수 있어, 단조 증가하는 `ContinuousClock.Instant` 사용
public final class AbnormalAccessMonitor: @unchecked Sendable {
    private let window: Duration
    private let threshold: Int
    private let lock = NSLock()
    private var timestamps: [ContinuousClock.Instant] = []

    /// - Parameters:
    ///   - window: 반복 여부를 판단할 시간 범위
    ///   - threshold: 이 윈도 안에서 몇 번째 접근부터 비정상으로 볼지
    public init(window: Duration, threshold: Int) {
        self.window = window
        self.threshold = threshold
    }

    /// 이번 접근 기록으로 윈도 내 횟수가 임계값에 도달했다면 `true`를 반환하고
    /// 내부 기록을 리셋한다(다음 알림까진 다시 threshold회가 필요 — 알림 스팸 방지).
    /// - Parameter instant: 접근이 발생한 시각
    /// - Returns: 이번 기록으로 임계값에 도달했는지 여부
    @discardableResult
    public func recordAccess(at instant: ContinuousClock.Instant) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        timestamps.removeAll { $0.duration(to: instant) > window }
        timestamps.append(instant)

        guard timestamps.count >= threshold else { return false }
        timestamps.removeAll()
        return true
    }
}
