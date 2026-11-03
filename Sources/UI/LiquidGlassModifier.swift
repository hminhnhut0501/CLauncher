import SwiftUI

/// True Liquid Glass Modifier - Replicating macOS Tahoe & VisionOS Glass Optics
public struct LiquidGlassModifier: ViewModifier {
    public var cornerRadius: CGFloat
    public var opacity: Double
    public var borderOpacity: Double
    public var isHighlighted: Bool

    public init(
        cornerRadius: CGFloat = 22,
        opacity: Double = 0.16,
        borderOpacity: Double = 0.40,
        isHighlighted: Bool = false
    ) {
        self.cornerRadius = cornerRadius
        self.opacity = opacity
        self.borderOpacity = borderOpacity
        self.isHighlighted = isHighlighted
    }

    public func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    // 1. Crystal Translucent Liquid Base
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(opacity + 0.08),
                                    Color.white.opacity(opacity * 0.5)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    // 2. Optical Lens Specular Highlight (Curved light reflection on top)
                    VStack {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.35),
                                        Color.white.opacity(0.04),
                                        Color.clear
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(height: 38)
                        Spacer()
                    }
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))

                    // 3. Asymmetric Specular Edge Rim (Tahoe 135-degree light source)
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(
                            LinearGradient(
                                stops: [
                                    .init(color: Color.white.opacity(borderOpacity + (isHighlighted ? 0.35 : 0.0)), location: 0.0),
                                    .init(color: Color.white.opacity(borderOpacity * 0.4), location: 0.4),
                                    .init(color: Color.white.opacity(0.12), location: 0.7),
                                    .init(color: Color.white.opacity(borderOpacity * 0.5), location: 1.0)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: isHighlighted ? 1.4 : 0.8
                        )
                }
                .shadow(color: Color.black.opacity(0.28), radius: 16, x: 0, y: 8)
                .shadow(color: isHighlighted ? Color.white.opacity(0.25) : Color.clear, radius: 10, x: 0, y: 0)
            )
    }
}

public extension View {
    func liquidGlass(
        cornerRadius: CGFloat = 22,
        opacity: Double = 0.16,
        borderOpacity: Double = 0.40,
        isHighlighted: Bool = false
    ) -> some View {
        self.modifier(LiquidGlassModifier(
            cornerRadius: cornerRadius,
            opacity: opacity,
            borderOpacity: borderOpacity,
            isHighlighted: isHighlighted
        ))
    }
}
