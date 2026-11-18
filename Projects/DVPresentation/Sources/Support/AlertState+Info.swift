// Copyright © 2026 Devault. All rights reserved

import ComposableArchitecture

extension AlertState {

  /// 제목과 메시지에 닫기 버튼 하나만 있는 알럿.
  static func info(
    title: String.LocalizationValue,
    message: String.LocalizationValue,
    buttonTitle: String.LocalizationValue = "OK"
  ) -> Self {
    AlertState {
      TextState(String.module(title))
    } actions: {
      ButtonState(role: .cancel) { TextState(String.module(buttonTitle)) }
    } message: {
      TextState(String.module(message))
    }
  }
}
