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
        // Share는 완료 콜백이 없다. 탭과 동시에(simultaneousGesture) 바로 닫으면 NSSharingServicePicker가
        // 팝오버를 띄우기 전에 이 뷰의 창이 사라져 공유 자체가 실패한다("no window"). 픽커가 창을
        // 넘겨받을 시간을 준 뒤 닫는다 — Save As처럼 결과를 기다리는 건 아니라 정확한 완료 시점은 모른다.
        .simultaneousGesture(TapGesture().onEnded {
          Task {
            try? await Task.sleep(for: .seconds(1))
            onDone()
          }
        })

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
    // Share는 탭한 즉시 시트를 닫지만, NSSharingServicePicker가 파일을 실제로 읽는 건 그 뒤다 —
    // 여기서 바로 지우면 픽커가 열리기도 전에 파일이 사라져 공유가 실패한다(sandbox extension
    // token 생성 실패). Save As는 fileExporter가 이미 복사를 끝낸 뒤에만 onDone을 부르므로
    // 지연 삭제로도 안전하다.
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
