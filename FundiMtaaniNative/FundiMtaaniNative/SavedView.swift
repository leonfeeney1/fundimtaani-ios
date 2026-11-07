import SwiftUI

/// Saved fundis — app-local only in v1. There is no server model for
/// saved fundis (the website keeps them in localStorage), so the app
/// stores the fundi summaries on the device. Cross-device saved needs
/// the new SavedFundi model (Phase 2, audit endpoints #32-34).
@MainActor
final class SavedStore: ObservableObject {
    @Published private(set) var saved: [FundiSummary] = []

    private let key = "fundimtaani.savedFundis"

    init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode([FundiSummary].self, from: data) {
            saved = decoded
        }
    }

    func isSaved(_ id: Int) -> Bool {
        saved.contains { $0.id == id }
    }

    func toggle(_ fundi: FundiSummary) {
        if isSaved(fundi.id) {
            saved.removeAll { $0.id == fundi.id }
        } else {
            saved.append(fundi)
        }
        persist()
    }

    func remove(_ fundi: FundiSummary) {
        saved.removeAll { $0.id == fundi.id }
        persist()
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(saved) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}

struct SavedView: View {
    @EnvironmentObject private var savedStore: SavedStore

    var body: some View {
        Group {
            if savedStore.saved.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "heart")
                        .font(.largeTitle)
                        .foregroundStyle(Brand.body)
                    Text("No saved fundis yet")
                        .font(.headline)
                        .foregroundStyle(Brand.ink)
                    Text("Tap the heart on a fundi's profile to save them here.")
                        .font(.subheadline)
                        .foregroundStyle(Brand.body)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                    Spacer()
                }
            } else {
                List {
                    ForEach(savedStore.saved) { fundi in
                        NavigationLink(value: fundi) {
                            FundiCardView(fundi: fundi)
                        }
                        .buttonStyle(.plain)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                        .swipeActions {
                            Button(role: .destructive) {
                                savedStore.remove(fundi)
                            } label: {
                                Label("Remove", systemImage: "trash")
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Saved")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: FundiSummary.self) { fundi in
            FundiDetailView(fundiId: fundi.id)
        }
    }
}
