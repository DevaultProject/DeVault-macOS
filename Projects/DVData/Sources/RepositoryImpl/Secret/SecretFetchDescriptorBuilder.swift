// Copyright © 2026 Devault. All rights reserved

import Foundation
import SwiftData

import DVDomain

enum SecretFetchDescriptorBuilder {
    static func make(from query: SecretQuery) -> FetchDescriptor<SwiftDataModel.Secret> {
        var descriptor = FetchDescriptor<SwiftDataModel.Secret>(
            predicate: predicate(from: query),
            sortBy: sortDescriptors(from: query.sort)
        )
        descriptor.includePendingChanges = true
        return descriptor
    }

    /// 정렬은 개수에 영향이 없으므로 생략한다. `fetch` 경로는 SwiftData predicate를 통과한 뒤
    /// `InMemorySecretQueryFilter`가 만료 항목을 한 번 더 걸러내지만, 개수 집계는 엔티티를 메모리로
    /// 올리지 않으므로 그 규칙을 predicate에 직접 넣어야 목록에 보이는 개수와 수치가 일치한다.
    /// (규칙 원본: `InMemorySecretQueryFilter.matchesExpiry`)
    ///
    /// `searchText`는 반영하지 않는다 — 사이드바 카운트는 검색어와 무관한 전체 개수를 보여준다.
    static func makeCountDescriptor(
        from query: SecretQuery,
        referenceDate: Date
    ) -> FetchDescriptor<SwiftDataModel.Secret> {
        var descriptor = FetchDescriptor<SwiftDataModel.Secret>(
            predicate: countPredicate(from: query, referenceDate: referenceDate)
        )
        descriptor.includePendingChanges = true
        return descriptor
    }

    /// 컬렉션·검색·만료 조건을 일절 걸지 않는다. 무료 티어 한도 계산 전용이다 — `makeCountDescriptor`는
    /// 사이드바 배지용이라 `.all`에 만료 조건이 붙어 있어, 한도 계산에 쓰면 만료된 Secret만큼 적게 세어진다.
    static func makeTotalCountExcludingTrashDescriptor() -> FetchDescriptor<SwiftDataModel.Secret> {
        var descriptor = FetchDescriptor<SwiftDataModel.Secret>(
            predicate: #Predicate<SwiftDataModel.Secret> { $0.deletedAt == nil }
        )
        descriptor.includePendingChanges = true
        return descriptor
    }

    /// `.all`/`.liked`만 만료 조건을 추가하고, 나머지는 목록용 predicate를 그대로 쓴다. 만료일이 없는
    /// Secret은 "만료되지 않음"으로 취급해야 하는데, `#Predicate` 안에서는 강제 언래핑을 쓸 수 없다
    /// (SwiftData가 SQL로 번역하지 못해 fetch 시점에 실패한다). `?? .distantFuture`로 대체한다.
    private static func countPredicate(
        from query: SecretQuery,
        referenceDate: Date
    ) -> Predicate<SwiftDataModel.Secret> {
        let neverExpires = Date.distantFuture
        let hasSecretType = query.secretType != nil
        let secretType = query.secretType?.rawValue ?? ""
        let hasService = !(query.service?.isEmpty ?? true)
        let service = query.service ?? ""
        let hasEnvironment = !(query.environment?.isEmpty ?? true)
        let environment = query.environment ?? ""

        switch query.collection {
        case .all:
            return #Predicate<SwiftDataModel.Secret> { secret in
                secret.deletedAt == nil &&
                (secret.expiresAt ?? neverExpires) >= referenceDate &&
                (!hasSecretType || secret.secretType == secretType) &&
                (!hasService || secret.service == service) &&
                (!hasEnvironment || secret.environment == environment)
            }
        case .liked:
            return #Predicate<SwiftDataModel.Secret> { secret in
                secret.deletedAt == nil &&
                secret.liked &&
                (secret.expiresAt ?? neverExpires) >= referenceDate &&
                (!hasSecretType || secret.secretType == secretType) &&
                (!hasService || secret.service == service) &&
                (!hasEnvironment || secret.environment == environment)
            }
        case .notice, .expired, .deleted, .project:
            return predicate(from: query)
        }
    }

    private static func predicate(from query: SecretQuery) -> Predicate<SwiftDataModel.Secret> {
        let hasSecretType = query.secretType != nil
        let secretType = query.secretType?.rawValue ?? ""
        let hasService = !(query.service?.isEmpty ?? true)
        let service = query.service ?? ""
        let hasEnvironment = !(query.environment?.isEmpty ?? true)
        let environment = query.environment ?? ""

        switch query.collection {
        case .all:
            return #Predicate<SwiftDataModel.Secret> { secret in
                secret.deletedAt == nil &&
                (!hasSecretType || secret.secretType == secretType) &&
                (!hasService || secret.service == service) &&
                (!hasEnvironment || secret.environment == environment)
            }
        case .liked:
            return #Predicate<SwiftDataModel.Secret> { secret in
                secret.deletedAt == nil &&
                secret.liked &&
                (!hasSecretType || secret.secretType == secretType) &&
                (!hasService || secret.service == service) &&
                (!hasEnvironment || secret.environment == environment)
            }
        case let .notice(referenceDate):
            // 이미 지났거나(< referenceDate) window를 벗어난(> windowEnd) 것은 제외한다.
            // 만료일이 없는 Secret은 `.distantFuture`로 치환되어 두 조건 다 자연히 걸러진다.
            let neverExpires = Date.distantFuture
            let windowEnd = SecretQuery.Collection.noticeWindowEnd(from: referenceDate)
            return #Predicate<SwiftDataModel.Secret> { secret in
                secret.deletedAt == nil &&
                (secret.expiresAt ?? neverExpires) >= referenceDate &&
                (secret.expiresAt ?? neverExpires) <= windowEnd &&
                (!hasSecretType || secret.secretType == secretType) &&
                (!hasService || secret.service == service) &&
                (!hasEnvironment || secret.environment == environment)
            }
        case let .expired(referenceDate):
            // 만료일이 없으면 `.distantFuture`로 치환 — referenceDate보다 항상 크므로 자연히 제외된다.
            // (강제 언래핑은 SwiftData가 SQL로 번역하지 못해 fetch 시점에 실패한다)
            let neverExpires = Date.distantFuture
            return #Predicate<SwiftDataModel.Secret> { secret in
                secret.deletedAt == nil &&
                (secret.expiresAt ?? neverExpires) < referenceDate &&
                (!hasSecretType || secret.secretType == secretType) &&
                (!hasService || secret.service == service) &&
                (!hasEnvironment || secret.environment == environment)
            }
        case .deleted:
            return #Predicate<SwiftDataModel.Secret> { secret in
                secret.deletedAt != nil &&
                (!hasSecretType || secret.secretType == secretType) &&
                (!hasService || secret.service == service) &&
                (!hasEnvironment || secret.environment == environment)
            }
        case let .project(projectID):
            return #Predicate<SwiftDataModel.Secret> { secret in
                secret.deletedAt == nil &&
                secret.projectLinks?.contains { link in
                    link.projectID == projectID
                } == true &&
                (!hasSecretType || secret.secretType == secretType) &&
                (!hasService || secret.service == service) &&
                (!hasEnvironment || secret.environment == environment)
            }
        }
    }

    /// 만료일(`.expiry`) 정렬에서 `nil`이 방향과 무관하게 뒤로 가야 하는 요구사항은
    /// SwiftData `SortDescriptor`(옵셔널을 `nil < .some`으로만 비교) 하나로는 표현할 수 없다.
    /// 여기서는 SwiftData가 다룰 수 있는 만큼만 정렬하고, `InMemorySecretQueryFilter`가
    /// nil을 뒤로 보내는 후처리를 맡는다.
    private static func sortDescriptors(
        from sort: SecretQuery.Sort
    ) -> [SortDescriptor<SwiftDataModel.Secret>] {
        let order: SortOrder = sort.direction == .ascending ? .forward : .reverse
        switch sort.key {
        case .time:
            return [SortDescriptor(\.updatedAt, order: order)]
        case .expiry:
            return [
                SortDescriptor(\.expiresAt, order: order),
                SortDescriptor(\.updatedAt, order: .reverse),
            ]
        case .name:
            return [
                SortDescriptor(\.name, order: order),
                SortDescriptor(\.updatedAt, order: .reverse),
            ]
        }
    }
}
