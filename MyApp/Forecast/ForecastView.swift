import SwiftUI

struct ForecastView: View {
    private enum Range: String, CaseIterable, Identifiable {
        case today = "Today"
        case tomorrow = "Tomorrow"
        case tenDay = "10-Day"
        var id: Self { self }
    }

    @Environment(WeatherStore.self) private var store
    @State private var range = Range.today
    @State private var isPickingLocation = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    if store.location == nil {
                        LocationPromptCard()
                    } else {
                        Picker("Forecast range", selection: $range) {
                            ForEach(Range.allCases) { Text($0.rawValue).tag($0) }
                        }
                        .pickerStyle(.segmented)

                        locationRow
                        content
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
            .refreshable { await store.refresh() }
            .navigationTitle("UV Forecast")
            .sheet(isPresented: $isPickingLocation) { LocationPicker() }
            .task { await store.refreshIfNeeded() }
            .sensoryFeedback(.selection, trigger: range)
        }
    }

    @ViewBuilder
    private var content: some View {
        if let forecast = store.forecast, let todayIndex = todayIndex(in: forecast) {
            switch range {
            case .today:
                DayForecastView(forecast: forecast, day: forecast.days[todayIndex], isToday: true)
            case .tomorrow:
                if todayIndex + 1 < forecast.days.count {
                    DayForecastView(forecast: forecast, day: forecast.days[todayIndex + 1], isToday: false)
                }
            case .tenDay:
                TenDayForecastView(forecast: forecast)
            }
        } else if let errorMessage = store.errorMessage, !store.isLoading {
            ForecastErrorCard(message: errorMessage) {
                Task { await store.refresh() }
            }
        } else {
            ProgressView("Loading forecast…")
                .padding(.top, 80)
        }
    }

    /// Which day in the forecast is today (in the forecast place's time zone).
    private func todayIndex(in forecast: UVForecast) -> Int? {
        forecast.days.firstIndex { forecast.calendar.isDateInToday($0.date) }
    }

    private var locationRow: some View {
        HStack(spacing: 8) {
            Button {
                isPickingLocation = true
            } label: {
                Label(store.location?.name ?? "", systemImage: store.location?.isCurrent == true ? "location.fill" : "mappin.and.ellipse")
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
            }
            .accessibilityHint("Changes the forecast location")

            Spacer()

            if let fetchedAt = store.forecast?.fetchedAt {
                TimelineView(.everyMinute) { _ in
                    Text(updatedText(fetchedAt))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Button("Refresh", systemImage: "arrow.clockwise") {
                Task { await store.refresh() }
            }
            .labelStyle(.iconOnly)
            .font(.subheadline.weight(.semibold))
            .symbolEffect(.rotate, isActive: store.isLoading)
            .disabled(store.isLoading)
            .frame(minWidth: 44, minHeight: 44)
        }
    }

    private func updatedText(_ date: Date) -> String {
        if Date.now.timeIntervalSince(date) < 60 { return "Updated just now" }
        return "Updated " + date.formatted(.relative(presentation: .named))
    }
}

#Preview {
    ForecastView()
        .environment(WeatherStore.shared)
        .tint(.orange)
}
