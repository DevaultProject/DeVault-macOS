// Copyright © 2026 Devault. All rights reserved

import SwiftUI
import UniformTypeIdentifiers

/// `.fileExporter`(NSSavePanel)로 임시 `.dvt` 파일을 사용자가 고른 위치에 복사하기 위한 래퍼.
struct DvtFileDocument: FileDocument {
  static let dvtContentType = UTType(exportedAs: "com.devault.container")
  static var readableContentTypes: [UTType] { [dvtContentType] }

  /// 소스 임시 파일을 못 읽으면 nil — 조용히 빈 파일을 저장하는 대신 `fileWrapper`에서 던진다.
  private let data: Data?

  init(fileURL: URL) {
    data = try? Data(contentsOf: fileURL)
  }

  init(configuration: ReadConfiguration) throws {
    data = configuration.file.regularFileContents
  }

  func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
    guard let data else {
      throw CocoaError(.fileReadUnknown)
    }
    return FileWrapper(regularFileWithContents: data)
  }
}
