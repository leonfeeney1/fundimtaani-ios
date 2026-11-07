import Foundation

/// Errors the API client can surface. Every one maps to a real server
/// behaviour in `api_v1.py` — the client never invents an error shape.
enum APIError: Error, LocalizedError {
    case siteUnavailable(siteStatus: String?)
    case unauthorized
    case forbidden
    case validation(message: String, fields: [String: String]?)
    case notFound
    case rateLimited(retryAfter: Int)
    case server(message: String)
    case network
    case decoding

    var errorDescription: String? {
        switch self {
        case .siteUnavailable:
            return "FundiMtaani is not live right now."
        case .unauthorized:
            return "Please sign in to continue."
        case .forbidden:
            return "Your account cannot use this feature."
        case .validation(let message, _):
            return message
        case .notFound:
            return "That could not be found."
        case .rateLimited(let seconds):
            let minutes = max(1, seconds / 60)
            return "Too many requests. Please try again in about \(minutes) minute\(minutes == 1 ? "" : "s")."
        case .server(let message):
            return message
        case .network:
            return "No connection. Check your internet and try again."
        case .decoding:
            return "The server sent something unexpected. Please try again."
        }
    }

    /// True when the app should re-check the site mode (the gate closed
    /// under us) instead of showing a plain error.
    var isSiteUnavailable: Bool {
        if case .siteUnavailable = self { return true }
        return false
    }
}

struct HealthPayload: Decodable {
    let ok: Bool
    let db: String
}

struct CoveragePayload: Decodable {
    let zones: [EstateZone]
}

struct MePayload: Decodable {
    let user: User
}

struct NextPayload: Decodable {
    let next: String
}

struct MessagePayload: Decodable {
    let message: String
}

struct FundiFilter {
    var category: String = ""
    var estate: String = ""
    var query: String = ""
    var emergencyOnly: Bool = false
    var availableTodayOnly: Bool = false
    var minRating: Double = 0
    var sort: String = "featured"
    var limit: Int = 50
    var offset: Int = 0

    var isEmpty: Bool {
        category.isEmpty && estate.isEmpty && query.isEmpty
            && !emergencyOnly && !availableTodayOnly && minRating == 0
    }
}

/// The FundiMtaani JSON API client (Phase 1, 24 endpoints).
///
/// Auth is the same Flask session cookie as the website: the session
/// uses the shared cookie storage, so the cookie set by a login POST is
/// sent automatically on every later call and survives app restarts.
/// The client never clears cookies. The customer app and the admin app
/// are separate apps with separate cookie jars, matching the web rule
/// that one session wipes the other.
final class APIClient {
    static let shared = APIClient()

    private let session: URLSession
    private let decoder = JSONDecoder()

    init(session: URLSession? = nil) {
        if let session {
            self.session = session
        } else {
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = 30
            config.httpShouldSetCookies = true
            config.httpCookieAcceptPolicy = .always
            self.session = URLSession(configuration: config)
        }
    }

    // MARK: - Core request

    private func request<T: Decodable>(
        _ path: String,
        method: String = "GET",
        body: [String: Any]? = nil,
        query: [URLQueryItem] = []
    ) async throws -> (T, PageMeta?) {
        var components = URLComponents(url: Brand.apiBaseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        if !query.isEmpty { components.queryItems = query }
        guard let url = components.url else { throw APIError.network }
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = method
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body)
        } else if method != "GET" {
            // Mutating calls must be JSON (the server 400s otherwise),
            // even when they carry no fields.
            urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            urlRequest.httpBody = try JSONSerialization.data(withJSONObject: [:])
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch {
            throw APIError.network
        }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0

        guard let envelope = try? decoder.decode(Envelope<T>.self, from: data) else {
            if status == 401 { throw APIError.unauthorized }
            if status == 404 { throw APIError.notFound }
            throw APIError.server(message: "The server returned an unexpected response (\(status)).")
        }
        if envelope.ok, let payload = envelope.data {
            return (payload, envelope.meta)
        }
        let error = envelope.error
        switch status {
        case 401:
            throw APIError.unauthorized
        case 403:
            throw APIError.forbidden
        case 404:
            throw APIError.notFound
        case 409, 400:
            throw APIError.validation(message: error?.message ?? "Please check the details and try again.", fields: error?.fields)
        case 429:
            throw APIError.rateLimited(retryAfter: error?.retryAfterSeconds ?? 60)
        case 503 where error?.code == "site_unavailable":
            throw APIError.siteUnavailable(siteStatus: error?.siteStatus)
        default:
            throw APIError.server(message: error?.message ?? "Something went wrong (\(status)). Please try again.")
        }
    }

    private func get<T: Decodable>(_ path: String, query: [URLQueryItem] = []) async throws -> (T, PageMeta?) {
        try await request(path, method: "GET", query: query)
    }

    private func post<T: Decodable>(_ path: String, body: [String: Any]? = nil) async throws -> T {
        let (payload, _): (T, PageMeta?) = try await request(path, method: "POST", body: body)
        return payload
    }

    // MARK: - Public: mode, home, discovery (#1-10)

    func fetchStatus() async throws -> SiteStatusPayload {
        let (payload, _): (SiteStatusPayload, PageMeta?) = try await get("status")
        return payload
    }

    func fetchHealth() async throws -> HealthPayload {
        let (payload, _): (HealthPayload, PageMeta?) = try await get("health")
        return payload
    }

    func fetchHome() async throws -> HomePayload {
        let (payload, _): (HomePayload, PageMeta?) = try await get("home")
        return payload
    }

    func fetchTrades() async throws -> [Trade] {
        let (payload, _): ([Trade], PageMeta?) = try await get("trades")
        return payload
    }

    func fetchEstates(zone: String? = nil) async throws -> EstatesPayload {
        var query: [URLQueryItem] = []
        if let zone, !zone.isEmpty { query.append(URLQueryItem(name: "zone", value: zone)) }
        let (payload, _): (EstatesPayload, PageMeta?) = try await get("estates", query: query)
        return payload
    }

    func fetchCoverage() async throws -> CoveragePayload {
        let (payload, _): (CoveragePayload, PageMeta?) = try await get("coverage")
        return payload
    }

    func fetchFundis(_ filter: FundiFilter) async throws -> ([FundiSummary], PageMeta?) {
        var query: [URLQueryItem] = [
            URLQueryItem(name: "limit", value: String(filter.limit)),
            URLQueryItem(name: "offset", value: String(filter.offset)),
            URLQueryItem(name: "sort", value: filter.sort),
        ]
        if !filter.category.isEmpty { query.append(URLQueryItem(name: "category", value: filter.category)) }
        if !filter.estate.isEmpty { query.append(URLQueryItem(name: "estate", value: filter.estate)) }
        if !filter.query.isEmpty { query.append(URLQueryItem(name: "q", value: filter.query)) }
        if filter.emergencyOnly { query.append(URLQueryItem(name: "emergency", value: "1")) }
        if filter.availableTodayOnly { query.append(URLQueryItem(name: "available_today", value: "1")) }
        if filter.minRating > 0 { query.append(URLQueryItem(name: "min_rating", value: String(filter.minRating))) }
        return try await get("fundis", query: query)
    }

    func fetchFundiDetail(_ id: Int) async throws -> FundiDetail {
        let (payload, _): (FundiDetail, PageMeta?) = try await get("fundis/\(id)")
        return payload
    }

    func fetchFundiReviews(_ id: Int, limit: Int = 50, offset: Int = 0) async throws -> ([Review], PageMeta?) {
        try await get("fundis/\(id)/reviews", query: [
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "offset", value: String(offset)),
        ])
    }

    func suggest(_ q: String) async throws -> SuggestPayload {
        let (payload, _): (SuggestPayload, PageMeta?) = try await get("suggest", query: [
            URLQueryItem(name: "q", value: q),
        ])
        return payload
    }

    // MARK: - Auth (#13-22)

    func signup(name: String, phone: String, email: String, password: String, role: String) async throws -> SignupPayload {
        try await post("auth/signup", body: [
            "name": name,
            "phone": phone,
            "email": email,
            "password": password,
            "confirm_password": password,
            "role": role,
            "age_confirm": true,
            "tos_accept": true,
        ])
    }

    func login(identifier: String, password: String) async throws -> LoginPayload {
        try await post("auth/login", body: [
            "identifier": identifier,
            "password": password,
        ])
    }

    func requestLoginCode(email: String) async throws -> NextPayload {
        try await post("auth/login-code/request", body: ["email": email])
    }

    func verifyLoginCode(_ code: String) async throws -> LoginPayload {
        try await post("auth/login-code/verify", body: ["code": code])
    }

    func verifyCode(_ code: String) async throws -> LoginPayload {
        try await post("auth/verify/code", body: ["code": code])
    }

    func resendVerification(email: String? = nil) async throws -> ResendPayload {
        var body: [String: Any] = [:]
        if let email, !email.isEmpty { body["email"] = email }
        return try await post("auth/verify/resend", body: body)
    }

    func forgotPassword(email: String) async throws -> MessagePayload {
        try await post("auth/forgot-password", body: ["email": email])
    }

    func resetPassword(token: String, password: String) async throws -> ResetPayload {
        try await post("auth/reset-password/\(token)", body: [
            "password": password,
            "confirm_password": password,
        ])
    }

    func fetchMe() async throws -> User {
        let (payload, _): (MePayload, PageMeta?) = try await get("auth/me")
        return payload.user
    }

    func logout() async throws {
        let _: EmptyData = try await post("auth/logout")
    }

    // MARK: - Customer bookings (#23-26)

    func fetchDashboard() async throws -> DashboardPayload {
        let (payload, _): (DashboardPayload, PageMeta?) = try await get("me/dashboard")
        return payload
    }

    func fetchBookings(status: String? = nil, limit: Int = 50, offset: Int = 0) async throws -> ([Booking], PageMeta?) {
        var query: [URLQueryItem] = [
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "offset", value: String(offset)),
        ]
        if let status, !status.isEmpty { query.append(URLQueryItem(name: "status", value: status)) }
        return try await get("me/bookings", query: query)
    }

    func fetchBooking(_ id: Int) async throws -> Booking {
        let (payload, _): (Booking, PageMeta?) = try await get("me/bookings/\(id)")
        return payload
    }

    /// Creates a booking. Callers must NOT retry blindly on a network
    /// failure — the server creates a row on every call. On failure,
    /// re-check My Bookings first (see BookingFormView).
    func bookFundi(_ id: Int, preferredDate: String, preferredSlot: String, message: String) async throws -> Booking {
        let payload: BookingCreatedPayload = try await post("fundis/\(id)/book", body: [
            "preferred_date": preferredDate,
            "preferred_slot": preferredSlot,
            "message": message,
        ])
        return payload.booking
    }
}
