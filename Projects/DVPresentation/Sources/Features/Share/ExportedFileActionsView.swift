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
  @State private var isSharePickerPresented = false
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

        // NSSharingServicePicker의 완료 콜백(didShareItems)은 AirDrop처럼 전송에 시간이 걸리는
        // 서비스에서 오지 않거나 들쭉날쭉해서 자동으로 닫는 시점을 믿을 수 없다 — Done으로 직접 닫는다.
        DVButton(titleText: .module("Share…"), style: .secondary) {
          isSharePickerPresented = true
        }
        .background(
          SharePickerAnchor(isPresented: $isSharePickerPresented, items: [file.url])
        )

        DVButton(titleText: .module("Save As…"), style: .secondary) {
          isSavePanelPresented = true
        }

        DVButton(titleText: .module("Done"), style: .secondaryProminent) {
          onDone()
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
    // 바로 안 지우고 약간의 여유를 둔다 — 시트가 닫히는 시점에 공유·저장이 파일을 아직 읽는 중일 수 있다.
    .onDisappear {
      let file = file
      Task {
        try? await Task.sleep(for: .seconds(10))
        file.removeFromDisk()
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
