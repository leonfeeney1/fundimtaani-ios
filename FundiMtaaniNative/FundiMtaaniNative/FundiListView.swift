import SwiftUI

/// Search / Browse fundis: approved fundis with trade, estate, text,
/// emergency, available-today and minimum-rating filters, sorted
/// featured / newest / rating / reviews. Filtering is its own step
/// after results (SAD-unit decision): the search runs first, then the
/// filter controls refine the same list.
struct FundiListView: View {
    @EnvironmentObject private var appState: AppState
    @State private var filter: FundiFilter
    @State private var fundis: [FundiSummary] = []
    @State private var meta: PageMeta?
    @State private var trades: [Trade] = []
    @State private var estates: [String] = []
    @State private var isLoading = false
    @State private var hasSearched = false
    @State private var errorMessage: String?

    private let api = APIClient.shared

    init(initialFilter: FundiFilter = FundiFilter()) {
        _filter = State(initialValue: initialFilter)
    }

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            filterBar
            Divider()
            if isLoading && fundis.isEmpty {
                LoadingView(message: "Searching…")
            } else if let errorMessage {
                VStack(spacing: 12) {
                    ErrorBannerView(message: errorMessage) { Task { await search() } }
                        .padding()
                    Spacer()
                }
            } else if fundis.isEmpty && hasSearched {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "magnifyingglass")
                        .font(.largeTitle)
                        .foregroundStyle(Brand.body)
                    Text("No fundis found")
                        .font(.headline)
                        .foregroundStyle(Brand.ink)
                    Text("Try a different trade, estate, or search word.")
                        .font(.subheadline)
                        .foregroundStyle(Brand.body)
                        .multilineTextAlignment(.center)
                    Spacer()
                }
                .padding()
            } else {
                List {
                    if let meta {
                        Text("\(meta.total) fundi\(meta.total == 1 ? "" : "s") found")
                            .font(.caption)
                            .foregroundStyle(Brand.body)
                    }
                    ForEach(fundis) { fundi in
                        NavigationLink(value: fundi) {
                            FundiCardView(fundi: fundi)
                        }
                        .buttonStyle(.plain)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Find a Fundi")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: FundiSummary.self) { fundi in
            FundiDetailView(fundiId: fundi.id)
        }
        .task {
            await loadPickers()
            await search()
        }
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Brand.body)
                TextField("Search name, trade, or job…", text: $filter.query)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    .submitLabel(.search)
                    .onSubmit { Task { await search() } }
                if !filter.query.isEmpty {
                    Button {
                        filter.query = ""
                        Task { await search() }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Brand.body)
                    }
                }
            }
            .padding(10)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            Button("Search") {
                Task { await search() }
            }
            .buttonStyle(.borderedProminent)
            .tint(Brand.primary)
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Picker("Trade", selection: $filter.category) {
                    Text("All trades").tag("")
                    ForEach(trades) { trade in
                        Text(trade.name).tag(trade.slug)
                    }
                }
                .pickerStyle(.menu)
                Picker("Estate", selection: $filter.estate) {
                    Text("All estates").tag("")
                    ForEach(estates, id: \.self) { estate in
                        Text(estate).tag(estate)
                    }
                }
                .pickerStyle(.menu)
                Picker("Rating", selection: $filter.minRating) {
                    Text("Any rating").tag(0.0)
                    Text("3.0+").tag(3.0)
                    Text("4.0+").tag(4.0)
                    Text("4.5+").tag(4.5)
                }
                .pickerStyle(.menu)
                Picker("Sort", selection: $filter.sort) {
                    Text("Featured").tag("featured")
                    Text("Newest").tag("newest")
                    Text("Top rated").tag("rating")
                    Text("Most reviewed").tag("reviews")
                }
                .pickerStyle(.menu)
                Toggle("Available today", isOn: $filter.availableTodayOnly)
                    .toggleStyle(.button)
                    .tint(Brand.primary)
                Toggle("Emergency", isOn: $filter.emergencyOnly)
                    .toggleStyle(.button)
                    .tint(Brand.primary)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .onChange(of: filter.category) { Task { await search() } }
        .onChange(of: filter.estate) { Task { await search() } }
        .onChange(of: filter.minRating) { Task { await search() } }
        .onChange(of: filter.sort) { Task { await search() } }
        .onChange(of: filter.availableTodayOnly) { Task { await search() } }
        .onChange(of: filter.emergencyOnly) { Task { await search() } }
    }

    private func loadPickers() async {
        do {
            async let tradesTask = api.fetchTrades()
            async let estatesTask = api.fetchEstates()
            let (tradesResult, estatesResult) = try await (tradesTask, estatesTask)
            trades = tradesResult
            estates = estatesResult.scoped
        } catch let error as APIError {
            if error.isSiteUnavailable {
                await appState.noteSiteUnavailable()
            }
        } catch {
            // Pickers are optional; the search still works without them.
        }
    }

    private func search() async {
        isLoading = true
        errorMessage = nil
        do {
            let (results, pageMeta) = try await api.fetchFundis(filter)
            fundis = results
            meta = pageMeta
            hasSearched = true
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
