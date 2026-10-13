// Copyright © 2026 Devault. All rights reserved

public enum PasswordKeyDerivationError: Error, Equatable, Sendable {
    case invalidParameters
    case derivationFailed(code: Int32)
}
