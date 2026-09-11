import Foundation

enum WayfolioMetrics {
    static let outerMargin: CGFloat = 14
    static let contentInset: CGFloat = 16
    static let compactGap: CGFloat = 8
    static let standardGap: CGFloat = 12
    static let sectionGap: CGFloat = 16
    static let panelRadius: CGFloat = 18
    static let cardRadius: CGFloat = 14
    static let dockHeight: CGFloat = 88
    static let quickRailWidth: CGFloat = 52
    static let quickRailGap: CGFloat = 10
    static let medallionDiameter: CGFloat = 72

    // Locked iPhone top-bar reference geometry (2026-09-07).
    static let referenceCanvasWidth: CGFloat = 440
    static let topBarReferenceHeight: CGFloat = 149
    static let topBarRuntimeCenterY: CGFloat = 77

    static func topBarScale(for width: CGFloat) -> CGFloat {
        guard width > 0 else { return 1 }
        return width / referenceCanvasWidth
    }

    static func topBarHeight(for width: CGFloat) -> CGFloat {
        topBarReferenceHeight * topBarScale(for: width)
    }
}
