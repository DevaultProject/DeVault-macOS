// Copyright © 2026 Devault. All rights reserved

import Foundation
import Testing

@testable import DVPresentation

@Suite("ExportedFile")
struct ExportedFileTests {

  private func makeDirectory(named name: String) throws -> URL {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(name, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory
  }

  @Test("UUID 폴더 안의 파일이면 폴더째 지운다")
  func removesUUIDDirectoryWithFile() throws {
    let directory = try makeDirectory(named: UUID().uuidString)
    let url = directory.appendingPathComponent("GitHub Token.dvt")
    try Data("sealed".utf8).write(to: url)

    ExportedFile(url: url).removeFromDisk()

    #expect(!FileManager.default.fileExists(atPath: directory.path))
  }

  @Test("UUID 폴더가 아니면 파일만 지우고 폴더와 다른 파일은 남긴다")
  func keepsNonUUIDDirectory() throws {
    let directory = try makeDirectory(named: "not-a-uuid-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appendingPathComponent("a.dvt")
    let other = directory.appendingPathComponent("other.txt")
    try Data("sealed".utf8).write(to: url)
    try Data("keep".utf8).write(to: other)

    ExportedFile(url: url).removeFromDisk()

    #expect(!FileManager.default.fileExists(atPath: url.path))
    #expect(FileManager.default.fileExists(atPath: other.path))
  }
}
