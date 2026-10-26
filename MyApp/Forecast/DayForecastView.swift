import SwiftUI

/// The "Today" and "Tomorrow" tabs of the forecast.
struct DayForecastView: View {
    let forecast: UVForecast
    let day: UVForecast.Day
    let isToday: Bool

    var body: some View {
        // Redraws every minute so "now" on the chart and "UV Right Now" stay current.
        TimelineView(.everyMinute) { context in
            let now = isToday ? context.date : nil

            VStack(spacing: 12) {
                UVIndexCard(
                    title: isToday ? "Today’s Max Index" : "Tomorrow’s Max Index",
                    reading: UVReading(uv: day.maxUV),
                    caption: day.weatherDescription
                )

                VStack(alignment: .leading, spacing: 8) {
                    Text("Hourly UV")
                        .font(.headline)
                    UVDayChart(forecast: forecast, day: day, now: now)
                    Text("Touch and hold the chart to see each hour.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .cardStyle()

                PeakTimeCard(forecast: forecast, day: day)
                DayDetailsCard(forecast: forecast, day: day, now: now)
                HourlyTableCard(forecast: forecast, day: day)
                UVGuideCard()
                SunTipCard()
            }
        }
    }
}
