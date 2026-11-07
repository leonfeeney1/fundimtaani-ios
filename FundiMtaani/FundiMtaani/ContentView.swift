import SwiftUI

/// FundiMtaani — a WKWebView wrapper around the live FundiMtaani site.
///
/// The site itself is the app: every feature and every pixel of the UI
/// comes from https://fundimtaani.me, so this file only adds native
/// chrome (mode pill, loading progress, offline state, pull-to-refresh
/// is wired in the WebView). On a 503 the site's own maintenance or
/// pre-launch page is shown as-is — it is never replaced with a native
/// screen.  The admin console is not linked from this app.
struct ContentView: View {
    @State private var mode: SiteMode = .live
    @State private var progress: Double = 0
    @State private var isLoading = true
    @State private var hasContent = false
    @State private var isOffline = false
    @State private var safariURL: URL?
    @State private var reloadTrigger = 0

    var body: some View {
        NavigationStack {
            ZStack {
                WebViewContainer(
                    mode: $mode,
                    progress: $progress,
                    isLoading: $isLoading,
                    hasContent: $hasContent,
                    isOffline: $isOffline,
                    safariURL: $safariURL,
                    reloadTrigger: reloadTrigger
                )
                .ignoresSafeArea(edges: .bottom)

                if isOffline && !hasContent {
                    offlineView
                }
            }
            .navigationTitle("FundiMtaani")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    modePill
                }
            }
            .overlay(alignment: .top) {
                if isLoading && progress < 1.0 {
                    ProgressView(value: progress)
                        .tint(Brand.accent)
                        .padding(.horizontal, 0)
                }
            }
            .sheet(item: $safariURL) { url in
                SafariView(url: url)
            }
        }
    }

    private var modePill: some View {
        Text(mode.label)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(mode.color, in: Capsule())
            .accessibilityLabel("Site status: \(mode.label)")
    }

    private var offlineView: some View {
        VStack(spacing: 16) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 44))
                .foregroundStyle(Brand.ink)
            Text("No connection")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Brand.ink)
            Text("FundiMtaani could not be reached. Check your connection and try again.")
                .font(.body)
                .foregroundStyle(Brand.body)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button("Retry") {
                isOffline = false
                isLoading = true
                reloadTrigger += 1
            }
            .buttonStyle(.borderedProminent)
            .tint(Brand.primary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

extension URL: Identifiable {
    public var id: String { absoluteString }
}
