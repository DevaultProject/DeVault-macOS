// Copyright © 2026 Devault. All rights reserved

import DVDomain
import Foundation

/// Create/Edit/Detail 세 화면이 공유하는 폼 VO.
/// Common 필드는 struct 최상위에 두고, type-specific 필드는 `content` enum의 각 case에 담아
/// subType 스위칭 시 case 교체로 이전 subType 값이 자동 clear되도록 한다.
/// SwiftUI 바인딩 편의를 위해 `""`·`nil`·기본 enum을 자유롭게 허용하며,
/// 실제 도메인 진입은 `toCreateSecretPayload`/`toSecretDraft`가 `Result` 반환으로 검증한다.
struct SecretMetaFields: Equatable {
    
    // MARK: - Common Fields
    
    /// 모든 secretType에서 required.
    var name: String = ""
    
    /// 연결할 Project ID 목록. 도메인·UI 모두 다중 연결을 지원한다 —
    /// `DVMultiSelectDropdown`에 선택 개수 제한이 없다.
    var projectIds: [Project.ID] = []
    
    /// 사용자가 텍스트필드에 입력한 service 값. 빈 문자열이면 저장 시 `nil`로 매핑.
    /// chip 후보는 State 최상위 `serviceCandidates`에서 관리 — 이 필드는 최종 입력 값만 유지.
    var service: String = ""

    var expireDate: Date?
    
    /// `SecretDraft.environment`에 `.rawValue`로 저장.
    var environment: SecretEnvironment = .dev
    
    var memo: String = ""
    
    // MARK: - Type-specific
    
    /// (secretType, subType) 조합별 폼 필드. subType 스위칭 시 case 교체로 이전 값 자동 clear.
    var content: SecretContentFields
    
    // MARK: - Init
    
    init(
        content: SecretContentFields,
        name: String = "",
        projectIds: [Project.ID] = [],
        service: String = "",
        expireDate: Date? = nil,
        environment: SecretEnvironment = .dev,
        memo: String = ""
    ) {
        self.content = content
        self.name = name
        self.projectIds = projectIds
        self.service = service
        self.expireDate = expireDate
        self.environment = environment
        self.memo = memo
    }
    
    // MARK: - Field identity

    /// 도메인 매핑 실패 시 어느 필드를 지목할지 식별하는 식별자. 검증 대상 필드만 포함.
    /// ``SecretFieldID``의 별칭. 기존 `SecretMetaFields.FieldID` 표기를 유지한다.
    typealias FieldID = SecretFieldID

    // MARK: - Detection helpers

    /// 감지 엔진에 전달할 주요 시크릿 값. 비어있으면 감지 생략.
    var primaryDetectionValue: String {
        switch content {
        case .apiKeyToken(let f):     return f.value
        case .oauthClient(let f):     return f.clientSecret
        case .serviceAccount(let f):  return f.credentialJSON
        case .database(let f):        return f.linkString
        case .sshKey(let f):          return f.privateKey
        case .sslTlsCertificate(let f): return f.certificate
        case .envSet(let f):          return f.envContent
        case .licenseKey(let f):      return f.licenseKey
        case .custom(let f):          return f.value
        }
    }

    /// `primaryDetectionValue`가 대응하는 FieldID — `detectedServices` 딕셔너리 키.
    var primaryDetectionFieldID: FieldID {
        switch content {
        case .apiKeyToken:          return .value
        case .oauthClient:          return .clientSecret
        case .serviceAccount:       return .credentialJSON
        case .database:             return .linkString
        case .sshKey:               return .privateKey
        case .sslTlsCertificate:    return .certificate
        case .envSet:               return .envContent
        case .licenseKey:           return .licenseKey
        case .custom:               return .value
        }
    }

    /// 감지 대상 값으로 서비스 후보와 인라인 힌트를 구한다.
    ///
    /// 생성·수정 화면이 같은 규칙을 쓰도록 한곳에 둔다. 값이 비었으면 감지 엔진을 부르지 않는다.
    /// - Parameter detect: 감지 엔진. ``DetectionClient/detect``를 넘긴다.
    /// - Returns: chip으로 띄울 후보 서비스 목록과, ``primaryDetectionFieldID``에 붙일 힌트.
    func detectServices(
        using detect: (SensitiveString) -> DetectionResult
    ) -> (candidates: [String], hints: [FieldID: String]) {
        guard !primaryDetectionValue.isEmpty else { return ([], [:]) }
        let result = detect(SensitiveString(primaryDetectionValue))
        let hints = result.candidates.first.map { [primaryDetectionFieldID: $0.service] } ?? [:]
        return (result.candidates.map(\.service), hints)
    }
}
