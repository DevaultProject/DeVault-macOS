// Copyright © 2026 Devault. All rights reserved

import SwiftUI

import ComposableArchitecture

// MARK: - ImportFlowView

public struct ImportFlowView: View {

  // MARK: - Properties

  @Bindable var store: StoreOf<ImportFlowFeature>

  // MARK: - Init

  public init(store: StoreOf<ImportFlowFeature>) {
    self.store = store
  }

  // MARK: - Body

  public var body: some View {
    Group {
      // preview는 reviewDuplicates로 넘어가도 살아있다(뒤로 가기 복원용) — reviewDuplicates가
      // 있으면 그게 앞선다.
      if let reviewStore = store.scope(state: \.reviewDuplicates, action: \.reviewDuplicates) {
        ReviewDuplicatesView(store: reviewStore)
      } else if let previewStore = store.scope(state: \.preview, action: \.preview) {
        ImportPreviewView(store: previewStore)
      }
    }
    .windowBusy(store.isExecuting)
    .alert($store.scope(state: \.alert, action: \.alert))
  }
}
