import SwiftUI

/// Shown until the user picks where they are: use their location, or type a city.
struct LocationPromptCard: View {
    @Environment(WeatherStore.self) private var store
    @State private var isPickingCity = false
    @State private var isLocating = false
    @State private var isShowingDeniedAlert = false
    @State private var isShowingNotFoundAlert = false

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "location.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.orange)
                .accessibilityHidden(true)

            Text("See the UV where you are")
                .font(.title3.bold())

            Text("Solify only uses your location to get the UV forecast. You can enter a city instead if you’d rather not share it.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button(action: useMyLocation) {
                if isLocating {
                    ProgressView().tint(.white)
                } else {
                    Label("Use My Location", systemImage: "location.fill")
                }
            }
            .buttonStyle(OrangeButtonStyle())
            .disabled(isLocating)
            .padding(.top, 4)

            Button("Enter a City") { isPickingCity = true }
                .font(.headline)
                .frame(minHeight: 44)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(Color.orange.opacity(0.1), in: .rect(cornerRadius: 20))
        .sheet(isPresented: $isPickingCity) { LocationPicker() }
        .locationDeniedAlert(isPresented: $isShowingDeniedAlert)
        .alert("Couldn’t Find Your Location", isPresented: $isShowingNotFoundAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Make sure you have a signal and try again, or search for a city instead.")
        }
    }

    private func useMyLocation() {
        Task {
            isLocating = true
            defer { isLocating = false }
            do {
                try await store.useCurrentLocation()
            } catch LocationService.LocationError.denied {
                isShowingDeniedAlert = true
            } catch {
                isShowingNotFoundAlert = true
            }
        }
    }
}

/// Sheet for choosing the forecast location: the phone's location, or search for a city.
struct LocationPicker: View {
    @Environment(WeatherStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var query = ""
    @State private var results: [OpenMeteo.Place] = []
    @State private var hasSearched = false
    @State private var isLocating = false
    @State private var isShowingDeniedAlert = false
    @State private var isShowingNotFoundAlert = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button(action: useCurrentLocation) {
                        HStack {
                            Label("Use Current Location", systemImage: "location.fill")
                            Spacer()
                            if isLocating { ProgressView() }
                        }
                    }
                    .disabled(isLocating)
                }

                if !results.isEmpty {
                    Section("Cities") {
                        ForEach(results) { city in
                            Button {
                                Task { await store.useCity(city) }
                                dismiss()
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(city.displayName)
                                        .foregroundStyle(.primary)
                                    if let country = city.country {
                                        Text(country)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                } else if hasSearched {
                    ContentUnavailableView.search(text: query)
                }
            }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search for a city")
            .task(id: query) {
                // Wait until the user pauses typing before searching.
                try? await Task.sleep(for: .milliseconds(300))
                guard !Task.isCancelled else { return }
                let trimmed = query.trimmingCharacters(in: .whitespaces)
                guard trimmed.count >= 2 else {
                    results = []
                    hasSearched = false
                    return
                }
                results = (try? await OpenMeteo.searchCities(trimmed)) ?? []
                hasSearched = true
            }
            .navigationTitle("Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", systemImage: "xmark") { dismiss() }
                }
            }
            .locationDeniedAlert(isPresented: $isShowingDeniedAlert)
        .alert("Couldn’t Find Your Location", isPresented: $isShowingNotFoundAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Make sure you have a signal and try again, or search for a city instead.")
        }
        }
    }

    private func useCurrentLocation() {
        Task {
            isLocating = true
            defer { isLocating = false }
            do {
                try await store.useCurrentLocation()
                dismiss()
            } catch LocationService.LocationError.denied {
                isShowingDeniedAlert = true
            } catch {
                isShowingNotFoundAlert = true
            }
        }
    }
}

extension View {
    /// Explains what to do when location permission is off.
    func locationDeniedAlert(isPresented: Binding<Bool>) -> some View {
        modifier(LocationDeniedAlert(isPresented: isPresented))
    }
}

private struct LocationDeniedAlert: ViewModifier {
    @Binding var isPresented: Bool
    @Environment(\.openURL) private var openURL

    func body(content: Content) -> some View {
        content.alert("Location Access Is Off", isPresented: $isPresented) {
            Button("Open Settings") {
                openURL(URL(string: UIApplication.openSettingsURLString)!)
            }
            Button("OK", role: .cancel) {}
        } message: {
            Text("To use your location, allow it for Solify in Settings. Or search for a city instead.")
        }
    }
}
