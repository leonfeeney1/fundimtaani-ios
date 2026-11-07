import SwiftUI

/// Home: search (trade + estate), Browse by Trade, featured and recent
/// fundis, live stats, testimonials, How It Works, Coverage. All data
/// comes from GET /api/v1/home + /trades + /estates — the counts are
/// live DB counts, never the animated home counters.
struct HomeView: View {
    @EnvironmentObject private var appState: AppState
    @State private var home: HomePayload?
    @State private var trades: [Trade] = []
    @State private var estates: [String] = []
    @State private var selectedTrade = ""
    @State private var selectedEstate = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    private let api = APIClient.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                heroSection
                if let errorMessage {
                    ErrorBannerView(message: errorMessage) { Task { await load() } }
                        .padding(.horizontal)
                }
                if isLoading && home == nil {
                    LoadingView(message: "Loading fundis…")
                } else if let home {
                    tradesSection
                    featuredSection(home.featured)
                    recentSection(home.recent)
                    statsSection(home.stats)
                    testimonialsSection(home.testimonials)
                    howItWorksSection
                    coverageLink
                }
            }
            .padding(.bottom, 24)
        }
        .navigationTitle("FundiMtaani")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    CoverageView()
                } label: {
                    Label("Coverage", systemImage: "map")
                }
            }
        }
        .task { await load() }
        .refreshable { await load() }
        .navigationDestination(for: FundiSummary.self) { fundi in
            FundiDetailView(fundiId: fundi.id)
        }
    }

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Find a trusted fundi near you, fast.")
                .font(.title.bold())
                .foregroundStyle(.white)
            Text("Verified local tradespeople in Nairobi.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.85))
            VStack(spacing: 10) {
                Picker("Trade", selection: $selectedTrade) {
                    Text("All trades").tag("")
                    ForEach(trades) { trade in
                        Text(trade.name).tag(trade.slug)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                Picker("Estate", selection: $selectedEstate) {
                    Text("All estates").tag("")
                    ForEach(estates, id: \.self) { estate in
                        Text(estate).tag(estate)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                NavigationLink {
                    FundiListView(initialFilter: FundiFilter(category: selectedTrade, estate: selectedEstate))
                } label: {
                    Label("Search", systemImage: "magnifyingglass")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Brand.accent)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
        .padding(20)
        .background(
            LinearGradient(colors: [Brand.primary, Brand.primaryDark], startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .padding(.horizontal)
        .padding(.top, 8)
    }

    private var tradesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Browse by Trade")
                .font(.title3.bold())
                .foregroundStyle(Brand.ink)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(trades) { trade in
                    NavigationLink {
                        FundiListView(initialFilter: FundiFilter(category: trade.slug))
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: Brand.tradeSymbol(for: trade.icon))
                                .font(.title2)
                                .foregroundStyle(Brand.primary)
                            Text(trade.name)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Brand.ink)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
        }
        .padding(.horizontal)
    }

    private func fundiRow(_ fundis: [FundiSummary]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(fundis) { fundi in
                    NavigationLink(value: fundi) {
                        FundiCardView(fundi: fundi)
                            .frame(width: 300)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
        }
    }

    private func featuredSection(_ fundis: [FundiSummary]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Featured Fundis")
                .font(.title3.bold())
                .foregroundStyle(Brand.ink)
                .padding(.horizontal)
            if fundis.isEmpty {
                Text("No featured fundis yet.")
                    .font(.subheadline)
                    .foregroundStyle(Brand.body)
                    .padding(.horizontal)
            } else {
                fundiRow(fundis)
            }
        }
    }

    private func recentSection(_ fundis: [FundiSummary]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recently Joined")
                .font(.title3.bold())
                .foregroundStyle(Brand.ink)
                .padding(.horizontal)
            if fundis.isEmpty {
                Text("No fundis yet.")
                    .font(.subheadline)
                    .foregroundStyle(Brand.body)
                    .padding(.horizontal)
            } else {
                fundiRow(fundis)
            }
        }
    }

    private func statsSection(_ stats: HomeStats) -> some View {
        HStack(spacing: 0) {
            statCell(value: "\(stats.workers)", label: "Fundis")
            statCell(value: "\(stats.reviews)", label: "Reviews")
            statCell(value: "\(stats.categories)", label: "Trades")
            statCell(value: "\(stats.estatesCount)", label: "Estates")
        }
        .padding(.vertical, 16)
        .background(Brand.primary)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal)
    }

    private func statCell(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.title3.bold())
                .foregroundStyle(.white)
            Text(label)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.85))
        }
        .frame(maxWidth: .infinity)
    }

    private func testimonialsSection(_ reviews: [Review]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("What Customers Say")
                .font(.title3.bold())
                .foregroundStyle(Brand.ink)
            ForEach(reviews) { review in
                VStack(alignment: .leading, spacing: 6) {
                    RatingStarsView(rating: Double(review.rating))
                    Text(review.comment)
                        .font(.subheadline)
                        .foregroundStyle(Brand.body)
                    Text("— \(review.reviewerName)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Brand.ink)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(.horizontal)
    }

    private var howItWorksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("How It Works")
                .font(.title3.bold())
                .foregroundStyle(Brand.ink)
            howStep(number: 1, title: "Find your fundi", body: "Search by trade and estate, or browse the list.")
            howStep(number: 2, title: "Book or chat", body: "Book in the app, or message the fundi on WhatsApp.")
            howStep(number: 3, title: "Job done", body: "The fundi comes to you. You pay them directly.")
        }
        .padding(.horizontal)
    }

    private func howStep(number: Int, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.headline.bold())
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(Brand.primary)
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline).foregroundStyle(Brand.ink)
                Text(body).font(.subheadline).foregroundStyle(Brand.body)
            }
        }
    }

    private var coverageLink: some View {
        NavigationLink {
            CoverageView()
        } label: {
            HStack {
                Image(systemName: "map.fill")
                Text("See where we work")
                    .font(.headline)
                Spacer()
                Image(systemName: "chevron.right")
            }
            .foregroundStyle(Brand.primary)
            .padding(16)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding(.horizontal)
    }

    private func load() async {
        if home == nil { isLoading = true }
        errorMessage = nil
        do {
            async let homeTask = api.fetchHome()
            async let tradesTask = api.fetchTrades()
            async let estatesTask = api.fetchEstates()
            let (homeResult, tradesResult, estatesResult) = try await (homeTask, tradesTask, estatesTask)
            home = homeResult
            trades = tradesResult
            estates = estatesResult.scoped
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
