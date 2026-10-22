// Copyright © 2026 Devault. All rights reserved

import SwiftUI

import DVDesign

// MARK: - ExportedFileActionsView

/// Export가 끝난 뒤 뜨는 화면. `.dvt` 임시 파일을 공유(NSSharingServicePicker)하거나
/// 원하는 위치에 저장(NSSavePanel)하는 두 경로를 제공한다.
struct ExportedFileActionsView: View {

  let file: ExportedFile
  var onDone: () -> Void

  @State private var isSavePanelPresented = false
  @State private var isSaveFailureAlertPresented = false
  /// body가 재평가될 때마다 디스크에서 다시 읽지 않도록 한 번만 로드해 둔다.
  private let document: DvtFileDocument

  init(file: ExportedFile, onDone: @escaping () -> Void) {
    self.file = file
    self.onDone = onDone
    self.document = DvtFileDocument(fileURL: file.url)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text(.module("Export Complete"))
        .dvFont(.bodyLG)
        .foregroundStyle(Color.dv(.gray900))

      Text(file.url.lastPathComponent)
        .dvFont(.bodyMD)
        .foregroundStyle(Color.dv(.gray600))

      HStack(spacing: 10) {
        Spacer()

        ShareLink(item: file.url) {
          Text(.module("Share…"))
        }
        // Share는 완료 콜백이 없어 탭한 시점에 바로 닫는다 — Save As처럼 결과를 기다리지 않는다.
        .simultaneousGesture(TapGesture().onEnded { onDone() })

        DVButton(titleText: .module("Save As…"), style: .secondary) {
          isSavePanelPresented = true
        }
      }
    }
    .padding(20)
    .frame(width: 380)
    .fileExporter(
      isPresented: $isSavePanelPresented,
      document: document,
      contentType: DvtFileDocument.dvtContentType,
      defaultFilename: file.url.deletingPathExtension().lastPathComponent
    ) { result in
      switch result {
      case .success:
        onDone()
      case .failure:
        isSaveFailureAlertPresented = true
      }
    }
    .alert(
      String.module("Couldn't save the file."),
      isPresented: $isSaveFailureAlertPresented
    ) {
      Button(String.module("OK")) {}
    } message: {
      Text(.module("Please try again in a moment."))
    }
    // Share는 탭한 즉시 시트를 닫지만, NSSharingServicePicker가 파일을 실제로 읽는 건 그 뒤다
    .onDisappear {
      try? FileManager.default.removeItem(at: file.url)
      let url = file.url
      Task {
        try? await Task.sleep(for: .seconds(10))
        try? FileManager.default.removeItem(at: url)
      }
    }
  }
}

// MARK: - Preview

#if DEBUG

#Preview {
  ExportedFileActionsView(file: ExportedFile(url: URL(fileURLWithPath: "/tmp/preview.dvt"))) {}
}

#endif
