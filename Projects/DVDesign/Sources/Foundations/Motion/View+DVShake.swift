// Copyright © 2026 Devault. All rights reserved

import SwiftUI

public extension View {
    /// `trigger`가 바뀔 때마다 좌우로 흔든다. 틀린 입력처럼 거절을 알리는 되먹임에 쓴다.
    /// 시스템 "동작 줄이기(Reduce Motion)"가 켜져 있으면 흔들지 않는다.
    func dvShake(trigger: Int) -> some View {
        modifier(ShakeModifier(trigger: trigger))
    }
}

private struct ShakeModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let trigger: Int

    func body(content: Content) -> some View {
        content
            .modifier(ShakeEffect(progress: CGFloat(trigger)))
            .animation(reduceMotion ? nil : .linear(duration: 0.28), value: trigger)
    }
}

/// `progress`가 정수에서 다음 정수로 갈 때 두 번 왕복하고 제자리로 돌아온다.
private struct ShakeEffect: GeometryEffect {
    var progress: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        let offset = 6 * sin(progress * .pi * 4)
        return ProjectionTransform(CGAffineTransform(translationX: offset, y: 0))
    }
}

#if DEBUG

#Preview("Shake") {
    DVShakePreview()
        .padding()
}

private struct DVShakePreview: View {
    @State private var trigger = 0

    var body: some View {
        VStack(spacing: 12) {
            Text("Shake me")
                .padding(8)
                .background(Color.dv(.gray300))
                .dvShake(trigger: trigger)
            Button("Shake") { trigger += 1 }
        }
    }
}

#endif
