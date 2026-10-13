// Copyright © 2026 Devault. All rights reserved

public enum SecretType: String, Codable, CaseIterable, Sendable {
    case apiKeyToken
    case oauth
    case database
    case sshAndCredentials
    case environmentVariableSet
    case etc

    public var availableSubTypes: [SecretSubType] {
        switch self {
        case .apiKeyToken:            return [.apiKey, .accessToken, .webhookSecret]
        case .oauth:                  return [.oauthClient, .serviceAccount]
        case .database:               return []
        case .sshAndCredentials:      return [.sshKey, .sslTlsCertificate]
        case .environmentVariableSet: return []
        case .etc:                    return [.licenseKey, .custom]
        }
    }
}

public enum SecretSubType: String, Codable, CaseIterable, Sendable {
    case apiKey
    case accessToken
    case webhookSecret
    case oauthClient
    case serviceAccount
    case sshKey
    case sslTlsCertificate
    case licenseKey
    case custom

    public var secretType: SecretType {
        switch self {
        case .apiKey, .accessToken, .webhookSecret: return .apiKeyToken
        case .oauthClient, .serviceAccount:         return .oauth
        case .sshKey, .sslTlsCertificate:           return .sshAndCredentials
        case .licenseKey, .custom:                  return .etc
        }
    }
}
