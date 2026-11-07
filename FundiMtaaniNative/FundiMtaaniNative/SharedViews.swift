import SwiftUI

/// Shared building blocks: loading state, fundi cards, star ratings,
/// photo loading, and the small error presentation every screen uses.

struct LoadingView: View {
    var message: String = "Loading…"

    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text(message)
                .font(.subheadline)
                .foregroundStyle(Brand.body)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

/// A fundi photo from the API (relative "/photos/workers/..." URLs are
/// made absolute in Brand). Falls back to a trade icon tile.
struct FundiPhotoView: View {
    let fundi: FundiSummary
    var size: CGFloat = 64

    var body: some View {
        Group {
            if let url = Brand.absolutePhotoURL(fundi.photoURL) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .failure, .empty:
                        tradeTile
                    @unknown default:
                        tradeTile
                    }
                }
            } else {
                tradeTile
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var tradeTile: some View {
        ZStack {
            Brand.primary
            Image(systemName: Brand.tradeSymbol(for: fundi.trade.slug))
                .font(.system(size: size * 0.4))
                .foregroundStyle(.white)
        }
    }
}

struct RatingStarsView: View {
    let rating: Double?
    var showText: Bool = true

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: "star.fill")
                .foregroundStyle(Brand.accentBright)
                .font(.caption)
            if showText {
                Text(Display.ratingText(rating))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Brand.ink)
            }
        }
    }
}

struct FundiCardView: View {
    let fundi: FundiSummary

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            FundiPhotoView(fundi: fundi, size: 64)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(fundi.name)
                        .font(.headline)
                        .foregroundStyle(Brand.ink)
                        .lineLimit(1)
                    if fundi.verified {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(Brand.primary)
                            .font(.caption)
                            .accessibilityLabel("Verified fundi")
                    }
                    if fundi.featured {
                        Text("Featured")
                            .font(.caption2.bold())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Brand.accent)
                            .clipShape(Capsule())
                    }
                }
                Text("\(fundi.trade.name) · \(fundi.estate)")
                    .font(.subheadline)
                    .foregroundStyle(Brand.body)
                    .lineLimit(1)
                HStack(spacing: 12) {
                    RatingStarsView(rating: fundi.rating)
                    Text("(\(fundi.reviewCount))")
                        .font(.caption)
                        .foregroundStyle(Brand.body)
                    if !fundi.rate.isEmpty {
                        Text(fundi.rate)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Brand.primary)
                            .lineLimit(1)
                    }
                }
                if fundi.availableToday {
                    Label("Available today", systemImage: "clock.fill")
                        .font(.caption)
                        .foregroundStyle(Brand.primary)
                }
            }
            Spacer()
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

/// A small banner for API errors, with a retry action when offered.
struct ErrorBannerView: View {
    let message: String
    var onRetry: (() -> Void)?

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Brand.accent)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(Brand.ink)
            Spacer()
            if let onRetry {
                Button("Retry", action: onRetry)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Brand.primary)
            }
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

/// Convenience: present an APIError as an alert, and hand
/// site_unavailable over to the AppState so the mode screen takes over.
struct APIErrorAlert {
    static func message(for error: Error) -> String {
        (error as? APIError)?.localizedDescription ?? error.localizedDescription
    }
}
