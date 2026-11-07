import Foundation
import SwiftUI

/// The mode the site is in, from GET /api/v1/status. The app never
/// guesses — every launch and every return from background re-checks.
enum SiteMode: Equatable {
    case unknown
    case live
    case prelaunch
    case maintenance
    case offline
}

/// Shared app state: site mode + signed-in user. Owned by the App entry
/// and injected as an environment object.
@MainActor
final class AppState: ObservableObject {
    @Published var mode: SiteMode = .unknown
    @Published var status: SiteStatusPayload?
    @Published var user: User?
    @Published var isCheckingMode = false

    private let api = APIClient.shared

    var isSignedIn: Bool { user != nil }

    /// Fetch the site mode. Called on launch and after backgrounding.
    /// A network failure means offline — never a mode guess.
    func refreshStatus() async {
        isCheckingMode = true
        defer { isCheckingMode = false }
        do {
            let payload = try await api.fetchStatus()
            status = payload
            switch payload.siteStatus {
            case "live": mode = .live
            case "prelaunch": mode = .prelaunch
            default: mode = .maintenance
            }
        } catch {
            mode = .offline
        }
    }

    /// Restore the session from the stored cookie. A 401 simply means
    /// signed out; anything else leaves the previous state alone.
    func refreshSession() async {
        do {
            user = try await api.fetchMe()
        } catch let error as APIError {
            if case .unauthorized = error { user = nil }
        } catch {
            // Leave the session state as it is on a network failure.
        }
    }

    /// A gated call failed with site_unavailable: the mode changed under
    /// us. Re-check the mode so the mode screen takes over.
    func noteSiteUnavailable() async {
        await refreshStatus()
    }

    func signOut() async {
        try? await api.logout()
        user = nil
    }
}
