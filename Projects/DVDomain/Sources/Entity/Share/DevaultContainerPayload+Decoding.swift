// Copyright © 2026 Devault. All rights reserved

import Foundation

extension DevaultContainerPayload {
    private struct SchemaVersionProbe: Decodable {
        let schemaVersion: Int
    }

    /// schemaVersion을 먼저 확인해 .corrupted와 .versionMismatch를 구분한다.
    public static func decodingSupportedSchemaVersion(from data: Data) throws -> DevaultContainerPayload {
        guard let probe = try? JSONDecoder().decode(SchemaVersionProbe.self, from: data) else {
            throw DevaultImportError.corrupted
        }
        guard probe.schemaVersion <= currentSchemaVersion else {
            throw DevaultImportError.versionMismatch
        }
        guard let payload = try? JSONDecoder().decode(DevaultContainerPayload.self, from: data) else {
            throw DevaultImportError.corrupted
        }
        return payload
    }
}
