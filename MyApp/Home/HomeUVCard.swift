import SwiftUI

/// Home's "Current UV Index" card, or a prompt to choose a location if there isn't one yet.
struct HomeUVCard: View {
    @Environment(WeatherStore.self) private var weather
    @State private var isPickingLocation = false

    var body: some View {
        Group {
            if let location = weather.location {
                if let uv = weather.forecast?.uv(at: .now) {
                    UVIndexCard(title: "Current UV Index", reading: UVReading(uv: uv), caption: location.name)
                } else {
                    statusCard
                }
            } else {
                setLocationCard
            }
        }
        .sheet(isPresented: $isPickingLocation) { LocationPicker() }
    }

    /// Loading, or couldn't load.
    private var statusCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Current UV Index")
                    .font(.headline)
                Text(weather.isLoading ? "Loading…" : "Couldn’t load the UV right now.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if weather.isLoading {
                ProgressView()
            } else {
                Button("Try Again") { Task { await weather.refresh() } }
                    .font(.subheadline.weight(.semibold))
            }
        }
        .frame(minHeight: 70)
        .cardStyle(LinearGradient(colors: [Color.orange.opacity(0.25), Color.orange.opacity(0.12)], startPoint: .leading, endPoint: .trailing))
    }

    private var setLocationCard: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Current UV Index")
                    .font(.headline)
                Text("Choose a location to see the live UV.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                isPickingLocation = true
            } label: {
                Label("Set Location", systemImage: "location.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(.solifyOrange, in: .capsule)
            }
            .buttonStyle(PressScaleButtonStyle())
        }
        .frame(minHeight: 70)
        .cardStyle(LinearGradient(colors: [Color.orange.opacity(0.25), Color.orange.opacity(0.12)], startPoint: .leading, endPoint: .trailing))
    }
}
