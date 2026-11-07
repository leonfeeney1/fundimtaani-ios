import SwiftUI

/// The site's mode, as seen by the wrapper.
///
/// There is no health / status endpoint on the site, so the mode is only
/// visible from the HTTP status of the top-level load: 200 means the site
/// is live, 503 means the maintenance or pre-launch gate is active. The
/// two 503 pages are told apart by the loaded page's wording; when the
/// wording cannot be read the pill falls back to "Unavailable" rather
/// than guessing.
enum SiteMode: Equatable {
    case live
    case maintenance
    case prelaunch
    case unavailable
    case offline

    var label: String {
        switch self {
        case .live: return "Live"
        case .maintenance: return "Maintenance"
        case .prelaunch: return "Pre-launch"
        case .unavailable: return "Unavailable"
        case .offline: return "Offline"
        }
    }

    var color: Color {
        switch self {
        case .live: return Brand.primary
        case .maintenance: return Brand.accent
        case .prelaunch: return Brand.ink
        case .unavailable: return Color.gray
        case .offline: return Color.gray
        }
    }

    /// Classify a 503 page from its title and visible text. Returns
    /// `.unavailable` when the wording does not identify the page.
    static func classify503Page(text: String) -> SiteMode {
        let lower = text.lowercased()
        if lower.contains("pre-launch") || lower.contains("prelaunch")
            || lower.contains("launching soon") || lower.contains("coming soon") {
            return .prelaunch
        }
        if lower.contains("maintenance") || lower.contains("under maintenance")
            || lower.contains("be right back") || lower.contains("back soon") {
            return .maintenance
        }
        return .unavailable
    }
}
