// Copyright © 2026 Devault. All rights reserved

import Foundation

/// Secret 목록 조회 범위, 필터, 검색어, 정렬 조건을 표현합니다.
public struct SecretQuery: Equatable, Sendable {
    public var collection: Collection
    public var secretType: SecretType?
    public var service: String?
    public var environment: String?
    public var searchText: String?
    public var sort: Sort

    public init(
        collection: Collection = .all,
        secretType: SecretType? = nil,
        service: String? = nil,
        environment: String? = nil,
        searchText: String? = nil,
        sort: Sort = .recentlyAdded
    ) {
        self.collection = collection
        self.secretType = secretType
        self.service = service
        self.environment = environment
        self.searchText = searchText
        self.sort = sort
    }
}

extension SecretQuery {
    /// `Hashable`인 것은 화면이 "무엇을 보고 있는지"의 정체성으로 쓰기 때문이다 —
    /// 목록 뷰가 컬렉션이 바뀔 때 내용을 새로 그리는 기준(`.id(_:)`)으로 삼는다.
    /// 연관값이 `Date`·`UUID`뿐이라 자동 합성으로 충분하다.
    public enum Collection: Equatable, Hashable, Sendable {
        case all
        case liked
        /// 아직 안 지났지만 곧 지날 것만 모은 컬렉션. Expired(30일)의 부분집합이며, 이미 지난 건 제외한다.
        case notice(referenceDate: Date)
        case expired(referenceDate: Date)
        case deleted
        case project(id: UUID)

        /// 목록 행 배지의 upcoming window와 같은 기준을 써야 사이드바 카드 숫자와 배지가 뜨는 시크릿 집합이 어긋나지 않는다.
        public static let noticeWindowDays = SecretExpiryPolicy.upcomingWindowDays

        public static func noticeWindowEnd(from referenceDate: Date) -> Date {
            referenceDate.addingTimeInterval(TimeInterval(noticeWindowDays) * 86_400)
        }
    }

    /// 정렬 기준(`key`)과 방향(`direction`)을 독립된 축으로 표현한다 — 묶인 케이스로는 "만료 내림차순" 같은 조합을 표현할 수 없었다.
    public struct Sort: Equatable, Sendable {
        public enum Key: Equatable, Sendable {
            /// `updatedAt` 기준. 목록 행에 표시되는 날짜와 같은 필드를 써야 사용자가 보는 순서와 정렬 기준이 일치한다.
            case time
            /// `expiresAt` 기준. 만료일이 없는 Secret은 방향과 무관하게 항상 뒤로 보낸다 — 소비처(정렬 구현부)의 책임.
            case expiry
            case name
        }

        public enum Direction: Equatable, Sendable {
            case ascending
            case descending
        }

        public var key: Key
        public var direction: Direction

        public init(key: Key, direction: Direction) {
            self.key = key
            self.direction = direction
        }

        /// 최근 수정 순으로 보여주는 기본 정렬.
        public static let recentlyAdded = Sort(key: .time, direction: .descending)
    }
}
