import SwiftUI

/// Dynamic Type sizes. Avoid fixed-point fonts so largest content sizes still layout.
/// Titles use SF Rounded for warmth; body stays default SF for long-form reading.
public enum Typography {
    public static let title = Font.system(.title, design: .rounded)
    public static let headline = Font.system(.headline, design: .rounded)
    public static let body = Font.body
    public static let callout = Font.callout
    public static let caption = Font.caption
    public static let score = Font.system(.title2, design: .rounded).monospacedDigit()
}
