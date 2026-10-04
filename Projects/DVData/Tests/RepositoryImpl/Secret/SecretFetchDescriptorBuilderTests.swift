// Copyright © 2026 Devault. All rights reserved

import Foundation
import SwiftData
import Testing

import DVDomain

@testable import DVData

/// `.notice` predicate를 실제 in-memory `ModelContainer`로 fetch까지 실행해 검증한다.
@Suite("SecretFetchDescriptorBuilder")
struct SecretFetchDescriptorBuilderTests {
    private static let referenceDate = Date(timeIntervalSince1970: 1_800_000_000)

    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: Schema.appSchema,
            configurations: .init(isStoredInMemoryOnly: true)
        )
    }

    @discardableResult
    private func insertSecret(
        in context: ModelContext,
        name: String,
        secretType: String = "apiKeyToken",
        expiresAt: Date?,
        deletedAt: Date? = nil
    ) -> SwiftDataModel.Secret {
        let secret = SwiftDataModel.Secret(
            name: name,
            secretType: secretType,
            expiresAt: expiresAt,
            deletedAt: deletedAt
        )
        context.insert(secret)
        return secret
    }

    @Test(".notice predicate는 실제 ModelContainer에서 fetch 시점 오류 없이 실행된다")
    func noticePredicateExecutesAgainstRealModelContainer() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let referenceDate = Self.referenceDate

        insertSecret(in: context, name: "이미 만료", expiresAt: referenceDate.addingTimeInterval(-86_400))
        insertSecret(in: context, name: "정각 만료", expiresAt: referenceDate)
        insertSecret(in: context, name: "3일 후", expiresAt: referenceDate.addingTimeInterval(3 * 86_400))
        insertSecret(in: context, name: "정각 7일 후", expiresAt: SecretQuery.Collection.noticeWindowEnd(from: referenceDate))
        insertSecret(in: context, name: "10일 후", expiresAt: referenceDate.addingTimeInterval(10 * 86_400))
        insertSecret(in: context, name: "만료일 없음", expiresAt: nil)
        insertSecret(
            in: context,
            name: "삭제됨",
            expiresAt: referenceDate.addingTimeInterval(3 * 86_400),
            deletedAt: referenceDate
        )
        try context.save()

        let query = SecretQuery(collection: .notice(referenceDate: referenceDate))
        let descriptor = SecretFetchDescriptorBuilder.make(from: query)
        let fetched = try context.fetch(descriptor)

        let names = Set(fetched.map(\.name))
        #expect(names == ["정각 만료", "3일 후", "정각 7일 후"])
    }

    // MARK: - 중복 이름 검사

    @Test("중복 이름 descriptor는 휴지통·다른 타입·대소문자가 다른 이름을 세지 않는다")
    func duplicateNameDescriptorNarrowsToSameTypeAndExactName() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        insertSecret(in: context, name: "AWS Key", expiresAt: nil)
        insertSecret(in: context, name: "AWS Key", secretType: "database", expiresAt: nil)
        insertSecret(in: context, name: "aws key", expiresAt: nil)
        insertSecret(in: context, name: "AWS Key", expiresAt: nil, deletedAt: Self.referenceDate)
        try context.save()

        let descriptor = SecretFetchDescriptorBuilder.makeDuplicateNameDescriptor(
            name: "AWS Key",
            secretType: .apiKeyToken,
            excludingID: nil
        )

        #expect(try context.fetchCount(descriptor) == 1)
    }

    @Test("중복 이름 descriptor는 만료된 Secret도 센다")
    func duplicateNameDescriptorCountsExpiredSecret() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        insertSecret(in: context, name: "AWS Key", expiresAt: Self.referenceDate.addingTimeInterval(-86_400))
        try context.save()

        let descriptor = SecretFetchDescriptorBuilder.makeDuplicateNameDescriptor(
            name: "AWS Key",
            secretType: .apiKeyToken,
            excludingID: nil
        )

        #expect(try context.fetchCount(descriptor) == 1)
    }

    @Test("중복 이름 descriptor는 excludingID가 가리키는 Secret만 뺀다")
    func duplicateNameDescriptorExcludesOnlyGivenID() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let editing = insertSecret(in: context, name: "AWS Key", expiresAt: nil)
        insertSecret(in: context, name: "AWS Key", expiresAt: nil)
        try context.save()

        func count(excludingID: UUID?) throws -> Int {
            try context.fetchCount(SecretFetchDescriptorBuilder.makeDuplicateNameDescriptor(
                name: "AWS Key",
                secretType: .apiKeyToken,
                excludingID: excludingID
            ))
        }

        #expect(try count(excludingID: editing.id) == 1)
        #expect(try count(excludingID: nil) == 2)
    }
}
