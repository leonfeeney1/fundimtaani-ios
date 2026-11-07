import SwiftUI

/// Fundi profile: photo, name + Verified badge, trade, estate, rating +
/// breakdown, reviews, rate, experience, bio, certifications, operating
/// hours, WhatsApp + Book buttons. Loading the profile increments the
/// fundi's view count on the server (web behaviour, kept).
struct FundiDetailView: View {
    let fundiId: Int

    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var savedStore: SavedStore
    @State private var detail: FundiDetail?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showLogin = false

    private let api = APIClient.shared

    var body: some View {
        Group {
            if isLoading && detail == nil {
                LoadingView(message: "Loading fundi…")
            } else if let errorMessage, detail == nil {
                VStack(spacing: 12) {
                    ErrorBannerView(message: errorMessage) { Task { await load() } }
                        .padding()
                    Spacer()
                }
            } else if let detail {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        headerSection(detail)
                        actionSection(detail)
                        aboutSection(detail)
                        ratingSection(detail)
                        reviewsSection(detail)
                    }
                    .padding(.bottom, 24)
                }
            }
        }
        .navigationTitle(detail?.name ?? "Fundi")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if let detail {
                    Button {
                        savedStore.toggle(detailSummary(detail))
                    } label: {
                        Image(systemName: savedStore.isSaved(detail.id) ? "heart.fill" : "heart")
                            .foregroundStyle(savedStore.isSaved(detail.id) ? .red : Brand.primary)
                    }
                    .accessibilityLabel(savedStore.isSaved(detail.id) ? "Remove from saved" : "Save this fundi")
                }
            }
        }
        .sheet(isPresented: $showLogin) {
            NavigationStack { LoginView() }
        }
        .task { await load() }
    }

    private func detailSummary(_ detail: FundiDetail) -> FundiSummary {
        FundiSummary(
            id: detail.id, name: detail.name, trade: detail.trade,
            estate: detail.estate, rate: detail.rate, experience: detail.experience,
            rating: detail.rating, reviewCount: detail.reviewCount, featured: detail.featured,
            availableToday: detail.availableToday, emergencyReady: detail.emergencyReady,
            verified: detail.verified, photoURL: detail.photoURL, whatsappLink: detail.whatsappLink
        )
    }

    private func headerSection(_ detail: FundiDetail) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 16) {
                FundiPhotoView(fundi: detailSummary(detail), size: 96)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(detail.name)
                            .font(.title2.bold())
                            .foregroundStyle(Brand.ink)
                        if detail.verified {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundStyle(Brand.primary)
                                .accessibilityLabel("Verified fundi")
                        }
                    }
                    Text("\(detail.trade.name) · \(detail.estate)")
                        .font(.subheadline)
                        .foregroundStyle(Brand.body)
                    HStack(spacing: 8) {
                        RatingStarsView(rating: detail.rating)
                        Text("(\(detail.reviewCount) reviews)")
                            .font(.caption)
                            .foregroundStyle(Brand.body)
                    }
                    if !detail.rate.isEmpty {
                        Text(detail.rate)
                            .font(.headline)
                            .foregroundStyle(Brand.primary)
                    }
                }
            }
            HStack(spacing: 16) {
                if !detail.experience.isEmpty {
                    Label(detail.experience, systemImage: "briefcase.fill")
                }
                if detail.availableToday {
                    Label("Available today", systemImage: "clock.fill")
                        .foregroundStyle(Brand.primary)
                }
                if detail.emergencyReady {
                    Label("Emergency ready", systemImage: "bolt.fill")
                        .foregroundStyle(Brand.accent)
                }
            }
            .font(.caption)
            .foregroundStyle(Brand.body)
            if !detail.operatingHours.isEmpty {
                Label(detail.operatingHours, systemImage: "clock")
                    .font(.caption)
                    .foregroundStyle(Brand.body)
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    private func actionSection(_ detail: FundiDetail) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                if appState.isSignedIn {
                    NavigationLink {
                        BookingFormView(fundi: detailSummary(detail))
                    } label: {
                        Label("Book this fundi", systemImage: "calendar.badge.plus")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Brand.primary)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                } else {
                    Button {
                        showLogin = true
                    } label: {
                        Label("Sign in to book", systemImage: "calendar.badge.plus")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Brand.primary)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                if let url = URL(string: detail.whatsappLink) {
                    Link(destination: url) {
                        Label("WhatsApp", systemImage: "message.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Brand.whatsapp)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
            if !appState.isSignedIn {
                Text("Booking needs an account — WhatsApp works for everyone.")
                    .font(.caption)
                    .foregroundStyle(Brand.body)
            }
        }
        .padding(.horizontal)
    }

    private func aboutSection(_ detail: FundiDetail) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("About")
                .font(.title3.bold())
                .foregroundStyle(Brand.ink)
            if !detail.bio.isEmpty {
                Text(detail.bio)
                    .font(.body)
                    .foregroundStyle(Brand.body)
            } else {
                Text("No bio yet.")
                    .font(.body)
                    .foregroundStyle(Brand.body)
            }
            if !detail.certifications.isEmpty {
                FlowChips(
                    items: detail.certifications.map { badge in
                        (badge.name, Brand.tradeSymbol(for: badge.icon))
                    }
                )
            }
        }
        .padding(.horizontal)
    }

    private func ratingSection(_ detail: FundiDetail) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Ratings")
                .font(.title3.bold())
                .foregroundStyle(Brand.ink)
            HStack(spacing: 16) {
                VStack {
                    Text(Display.ratingText(detail.rating))
                        .font(.largeTitle.bold())
                        .foregroundStyle(Brand.ink)
                    RatingStarsView(rating: detail.rating, showText: false)
                    Text("\(detail.reviewCount) reviews")
                        .font(.caption)
                        .foregroundStyle(Brand.body)
                }
                VStack(spacing: 6) {
                    ForEach([5, 4, 3, 2, 1], id: \.self) { star in
                        HStack(spacing: 8) {
                            Text("\(star)")
                                .font(.caption)
                                .foregroundStyle(Brand.body)
                                .frame(width: 12)
                            ProgressView(value: Double(detail.ratingBreakdown.percentages["\(star)"] ?? 0), total: 100)
                                .tint(Brand.accent)
                            Text("\(detail.ratingBreakdown.counts["\(star)"] ?? 0)")
                                .font(.caption)
                                .foregroundStyle(Brand.body)
                                .frame(width: 24, alignment: .trailing)
                        }
                    }
                }
            }
        }
        .padding(.horizontal)
    }

    private func reviewsSection(_ detail: FundiDetail) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Reviews")
                .font(.title3.bold())
                .foregroundStyle(Brand.ink)
            if detail.reviews.isEmpty {
                Text("No reviews yet.")
                    .font(.subheadline)
                    .foregroundStyle(Brand.body)
            } else {
                ForEach(detail.reviews) { review in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(review.reviewerName)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Brand.ink)
                            Spacer()
                            RatingStarsView(rating: Double(review.rating))
                        }
                        if !review.comment.isEmpty {
                            Text(review.comment)
                                .font(.subheadline)
                                .foregroundStyle(Brand.body)
                        }
                        HStack(spacing: 8) {
                            Text(Display.shortDate(review.createdAt))
                                .font(.caption)
                                .foregroundStyle(Brand.body)
                            if review.verifiedBooking {
                                Label("Verified booking", systemImage: "checkmark.seal.fill")
                                    .font(.caption)
                                    .foregroundStyle(Brand.primary)
                            }
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .padding(.horizontal)
    }

    private func load() async {
        if detail == nil { isLoading = true }
        errorMessage = nil
        do {
            detail = try await api.fetchFundiDetail(fundiId)
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

/// Simple wrapping chips (name + icon), used for certification badges.
struct FlowChips: View {
    let items: [(String, String)]

    var body: some View {
        // A plain vertical stack of chips keeps layout predictable on
        // narrow screens; the list is short (certifications).
        VStack(alignment: .leading, spacing: 6) {
            ForEach(items, id: \.0) { name, symbol in
                Label(name, systemImage: symbol)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Brand.primary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Brand.primary.opacity(0.1))
                    .clipShape(Capsule())
            }
        }
    }
}
