import SwiftUI

public enum Colors {
    /// Education teal (LMS palette). Light `#0F766E` / dark `#5EEAD4`.
    public static let accent = Color(light: Color(hex: 0x0F766E), dark: Color(hex: 0x5EEAD4))
    public static let onAccent = Color(light: Color.white, dark: Color(hex: 0x042F2E))
    public static let success = Color.green
    public static let warning = Color.orange
    public static let danger = Color.red
    public static let secondaryFill = Color.secondary
    public static let background = Color(light: Color(hex: 0xF3F6F4), dark: Color(hex: 0x0C1211))
    public static let cardFill = Color(light: Color(hex: 0xFFFEFB), dark: Color(hex: 0x16201E))
    public static let cardStroke = Color(light: Color(hex: 0xD5E3DF), dark: Color(hex: 0x2A3C38))
}
