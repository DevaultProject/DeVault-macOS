// Copyright © 2026 Devault. All rights reserved

import ComposableArchitecture
import DVDomain
import DVPresentation

extension ShareClient: @retroactive DependencyKey {
    public static let liveValue: ShareClient = ShareClient(
        // 반드시 공유 싱글턴을 거친다 — 화면마다 인증 UseCase를 따로 만들면 비정상 접근 카운터가 쪼개져 반복 실패를 감지하지 못한다.
        authenticate: { try await LiveUseCases.authenticate.authenticate(reason: $0) },
        exportSecrets: { secretIDs, password, expiresAt in
            try await LiveUseCases.exportSecrets.execute(
                secretIDs: secretIDs,
                // 비밀번호는 입력 필드에서 String으로 오고, 도메인 경계인 여기서부터 감싼다.
                password: SensitiveString(password),
                expiresAt: expiresAt
            )
        },
        decryptContainer: { data, password in
            try await LiveUseCases.importSecrets.decrypt(data: data, password: SensitiveString(password))
        },
        judgeDuplicates: { payload, resolutions in
            try await LiveUseCases.importSecrets.judgeDuplicates(payload: payload, resolutions: resolutions)
        },
        importSecrets: { payload, resolutions, project in
            try await LiveUseCases.importSecrets.execute(
                payload: payload,
                resolutions: resolutions,
                project: project
            )
        }
    )
}
