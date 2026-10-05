// Copyright © 2026 Devault. All rights reserved

import DVDomain
import Foundation
import SwiftUI

public enum CreatableSecretType: String, CaseIterable, Hashable {
    case apiKeyToken
    case oauth
    case database
    case sshAndCredentials
    case environmentVariableSet
    case etc
    
    /// String Catalog 룩업 대상이다.
    var displayName: LocalizedStringResource {
        switch self {
        case .apiKeyToken:            return .module("API Keys/Token")
        case .oauth:                  return .module("OAuth")
        case .database:               return .module("Database")
        case .sshAndCredentials:      return .module("SSH & Credentials")
        case .environmentVariableSet: return .module("Environment Variable Set")
        case .etc:                    return .module("Etc")
        }
    }
    
    /// 빈 배열이면 상단 서브 탭바가 표시되지 않는다.
    var availableSubTypes: [CreatableSecretSubType] {
        switch self {
        case .apiKeyToken:            return [.apiKey, .accessToken, .webhookSecret]
        case .oauth:                  return [.oauthClient, .serviceAccount]
        case .database:               return []
        case .sshAndCredentials:      return [.sshKey, .sslTlsCertificate]
        case .environmentVariableSet: return []
        case .etc:                    return [.licenseKey, .custom]
        }
    }
    
    var domainType: SecretType {
        switch self {
        case .apiKeyToken:            return .apiKeyToken
        case .oauth:                  return .oauth
        case .database:               return .database
        case .sshAndCredentials:      return .sshAndCredentials
        case .environmentVariableSet: return .environmentVariableSet
        case .etc:                    return .etc
        }
    }

    /// SecretList 아바타 폴백과 동일한 소스(`SecretType.icon`)를 쓴다.
    var icon: Image {
        domainType.icon
    }
}
