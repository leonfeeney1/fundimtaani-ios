import SwiftUI

/// Brand constants for FundiMtaani.
/// All colours are the real FundiMtaani brand colours from the live site.
/// The web font (Plus Jakarta Sans) is not bundled on iOS; native chrome
/// uses the iOS system font, as documented in the README.
enum Brand {
    static let primary = Color(hex: "0F4C3A")
    static let primaryHover = Color(hex: "0A3327")
    static let accent = Color(hex: "D97706")
    static let ink = Color(hex: "0F172A")
    static let body = Color(hex: "334155")

    /// The live site entry point. The customer app loads the public site;
    /// the admin app loads the admin console, which bypasses the
    /// maintenance / pre-launch gate.
    static let entryURL = URL(string: "https://fundimtaani.me/")!

    /// The site's own host. Only this host is ever loaded in the WebView.
    static let siteHost = "fundimtaani.me"
}

extension Color {
    init(hex: String) {
        let value = UInt64(hex, radix: 16) ?? 0
        let red = Double((value >> 16) & 0xFF) / 255.0
        let green = Double((value >> 8) & 0xFF) / 255.0
        let blue = Double(value & 0xFF) / 255.0
        self.init(red: red, green: green, blue: blue)
    }
}
