import SwiftUI

/// Coverage: the 7 Nairobi zones with badge, description and estate
/// lists, straight from GET /api/v1/coverage. The list is never
/// hardcoded in the app.
struct CoverageView: View {
    @EnvironmentObject private var appState: AppState
    @State private var zones: [EstateZone] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    private let api = APIClient.shared

    var body: some View {
        Group {
            if isLoading && zones.isEmpty {
                LoadingView(message: "Loading coverage…")
            } else if let errorMessage, zones.isEmpty {
                VStack(spacing: 12) {
                    ErrorBannerView(message: errorMessage) { Task { await load() } }
                        .padding()
                    Spacer()
                }
            } else {
                List(zones) { zone in
                    Section {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(zone.zone)
                                    .font(.headline)
                                    .foregroundStyle(Brand.ink)
                                Spacer()
                                Text(zone.badge)
                                    .font(.caption2.bold())
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Brand.accent)
                                    .clipShape(Capsule())
                            }
                            if !zone.description.isEmpty {
                                Text(zone.description)
                                    .font(.subheadline)
                                    .foregroundStyle(Brand.body)
                            }
                            Text(zone.estates.joined(separator: " · "))
                                .font(.caption)
                                .foregroundStyle(Brand.body)
                        }
                        .padding(.vertical, 4)
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Coverage")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .refreshable { await load() }
    }

    private func load() async {
        if zones.isEmpty { isLoading = true }
        errorMessage = nil
        do {
            zones = try await api.fetchCoverage().zones
        } catch let error as APIError {
            if error.isSiteUnavailable {
                await appState.noteSiteUnavailable()
            } else {
                errorMessage = error.localizedDescription
            }
        } catch {
            errorMessage = APIErrorAlert.message(for: error)
        }
        isLoading = false
    }
}
