// Copyright © 2026 Devault. All rights reserved

import Foundation

/// Export가 끝난 뒤 Share/Save As 선택을 기다리는 임시 `.dvt` 파일.
struct ExportedFile: Identifiable, Equatable {
  let id = UUID()
  let url: URL
}
