import SwiftUI

/// Account: the signed-in user's details (from GET /api/v1/auth/me),
/// links to bookings/saved/coverage, the fundi-application row, and
/// sign out. Signed-out users get the login / signup entry points.
struct AccountView: View {
    @EnvironmentObject private var appState: AppState
    @State private var showLogin = false
    @State private var showSignup = false
    @State private var isSigningOut = false

    var body: some View {
        Group {
            if let user = appState.user {
                signedInSection(user)
            } else {
                signedOutSection
            }
        }
        .navigationTitle("Account")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showLogin) {
            NavigationStack { LoginView() }
        }
        .sheet(isPresented: $showSignup) {
            NavigationStack { SignupView() }
        }
        .task {
            if appState.isSignedIn {
                await appState.refreshSession()
            }
        }
    }

    private var signedOutSection: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "person.crop.circle")
                .font(.system(size: 64))
                .foregroundStyle(Brand.primary)
            Text("Your account")
                .font(.title2.bold())
                .foregroundStyle(Brand.ink)
            Text("Sign in to book fundis, see your bookings, and save the fundis you like.")
                .font(.body)
                .foregroundStyle(Brand.body)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button("Log in") { showLogin = true }
                .buttonStyle(.borderedProminent)
                .tint(Brand.primary)
            Button("Create an account") { showSignup = true }
                .buttonStyle(.bordered)
                .tint(Brand.primary)
            Spacer()
        }
    }

    private func signedInSection(_ user: User) -> some View {
        List {
            Section {
                HStack(spacing: 12) {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(Brand.primary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(user.name)
                            .font(.headline)
                            .foregroundStyle(Brand.ink)
                        if let email = user.email {
                            Text(email)
                                .font(.subheadline)
                                .foregroundStyle(Brand.body)
                        }
                        Text(user.phone)
                            .font(.subheadline)
                            .foregroundStyle(Brand.body)
                        HStack(spacing: 6) {
                            Text(user.role.capitalized)
                                .font(.caption2.bold())
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Brand.primary)
                                .clipShape(Capsule())
                            if user.emailVerified {
                                Label("Email verified", systemImage: "checkmark.seal.fill")
                                    .font(.caption)
                                    .foregroundStyle(Brand.primary)
                            } else {
                                Label("Email not verified", systemImage: "exclamationmark.circle.fill")
                                    .font(.caption)
                                    .foregroundStyle(Brand.accent)
                            }
                        }
                    }
                }
            }
            Section {
                NavigationLink {
                    BookingsView()
                } label: {
                    Label("My bookings", systemImage: "calendar")
                }
                NavigationLink {
                    SavedView()
                } label: {
                    Label("Saved fundis", systemImage: "heart")
                }
                NavigationLink {
                    CoverageView()
                } label: {
                    Label("Coverage", systemImage: "map")
                }
            }
            if user.isTechnician {
                Section {
                    if let joinStep = user.joinStep, joinStep < 4 {
                        Link(destination: Brand.joinURL) {
                            Label("Complete your fundi application (step \(joinStep) of 4)", systemImage: "wrench.and.screwdriver.fill")
                        }
                    } else {
                        Label("Fundi application complete", systemImage: "checkmark.seal.fill")
                            .foregroundStyle(Brand.primary)
                    }
                } header: {
                    Text("For fundis")
                } footer: {
                    Text("The in-app fundi application opens in the next update — for now it opens the website.")
                }
            } else {
                Section {
                    Link(destination: Brand.joinURL) {
                        Label("Join as a fundi", systemImage: "wrench.and.screwdriver.fill")
                    }
                } header: {
                    Text("For fundis")
                } footer: {
                    Text("The in-app fundi application opens in the next update — for now it opens the website.")
                }
            }
            Section {
                Button {
                    Task {
                        isSigningOut = true
                        await appState.signOut()
                        isSigningOut = false
                    }
                } label: {
                    if isSigningOut {
                        ProgressView()
                    } else {
                        Label("Sign out", systemImage: "rectangle.portrait.and.arrow.right")
                            .foregroundStyle(Color(hex: "DC2626"))
                    }
                }
                .disabled(isSigningOut)
            }
        }
    }
}
