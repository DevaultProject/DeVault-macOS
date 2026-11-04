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
      if let previewStore = store.scope(state: \.preview, action: \.preview) {
        ImportPreviewView(store: previewStore)
      } else if let reviewStore = store.scope(state: \.reviewDuplicates, action: \.reviewDuplicates) {
        ReviewDuplicatesView(store: reviewStore)
      }
    }
    .windowBusy(store.isExecuting)
    .alert($store.scope(state: \.alert, action: \.alert))
  }
}
