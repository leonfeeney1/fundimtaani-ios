import SwiftUI

/// The native mode screen, driven by GET /api/v1/status. Shown while the
/// site is in pre-launch or maintenance — with the real announcement
/// text and the real support contacts from the server, never the site's
/// own 503 HTML. Bookings, login and all writes are blocked by the
/// gate, so there is nothing else to offer here yet.
struct ModeView: View {
    @EnvironmentObject private var appState: AppState

    private var isPrelaunch: Bool { appState.mode == .prelaunch }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer(minLength: 48)

                Image("LaunchLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120, height: 120)
                    .accessibilityHidden(true)

                VStack(spacing: 8) {
                    Text(isPrelaunch ? "We'll be launching soon" : "We'll be back soon")
                        .font(.title2.bold())
                        .foregroundStyle(Brand.ink)
                        .multilineTextAlignment(.center)
                    Text(isPrelaunch
                         ? "FundiMtaani is getting ready to connect you with trusted, verified fundis across Nairobi."
                         : "FundiMtaani is down for maintenance. Please check back shortly.")
                        .font(.body)
                        .foregroundStyle(Brand.body)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 32)

                if let announcement = appState.status?.announcementText,
                   !announcement.isEmpty, appState.status?.announcementEnabled == true {
                    Text(announcement)
                        .font(.subheadline)
                        .foregroundStyle(Brand.body)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Brand.lightBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal, 24)
                }

                VStack(spacing: 12) {
                    Text("Need help?")
                        .font(.headline)
                        .foregroundStyle(Brand.ink)
                    if let phone = appState.status?.supportPhone, !phone.isEmpty {
                        Link(destination: URL(string: "tel:\(phone)")!) {
                            Label(phone, systemImage: "phone.fill")
                        }
                        .buttonStyle(.bordered)
                        .tint(Brand.primary)
                    }
                    if let email = appState.status?.supportEmail, !email.isEmpty {
                        Link(destination: URL(string: "mailto:\(email)")!) {
                            Label(email, systemImage: "envelope.fill")
                        }
                        .buttonStyle(.bordered)
                        .tint(Brand.primary)
                    }
                    if let whatsapp = appState.status?.supportWhatsapp, !whatsapp.isEmpty {
                        Link(destination: URL(string: "https://wa.me/\(whatsapp)")!) {
                            Label("Chat on WhatsApp", systemImage: "message.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Brand.whatsapp)
                    }
                }

                Button {
                    Task { await appState.refreshStatus() }
                } label: {
                    if appState.isCheckingMode {
                        ProgressView()
                    } else {
                        Label("Check again", systemImage: "arrow.clockwise")
                    }
                }
                .buttonStyle(.bordered)
                .tint(Brand.primary)
                .disabled(appState.isCheckingMode)

                Spacer(minLength: 32)
            }
        }
        .background(Color(.systemBackground))
    }
}

/// Shown when the status call itself fails: the backend is unreachable,
/// which is different from the site being deliberately down.
struct OfflineView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "wifi.slash")
                .font(.system(size: 56))
                .foregroundStyle(Brand.body)
            Text("No connection")
                .font(.title2.bold())
                .foregroundStyle(Brand.ink)
            Text("We couldn't reach FundiMtaani. Check your internet and try again.")
                .font(.body)
                .foregroundStyle(Brand.body)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button {
                Task {
                    await appState.refreshStatus()
                    if appState.mode == .live {
                        await appState.refreshSession()
                    }
                }
            } label: {
                if appState.isCheckingMode {
                    ProgressView()
                } else {
                    Label("Retry", systemImage: "arrow.clockwise")
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(Brand.primary)
            .disabled(appState.isCheckingMode)
            Spacer()
        }
        .background(Color(.systemBackground))
    }
}
