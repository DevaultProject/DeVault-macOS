// Copyright © 2026 Devault. All rights reserved

import Foundation

// MARK: - metadata 디코딩

extension Secret {

    /// `metadata`를 해당 타입의 content로 디코딩한다.
    ///
    /// **복호화도 인증도 거치지 않는다.** `metadataJSON`은 설계상 평문으로 저장되므로
    /// (`SecretMetadataContent` 참조) `Secret`을 손에 쥔 시점에 이미 읽을 수 있다.
    /// 암호화된 값은 `payload` 쪽이고, 그쪽만 `RevealSecretPayloadUseCase`를 거친다.
    ///
    /// 디코딩 실패는 `nil`로 삼킨다 — metadata는 부가 정보라 스키마가 어긋나도
    /// 시크릿 자체를 못 여는 것보다 해당 필드만 비는 편이 낫다.
    public func decodedMetadata<M: SecretMetadataContent>(_ type: M.Type) -> M? {
        metadata.flatMap { try? JSONDecoder().decode(M.self, from: $0.metadataJSON) }
    }
}
