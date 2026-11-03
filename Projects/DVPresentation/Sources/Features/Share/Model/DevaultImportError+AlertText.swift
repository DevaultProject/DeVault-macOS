// Copyright © 2026 Devault. All rights reserved

import DVDomain

extension DevaultImportError {

  /// 알럿으로 알리는 거절 문구. 비밀번호 화면과 파일 진입(헤더 사전 판별)이 같은 문구를 쓴다.
  /// `invalidPassword`는 비밀번호 화면 안에서 처리하므로 `nil`이다.
  var rejectionAlertText: (title: String, message: String)? {
    switch self {
    case .versionMismatch:
      return (
        String.module("Unsupported File Version"),
        String.module("This file requires a newer version of DeVault. Please update the app and try again.")
      )
    case .expired:
      return (
        String.module("File Expired"),
        String.module("This file has expired and can no longer be opened. Ask the sender to share it again.")
      )
    case .corrupted:
      return (
        String.module("File Corrupted"),
        String.module("This file appears to be damaged or tampered with and can't be opened.")
      )
    case .invalidPassword:
      return nil
    }
  }
}
