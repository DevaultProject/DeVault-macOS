// Copyright © 2026 Devault. All rights reserved

import Foundation

public struct DevaultContainerFile: Equatable, Sendable {
    public var header: DevaultContainerHeader
    public var ciphertext: Data

    public init(
        header: DevaultContainerHeader,
        ciphertext: Data
    ) {
        self.header = header
        self.ciphertext = ciphertext
    }
}
