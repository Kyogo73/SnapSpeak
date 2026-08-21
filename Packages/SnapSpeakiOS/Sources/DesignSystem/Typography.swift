import SwiftUI

/// Dynamic Type sizes. Avoid fixed-point fonts so largest content sizes still layout.
public enum Typography {
    public static let title = Font.title
    public static let headline = Font.headline
    public static let body = Font.body
    public static let callout = Font.callout
    public static let caption = Font.caption
    public static let score = Font.title2.monospacedDigit()
}
