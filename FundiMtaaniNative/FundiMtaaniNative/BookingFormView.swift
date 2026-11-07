import SwiftUI

/// Booking form: preferred date, slot, message. Creates a Booking with
/// status `requested` and the fundi's rate as the price estimate. There
/// is no payment step anywhere — customers pay fundis directly.
///
/// DO-NOT-RETRY: the server creates a row on every call. The submit
/// button is disabled while a request is in flight, and a network
/// failure is shown as "unknown outcome — check My Bookings before
/// trying again" instead of silently re-posting.
struct BookingFormView: View {
    let fundi: FundiSummary

    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var date = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
    @State private var slot = "Morning (8:00 AM - 12:00 PM)"
    @State private var message = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var networkUnknown = false
    @State private var createdBooking: Booking?

    private let api = APIClient.shared
    private let slots = [
        "Morning (8:00 AM - 12:00 PM)",
        "Afternoon (12:00 PM - 4:00 PM)",
        "Evening (4:00 PM - 6:30 PM)",
        "Any Time",
    ]

    var body: some View {
        Group {
            if let createdBooking {
                confirmationSection(createdBooking)
            } else {
                formSection
            }
        }
        .navigationTitle("Book \(fundi.name)")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var formSection: some View {
        Form {
            Section {
                HStack(spacing: 12) {
                    FundiPhotoView(fundi: fundi, size: 56)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(fundi.name)
                            .font(.headline)
                            .foregroundStyle(Brand.ink)
                        Text("\(fundi.trade.name) · \(fundi.estate)")
                            .font(.subheadline)
                            .foregroundStyle(Brand.body)
                        if !fundi.rate.isEmpty {
                            Text(fundi.rate)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Brand.primary)
                        }
                    }
                }
            }
            Section("When") {
                DatePicker("Preferred date", selection: $date, in: Date()..., displayedComponents: .date)
                Picker("Time slot", selection: $slot) {
                    ForEach(slots, id: \.self) { slot in
                        Text(slot).tag(slot)
                    }
                }
            }
            Section("What needs doing?") {
                TextField("Describe the job (optional)", text: $message, axis: .vertical)
                    .lineLimit(4...)
            }
            if let errorMessage {
                Section {
                    ErrorBannerView(message: errorMessage)
                }
            }
            if networkUnknown {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("We couldn't confirm whether your booking went through.")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Brand.ink)
                        Text("Check My Bookings before trying again, so you don't book twice.")
                            .font(.subheadline)
                            .foregroundStyle(Brand.body)
                    }
                }
            }
            Section {
                Button {
                    Task { await submit() }
                } label: {
                    if isSubmitting {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Request booking")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(Brand.primary)
                .disabled(isSubmitting)
            } footer: {
                Text("The fundi will confirm your booking. You pay them directly — there is no payment in the app.")
            }
        }
    }

    private func confirmationSection(_ booking: Booking) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                Spacer(minLength: 32)
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(Brand.primary)
                Text("Booking requested")
                    .font(.title2.bold())
                    .foregroundStyle(Brand.ink)
                Text("\(fundi.name) will confirm your booking. You can follow it in My Bookings.")
                    .font(.body)
                    .foregroundStyle(Brand.body)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                VStack(alignment: .leading, spacing: 8) {
                    bookingRow(label: "Fundi", value: booking.worker?.name ?? fundi.name)
                    bookingRow(label: "Date", value: booking.preferredDate)
                    bookingRow(label: "Time", value: booking.preferredSlot)
                    bookingRow(label: "Estimate", value: booking.priceEstimate.isEmpty ? fundi.rate : booking.priceEstimate)
                    bookingRow(label: "Status", value: booking.statusLabel)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal)
                Button("Done") { dismiss() }
                    .buttonStyle(.borderedProminent)
                    .tint(Brand.primary)
                Spacer(minLength: 32)
            }
        }
    }

    private func bookingRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(Brand.body)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Brand.ink)
                .multilineTextAlignment(.trailing)
        }
    }

    private func submit() async {
        isSubmitting = true
        errorMessage = nil
        networkUnknown = false
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        let dateString = formatter.string(from: date)
        do {
            createdBooking = try await api.bookFundi(fundi.id, preferredDate: dateString, preferredSlot: slot, message: message)
        } catch let error as APIError {
            switch error {
            case .network:
                // The request may have landed. Never re-post blindly.
                networkUnknown = true
            case .unauthorized:
                errorMessage = "Your session expired. Please sign in again."
            case .siteUnavailable:
                await appState.noteSiteUnavailable()
            default:
                errorMessage = error.localizedDescription
            }
        } catch {
            errorMessage = APIErrorAlert.message(for: error)
        }
        isSubmitting = false
    }
}
