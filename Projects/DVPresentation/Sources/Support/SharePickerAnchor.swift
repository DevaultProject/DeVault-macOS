// Copyright © 2026 Devault. All rights reserved

import AppKit
import SwiftUI

/// `NSSharingServicePicker`를 직접 띄운다.
///
/// SwiftUI `ShareLink`는 완료 콜백이 없다 — 추측 타이머로 호출부를 닫으면, 사용자가 픽커를
/// 더 오래 보고 있을 때 그 밑에서 창이 뜯겨나가 픽커까지 같이 죽는다("this process disconnected
/// remote view controller"). AirDrop처럼 전송에 시간이 걸리는 서비스는 완료 콜백도 들쭉날쭉해서
/// 자동으로 닫는 시점을 믿을 수 없으므로, 호출부가 별도 버튼(Done)으로 직접 닫게 한다.
struct SharePickerAnchor: NSViewRepresentable {
  @Binding var isPresented: Bool
  let items: [Any]

  func makeNSView(context: Context) -> NSView { NSView() }

  func updateNSView(_ nsView: NSView, context: Context) {
    guard isPresented else { return }
    isPresented = false

    let picker = NSSharingServicePicker(items: items)
    picker.delegate = context.coordinator
    context.coordinator.picker = picker
    picker.show(relativeTo: nsView.bounds, of: nsView, preferredEdge: .minY)
  }

  func makeCoordinator() -> Coordinator { Coordinator() }

  final class Coordinator: NSObject, NSSharingServicePickerDelegate {
    /// 델리게이트로 계속 붙잡아 둔다 — 안 그러면 `show` 반환 직후 해제돼 콜백을 못 받는다.
    var picker: NSSharingServicePicker?
  }
}
