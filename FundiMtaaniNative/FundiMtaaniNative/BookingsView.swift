import SwiftUI

/// My bookings: the customer's own bookings, newest first, filterable
/// by status. Tapping one shows the detail (fundi + dispute case
/// status when one exists). Signed-out users are routed to login.
struct BookingsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var bookings: [Booking] = []
    @State private var selectedStatus = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showLogin = false

    private let api = APIClient.shared
    private let statuses = ["", "requested", "confirmed", "in_progress", "completed", "cancelled"]

    var body: some View {
        Group {
            if !appState.isSignedIn {
                signInPrompt
            } else if isLoading && bookings.isEmpty {
                LoadingView(message: "Loading your bookings…")
            } else if let errorMessage, bookings.isEmpty {
                VStack(spacing: 12) {
                    ErrorBannerView(message: errorMessage) { Task { await load() } }
                        .padding()
                    Spacer()
                }
            } else if bookings.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "calendar")
                        .font(.largeTitle)
                        .foregroundStyle(Brand.body)
                    Text("No bookings yet")
                        .font(.headline)
                        .foregroundStyle(Brand.ink)
                    Text("Book a fundi and it will show up here.")
                        .font(.subheadline)
                        .foregroundStyle(Brand.body)
                    Spacer()
                }
                .padding()
            } else {
                List {
                    ForEach(bookings) { booking in
                        NavigationLink(value: booking) {
                            bookingRow(booking)
                        }
                    }
                }
                .listStyle(.plain)
                .refreshable { await load() }
            }
        }
        .navigationTitle("My Bookings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Picker("Status", selection: $selectedStatus) {
                    Text("All").tag("")
                    Text("Requested").tag("requested")
                    Text("Confirmed").tag("confirmed")
                    Text("In progress").tag("in_progress")
                    Text("Completed").tag("completed")
                    Text("Cancelled").tag("cancelled")
                }
                .pickerStyle(.menu)
            }
        }
        .navigationDestination(for: Booking.self) { booking in
            BookingDetailView(bookingId: booking.id)
        }
        .sheet(isPresented: $showLogin) {
            NavigationStack { LoginView() }
        }
        .task { await load() }
        .onChange(of: selectedStatus) { Task { await load() } }
        .onChange(of: appState.user) { Task { await load() } }
    }

    private var signInPrompt: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 56))
                .foregroundStyle(Brand.body)
            Text("Sign in to see your bookings")
                .font(.title3.bold())
                .foregroundStyle(Brand.ink)
            Text("Bookings need an account, so we can keep them tied to you.")
                .font(.body)
                .foregroundStyle(Brand.body)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button("Sign in") { showLogin = true }
                .buttonStyle(.borderedProminent)
                .tint(Brand.primary)
            Spacer()
        }
    }

    private func bookingRow(_ booking: Booking) -> some View {
        HStack(spacing: 12) {
            Image(systemName: Display.statusSymbol(booking.status))
                .foregroundStyle(Brand.primary)
                .font(.title3)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 4) {
                Text(booking.worker?.name ?? "Fundi")
                    .font(.headline)
                    .foregroundStyle(Brand.ink)
                    .lineLimit(1)
                Text("\(booking.preferredDate) · \(booking.preferredSlot)")
                    .font(.caption)
                    .foregroundStyle(Brand.body)
                    .lineLimit(1)
                if !booking.priceEstimate.isEmpty {
                    Text(booking.priceEstimate)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Brand.primary)
                }
            }
            Spacer()
            Text(booking.statusLabel)
                .font(.caption2.bold())
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(statusColor(booking.status))
                .clipShape(Capsule())
        }
        .padding(.vertical, 4)
    }

    private func statusColor(_ status: String) -> Color {
        switch status {
        case "requested": return Brand.accent
        case "confirmed": return Brand.primary
        case "in_progress": return Color(hex: "2563EB")
        case "completed": return Brand.primaryDark
        case "cancelled": return Color(hex: "DC2626")
        default: return Brand.body
        }
    }

    private func load() async {
        guard appState.isSignedIn else { return }
        if bookings.isEmpty { isLoading = true }
        errorMessage = nil
        do {
            let (results, _) = try await api.fetchBookings(status: selectedStatus.isEmpty ? nil : selectedStatus)
            bookings = results
        } catch let error as APIError {
            if error.isSiteUnavailable {
                await appState.noteSiteUnavailable()
            } else if case .unauthorized = error {
                await appState.refreshSession()
            } else {
                errorMessage = error.localizedDescription
            }
        } catch {
            errorMessage = APIErrorAlert.message(for: error)
        }
        isLoading = false
    }
}

/// One booking: fundi, date, slot, message, price, status, and the
/// dispute case status when a case exists for it.
struct BookingDetailView: View {
    let bookingId: Int

    @EnvironmentObject private var appState: AppState
    @State private var booking: Booking?
    @State private var isLoading = false
    @State private var errorMessage: String?

    private let api = APIClient.shared

    var body: some View {
        Group {
            if isLoading && booking == nil {
                LoadingView(message: "Loading booking…")
            } else if let errorMessage, booking == nil {
                VStack(spacing: 12) {
                    ErrorBannerView(message: errorMessage) { Task { await load() } }
                        .padding()
                    Spacer()
                }
            } else if let booking {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        if let worker = booking.worker {
                            NavigationLink(value: FundiSummary(
                                id: worker.id, name: worker.name, trade: worker.trade,
                                estate: worker.estate, rate: "", experience: "",
                                rating: nil, reviewCount: 0, featured: false,
                                availableToday: false, emergencyReady: false,
                                verified: false, photoURL: worker.photoURL, whatsappLink: ""
                            )) {
                                HStack(spacing: 12) {
                                    if let url = Brand.absolutePhotoURL(worker.photoURL) {
                                        AsyncImage(url: url) { phase in
                                            switch phase {
                                            case .success(let image): image.resizable().scaledToFill()
                                            default: Color(.secondarySystemBackground)
                                            }
                                        }
                                        .frame(width: 56, height: 56)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                    }
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(worker.name)
                                            .font(.headline)
                                            .foregroundStyle(Brand.ink)
                                        Text("\(worker.trade.name) · \(worker.estate)")
                                            .font(.subheadline)
                                            .foregroundStyle(Brand.body)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundStyle(Brand.body)
                                }
                                .padding(12)
                                .background(Color(.secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .buttonStyle(.plain)
                        }
                        detailRows(booking)
                        if let dispute = booking.dispute {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Dispute")
                                    .font(.title3.bold())
                                    .foregroundStyle(Brand.ink)
                                Text("This booking has a dispute case: \(dispute.status).")
                                    .font(.subheadline)
                                    .foregroundStyle(Brand.body)
                                Text("Opened \(Display.shortDate(dispute.createdAt))")
                                    .font(.caption)
                                    .foregroundStyle(Brand.body)
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("Booking")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: FundiSummary.self) { fundi in
            FundiDetailView(fundiId: fundi.id)
        }
        .task { await load() }
    }

    private func detailRows(_ booking: Booking) -> some View {
        VStack(spacing: 0) {
            detailRow(label: "Status", value: booking.statusLabel)
            detailRow(label: "Date", value: booking.preferredDate)
            detailRow(label: "Time", value: booking.preferredSlot)
            detailRow(label: "Estimate", value: booking.priceEstimate)
            if !booking.agreedPrice.isEmpty {
                detailRow(label: "Agreed price", value: booking.agreedPrice)
            }
            if !booking.message.isEmpty {
                detailRow(label: "Message", value: booking.message)
            }
            detailRow(label: "Booked", value: Display.shortDate(booking.createdAt))
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func detailRow(label: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(Brand.body)
                .frame(width: 110, alignment: .leading)
            Text(value)
                .font(.subheadline)
                .foregroundStyle(Brand.ink)
                .multilineTextAlignment(.leading)
            Spacer()
        }
        .padding(.vertical, 4)
    }

    private func load() async {
        if booking == nil { isLoading = true }
        errorMessage = nil
        do {
            booking = try await api.fetchBooking(bookingId)
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
