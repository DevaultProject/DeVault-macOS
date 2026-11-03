// Copyright © 2026 Devault. All rights reserved

import Foundation

/// Export가 끝난 뒤 Share/Save As 선택을 기다리는 임시 `.dvt` 파일.
struct ExportedFile: Identifiable, Equatable {
  let url: URL
  var id: URL { url }

  /// 파일과 그 UUID 폴더를 지운다. UUID 폴더가 아니면 파일만 지운다.
  func removeFromDisk() {
    let directory = url.deletingLastPathComponent()
    let target = UUID(uuidString: directory.lastPathComponent) == nil ? url : directory
    try? FileManager.default.removeItem(at: target)
  }
}
