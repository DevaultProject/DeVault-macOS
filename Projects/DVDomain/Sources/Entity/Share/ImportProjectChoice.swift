// Copyright © 2026 Devault. All rights reserved

import Foundation

/// 들여온 시크릿을 어느 Project에 연결할지에 대한 선택. `.dvt`는 이름 하나만 담으므로(M:N 정보는 export에서 버려진다) 연결 대상은 받는 쪽이 정한다.
public enum ImportProjectChoice: Equatable, Sendable {
    /// 어느 Project에도 연결하지 않는다.
    case none
    /// 이미 있는 Project에 연결한다.
    case existing(id: UUID)
    /// 새 Project를 만들어 연결한다 — ``EntitlementUseCase/canCreateProject()`` 게이트를 지난다. Project 이름은 유니크하므로 같은 이름이 이미 있으면 생성이 거부된다. 화면이 ``existing(id:)``으로 바꿔 제안해야 사용자가 막히지 않는다.
    case create(name: String)
}
