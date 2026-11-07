import Foundation

/// Codable models for the FundiMtaani JSON API (Phase 1, commit 504b27c).
/// Field names and shapes are taken from `api_v1.py` in
/// backend-phase1 — nothing invented. The envelope is uniform:
/// success `{ok: true, data: ...}` (lists also carry `meta`), error
/// `{ok: false, error: {code, message, ...}}`. Timestamps are ISO 8601
/// UTC strings. Money (`rate`, `price_estimate`, `agreed_price`) is free
/// text, displayed never parsed.

struct APIErrorBody: Codable {
    let code: String
    let message: String
    let retryAfterSeconds: Int?
    let attemptsLeft: Int?
    let fields: [String: String]?
    let siteStatus: String?

    enum CodingKeys: String, CodingKey {
        case code, message, fields
        case retryAfterSeconds = "retry_after_seconds"
        case attemptsLeft = "attempts_left"
        case siteStatus = "site_status"
    }
}

struct PageMeta: Codable {
    let total: Int
    let limit: Int
    let offset: Int
    let detectedTrade: String?
    let detectedTradeSlug: String?

    enum CodingKeys: String, CodingKey {
        case total, limit, offset
        case detectedTrade = "detected_trade"
        case detectedTradeSlug = "detected_trade_slug"
    }
}

struct Envelope<T: Decodable>: Decodable {
    let ok: Bool
    let data: T?
    let error: APIErrorBody?
    let meta: PageMeta?
}

struct EmptyData: Decodable {}

struct SiteStatusPayload: Codable {
    let siteStatus: String
    let announcementEnabled: Bool
    let announcementText: String
    let supportPhone: String
    let supportEmail: String
    let supportWhatsapp: String
    let launchedEstates: [String]

    enum CodingKeys: String, CodingKey {
        case siteStatus = "site_status"
        case announcementEnabled = "announcement_enabled"
        case announcementText = "announcement_text"
        case supportPhone = "support_phone"
        case supportEmail = "support_email"
        case supportWhatsapp = "support_whatsapp"
        case launchedEstates = "launched_estates"
    }
}

struct Trade: Codable, Hashable, Identifiable {
    let id: Int
    let name: String
    let slug: String
    let icon: String
    let blurb: String
}

struct EstateZone: Codable, Hashable, Identifiable {
    let id: String
    let zone: String
    let badge: String
    let description: String
    let estates: [String]
}

struct EstatesPayload: Codable {
    let zones: [EstateZone]
    let scoped: [String]
}

struct FundiTrade: Codable, Hashable {
    let slug: String
    let name: String
}

struct FundiSummary: Codable, Hashable, Identifiable {
    let id: Int
    let name: String
    let trade: FundiTrade
    let estate: String
    let rate: String
    let experience: String
    let rating: Double?
    let reviewCount: Int
    let featured: Bool
    let availableToday: Bool
    let emergencyReady: Bool
    let verified: Bool
    let photoURL: String?
    let whatsappLink: String

    enum CodingKeys: String, CodingKey {
        case id, name, trade, estate, rate, experience, rating, featured, verified
        case reviewCount = "review_count"
        case availableToday = "available_today"
        case emergencyReady = "emergency_ready"
        case photoURL = "photo_url"
        case whatsappLink = "whatsapp_link"
    }
}

struct CertificationBadge: Codable, Hashable {
    let name: String
    let icon: String
}

struct RatingBreakdown: Codable {
    let counts: [String: Int]
    let percentages: [String: Int]
    let total: Int
}

struct Review: Codable, Hashable, Identifiable {
    let id: Int
    let reviewerName: String
    let rating: Int
    let comment: String
    let verifiedBooking: Bool
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id, rating, comment
        case reviewerName = "reviewer_name"
        case verifiedBooking = "verified_booking"
        case createdAt = "created_at"
    }
}

struct FundiDetail: Codable, Identifiable {
    let id: Int
    let name: String
    let trade: FundiTrade
    let estate: String
    let rate: String
    let experience: String
    let rating: Double?
    let reviewCount: Int
    let featured: Bool
    let availableToday: Bool
    let emergencyReady: Bool
    let verified: Bool
    let photoURL: String?
    let whatsappLink: String
    let bio: String
    let certifications: [CertificationBadge]
    let operatingHours: String
    let views: Int
    let ratingBreakdown: RatingBreakdown
    let reviews: [Review]

    enum CodingKeys: String, CodingKey {
        case id, name, trade, estate, rate, experience, rating, featured, verified, bio, certifications, views, reviews
        case reviewCount = "review_count"
        case availableToday = "available_today"
        case emergencyReady = "emergency_ready"
        case photoURL = "photo_url"
        case whatsappLink = "whatsapp_link"
        case operatingHours = "operating_hours"
        case ratingBreakdown = "rating_breakdown"
    }
}

struct SuggestTrade: Codable, Hashable {
    let slug: String
    let name: String
    let blurb: String
}

struct SuggestFundi: Codable, Hashable, Identifiable {
    let id: Int
    let name: String
    let trade: String
    let estate: String
    let photoURL: String?
    let url: String

    enum CodingKeys: String, CodingKey {
        case id, name, trade, estate, url
        case photoURL = "photo_url"
    }
}

struct SuggestPayload: Codable {
    let trades: [SuggestTrade]
    let fundis: [SuggestFundi]
}

struct HomeStats: Codable {
    let workers: Int
    let reviews: Int
    let categories: Int
    let estatesCount: Int

    enum CodingKeys: String, CodingKey {
        case workers, reviews, categories
        case estatesCount = "estates_count"
    }
}

struct HomePayload: Codable {
    let featured: [FundiSummary]
    let recent: [FundiSummary]
    let stats: HomeStats
    let testimonials: [Review]
    let heroWorker: FundiSummary?

    enum CodingKeys: String, CodingKey {
        case featured, recent, stats, testimonials
        case heroWorker = "hero_worker"
    }
}

struct User: Codable, Hashable {
    let id: Int
    let name: String
    let phone: String
    let email: String?
    let emailVerified: Bool
    let role: String
    let isTechnician: Bool
    let workerId: Int?
    let joinStep: Int?

    enum CodingKeys: String, CodingKey {
        case id, name, phone, email, role
        case emailVerified = "email_verified"
        case isTechnician = "is_technician"
        case workerId = "worker_id"
        case joinStep = "join_step"
    }
}

/// Login / code-verify responses. The web's `next`/`redirect` target is
/// kept for parity; the app routes on `role` / `joinStep` instead.
struct LoginPayload: Codable {
    let user: User?
    let next: String?
    let redirect: String?
    let name: String?
    let message: String?
    let role: String?
    let isTechnician: Bool?
    let workerId: Int?
    let joinStep: Int?
    let resumeURL: String?

    enum CodingKeys: String, CodingKey {
        case user, next, redirect, name, message, role
        case isTechnician = "is_technician"
        case workerId = "worker_id"
        case joinStep = "join_step"
        case resumeURL = "resume_url"
    }
}

struct SignupPayload: Codable {
    let user: User
    let next: String
    let emailSent: Bool

    enum CodingKeys: String, CodingKey {
        case user, next
        case emailSent = "email_sent"
    }
}

struct BookingWorker: Codable, Hashable {
    let id: Int
    let name: String
    let trade: FundiTrade
    let estate: String
    let photoURL: String?

    enum CodingKeys: String, CodingKey {
        case id, name, trade, estate
        case photoURL = "photo_url"
    }
}

struct DisputeInfo: Codable, Hashable {
    let id: Int
    let status: String
    let createdAt: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id, status
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct Booking: Codable, Hashable, Identifiable {
    let id: Int
    let worker: BookingWorker?
    let clientName: String
    let clientPhone: String
    let preferredDate: String
    let preferredSlot: String
    let message: String
    let priceEstimate: String
    let agreedPrice: String
    let status: String
    let statusLabel: String
    let createdAt: String
    let updatedAt: String
    let dispute: DisputeInfo?

    enum CodingKeys: String, CodingKey {
        case id, worker, message, status, dispute
        case clientName = "client_name"
        case clientPhone = "client_phone"
        case preferredDate = "preferred_date"
        case preferredSlot = "preferred_slot"
        case priceEstimate = "price_estimate"
        case agreedPrice = "agreed_price"
        case statusLabel = "status_label"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct BookingCreatedPayload: Codable {
    let booking: Booking
}

struct DashboardPayload: Codable {
    let bookings: [Booking]
}

struct ResendPayload: Codable {
    let email: String
    let emailSent: Bool

    enum CodingKeys: String, CodingKey {
        case email
        case emailSent = "email_sent"
    }
}

struct ResetPayload: Codable {
    let next: String
    let email: String?
    let emailSent: Bool

    enum CodingKeys: String, CodingKey {
        case next, email
        case emailSent = "email_sent"
    }
}

/// Display helpers for server values.
enum Display {
    private static let iso = ISO8601DateFormatter()

    /// "2026-11-07T17:27:19Z" -> "7 Nov 2026". Falls back to the raw
    /// string (which is already human-shaped for preferred_date).
    static func shortDate(_ raw: String) -> String {
        guard let date = iso.date(from: raw) else { return raw }
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f.string(from: date)
    }

    static func ratingText(_ rating: Double?) -> String {
        guard let rating, rating > 0 else { return "New" }
        return String(format: "%.1f", rating)
    }

    /// Booking status -> SF Symbol, for the status chip.
    static func statusSymbol(_ status: String) -> String {
        switch status {
        case "requested": return "clock"
        case "confirmed": return "checkmark.circle"
        case "in_progress": return "hammer"
        case "completed": return "checkmark.seal.fill"
        case "cancelled": return "xmark.circle"
        default: return "circle"
        }
    }
}
