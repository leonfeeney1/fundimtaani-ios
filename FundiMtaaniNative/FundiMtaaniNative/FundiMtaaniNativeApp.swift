import SwiftUI

/// App entry. Holds the AppState, checks the site mode on launch and on
/// every return from the background, and shows the mode screen whenever
/// the site is not live — the app never pretends the site is up.
@main
struct FundiMtaaniNativeApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var savedStore = SavedStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environmentObject(savedStore)
                .task {
                    await appState.refreshStatus()
                    if appState.mode == .live {
                        await appState.refreshSession()
                    }
                }
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        Task {
                            await appState.refreshStatus()
                            if appState.mode == .live {
                                await appState.refreshSession()
                            }
                        }
                    }
                }
        }
    }
}

/// Root view: loading -> mode screen (pre-launch / maintenance /
/// offline) -> the live app. No tab is reachable while gated.
struct ContentView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Group {
            switch appState.mode {
            case .unknown:
                LoadingView(message: "Checking FundiMtaani…")
            case .live:
                MainTabsView()
            case .prelaunch, .maintenance:
                ModeView()
            case .offline:
                OfflineView()
            }
        }
        .tint(Brand.primary)
    }
}

/// The five tabs of the live app. Each tab keeps its own navigation
/// stack; booking requires sign-in (the detail view routes to login).
struct MainTabsView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        TabView {
            NavigationStack {
                HomeView()
            }
            .tabItem { Label("Home", systemImage: "house.fill") }

            NavigationStack {
                FundiListView()
            }
            .tabItem { Label("Explore", systemImage: "magnifyingglass") }

            NavigationStack {
                BookingsView()
            }
            .tabItem { Label("Bookings", systemImage: "calendar") }

            NavigationStack {
                SavedView()
            }
            .tabItem { Label("Saved", systemImage: "heart") }

            NavigationStack {
                AccountView()
            }
            .tabItem { Label("Account", systemImage: "person.crop.circle") }
        }
    }
}
