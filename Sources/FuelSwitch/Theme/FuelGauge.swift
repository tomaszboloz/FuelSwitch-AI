import SwiftUI

/// Precision fuel bar with segmented glowing track and tabular typography.
public struct FuelGauge: View {
    public let value: Double
    public let color: Color
    public var height: CGFloat = 6
    public var showSegments: Bool = true

    public init(value: Double, color: Color, height: CGFloat = 6, showSegments: Bool = true) {
        self.value = max(0, min(100, value))
        self.color = color
        self.height = height
        self.showSegments = showSegments
    }

    public var body: some View {
        GeometryReader { geo in
            let fillWidth = max(0, min(geo.size.width, geo.size.width * CGFloat(value / 100.0)))
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(Color.white.opacity(0.06))

                if fillWidth > 0 {
                    RoundedRectangle(cornerRadius: height / 2)
                        .fill(
                            LinearGradient(
                                colors: [color.opacity(0.85), color],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: fillWidth)
                        .shadow(color: color.opacity(0.4), radius: 3, x: 0, y: 0)
                }

                if showSegments && geo.size.width > 120 {
                    HStack(spacing: 0) {
                        Spacer()
                        tick
                        Spacer()
                        tick
                        Spacer()
                        tick
                        Spacer()
                    }
                }
            }
        }
        .frame(height: height)
    }

    private var tick: some View {
        Rectangle()
            .fill(Color.black.opacity(0.4))
            .frame(width: 1, height: height)
    }
}
