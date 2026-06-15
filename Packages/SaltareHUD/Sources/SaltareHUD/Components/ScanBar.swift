import SwiftUI

/// `nier-scan-bar` — a 1pt horizontal sweep: a 20%-width arc gradient slides
/// from off-screen left to off-screen right every `duration`, linearly. The
/// HUD's "alive" signal.
public struct ScanBar: View {
    let color: Color?
    let duration: Double

    @Environment(\.saltareColors) private var colors
    @State private var position: CGFloat = -0.2

    public init(color: Color? = nil, duration: Double = 2.5) {
        self.color = color
        self.duration = duration
    }

    public var body: some View {
        let tint = color ?? colors.arc
        GeometryReader { geo in
            let barWidth = geo.size.width * 0.2
            Rectangle()
                .fill(LinearGradient(
                    stops: [
                        .init(color: tint.opacity(0), location: 0),
                        .init(color: tint, location: 0.5),
                        .init(color: tint.opacity(0), location: 1),
                    ],
                    startPoint: .leading, endPoint: .trailing
                ))
                .frame(width: barWidth)
                .offset(x: geo.size.width * position)
        }
        .frame(height: 1)
        .onAppear {
            withAnimation(.linear(duration: duration).repeatForever(autoreverses: false)) {
                position = 1
            }
        }
    }
}
