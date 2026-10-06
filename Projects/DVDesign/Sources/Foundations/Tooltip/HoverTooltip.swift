// Copyright © 2026 Devault. All rights reserved

import SwiftUI

/// `.help(_:)`와 `NSView.toolTip` 둘 다 `List` 행 안에서 안 떴다(마우스 이벤트는 도달하는데
/// 시스템 tooltip 렌더링만 안 됨). `.overlay`로 직접 그리면 `List`가 폭 밖 콘텐츠를 잘라서,
/// 화면 절대 좌표의 별도 `NSWindow`로 띄운다 — 실제 시스템 tooltip과 같은 방식.
extension View {
    /// `text`가 `nil`이면 아무것도 붙이지 않는다.
    public func hoverTooltip(_ text: String?) -> some View {
        overlay {
            if let text {
                HoverTooltipHost(text: text)
            }
        }
    }
}

private struct HoverTooltipHost: NSViewRepresentable {
    let text: String

    func makeNSView(context: Context) -> TrackingView {
        let view = TrackingView()
        view.text = text
        return view
    }

    func updateNSView(_ nsView: TrackingView, context: Context) {
        nsView.text = text
    }
}

private final class TrackingView: NSView {
    var text: String?

    private var trackingArea: NSTrackingArea?
    private var tooltipPanel: NSPanel?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea {
            removeTrackingArea(trackingArea)
        }
        let newTrackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(newTrackingArea)
        trackingArea = newTrackingArea
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        showTooltip()
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        hideTooltip()
    }

    override func removeFromSuperview() {
        hideTooltip()
        super.removeFromSuperview()
    }

    // hover 전용이라 히트테스트에서 빠진다 — 안 그러면 배지 클릭이 행 선택을 막을 수 있다.
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    deinit {
        hideTooltip()
    }

    private func showTooltip() {
        guard let text, let window, !text.isEmpty else { return }
        // mouseExited 없이 mouseEntered가 다시 올 수 있어(트래킹 재등록 시) 먼저 정리한다.
        hideTooltip()

        let hosting = NSHostingView(rootView: TooltipBubble(text: text))
        let size = hosting.fittingSize
        hosting.frame = CGRect(origin: .zero, size: size)

        let panel = NSPanel(
            contentRect: CGRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .popUpMenu
        panel.ignoresMouseEvents = true
        panel.isReleasedWhenClosed = false
        panel.contentView = hosting

        let boundsInWindow = convert(bounds, to: nil)
        let boundsOnScreen = window.convertToScreen(boundsInWindow)
        let origin = CGPoint(
            x: boundsOnScreen.midX - size.width / 2,
            y: boundsOnScreen.minY - size.height - 6
        )
        panel.setFrameOrigin(origin)
        window.addChildWindow(panel, ordered: .above)
        tooltipPanel = panel
    }

    private func hideTooltip() {
        if let tooltipPanel {
            tooltipPanel.parent?.removeChildWindow(tooltipPanel)
            tooltipPanel.orderOut(nil)
        }
        tooltipPanel = nil
    }
}

/// macOS 시스템 tooltip과 비슷한 외관(밝은 회색 배경 + 어두운 텍스트)으로 맞춘다.
private struct TooltipBubble: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundStyle(Color(NSColor.labelColor))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(NSColor.windowBackgroundColor), in: RoundedRectangle(cornerRadius: 4))
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color(NSColor.separatorColor), lineWidth: 1)
            )
            .fixedSize()
    }
}
