import SwiftUI

/// Brand constants for FundiMtaani.
/// All colours are the real FundiMtaani brand colours from the live site:
/// deep green #0F4C3A, darker #0A3327, amber accent #D97706 (logo accent
/// #F59E0B), WhatsApp #25D366, ink #0F172A, body #334155, light bg #F8FAFC.
/// The web font (Plus Jakarta Sans) is not bundled on iOS; native chrome
/// uses the iOS system font with capped sizes, as documented in the README.
enum Brand {
    static let primary = Color(hex: "0F4C3A")
    static let primaryDark = Color(hex: "0A3327")
    static let primaryMid = Color(hex: "16654F")
    static let accent = Color(hex: "D97706")
    static let accentBright = Color(hex: "F59E0B")
    static let whatsapp = Color(hex: "25D366")
    static let ink = Color(hex: "0F172A")
    static let body = Color(hex: "334155")
    static let lightBackground = Color(hex: "F8FAFC")

    /// The live JSON API the native app talks to. The Phase 1 blueprint
    /// lives at this prefix (commit 504b27c on leonfeeney1/fundimtaani).
    static let apiBaseURL = URL(string: "https://fundimtaani.me/api/v1")!
    static let siteBaseURL = URL(string: "https://fundimtaani.me")!
    static let joinURL = URL(string: "https://fundimtaani.me/join")!
    static let supportPhoneDisplay = "0799 242 459"
    static let supportPhoneDigits = "254799242459"

    /// SF Symbol for a trade icon string from the server (Category.icon,
    /// one of the 13 ICON_CHOICES). Falls back to the briefcase, exactly
    /// as the server's `_trade_icon_for` does.
    static func tradeSymbol(for icon: String) -> String {
        switch icon {
        case "plumbing": return "drop.fill"
        case "electrical": return "bolt.fill"
        case "carpentry": return "hammer.fill"
        case "painting": return "paintbrush.fill"
        case "masonry": return "building.2.fill"
        case "welding": return "flame.fill"
        case "cleaning": return "sparkles"
        case "gardening": return "leaf.fill"
        case "mechanic": return "wrench.fill"
        case "tailor": return "scissors"
        case "appliance-repair": return "plug.fill"
        case "phone-repair": return "iphone"
        default: return "briefcase.fill"
        }
    }

    /// Resolve a photo URL from the API. The server returns a relative
    /// path ("/photos/workers/<file>") or null; make it absolute.
    static func absolutePhotoURL(_ raw: String?) -> URL? {
        guard let raw, !raw.isEmpty else { return nil }
        if raw.hasPrefix("http") { return URL(string: raw) }
        return URL(string: raw, relativeTo: siteBaseURL)
    }
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
