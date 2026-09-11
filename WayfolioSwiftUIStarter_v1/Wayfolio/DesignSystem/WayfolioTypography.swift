import SwiftUI

enum WayfolioTypography {
    static let display = Font.custom("EBGaramond-SemiBold", size: 34, relativeTo: .largeTitle)
    static let title = Font.custom("EBGaramond-SemiBold", size: 24, relativeTo: .title2)
    static let headline = Font.custom("EBGaramond-SemiBold", size: 17, relativeTo: .headline)
    static let reading = Font.custom("EBGaramond-Regular", size: 16, relativeTo: .body)
    static let body = Font.custom("Manrope-Regular", size: 15, relativeTo: .body)
    static let caption = Font.custom("Manrope-Medium", size: 12, relativeTo: .caption)
    static let tiny = Font.custom("Manrope-SemiBold", size: 10, relativeTo: .caption2)
}
