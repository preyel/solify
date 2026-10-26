import Charts
import SwiftUI

/// The "10-Day" tab: a bar chart of each day's max UV, then a list of days.
struct TenDayForecastView: View {
    let forecast: UVForecast

    @State private var isShowingAllDays = false

    private var visibleDays: ArraySlice<UVForecast.Day> {
        isShowingAllDays ? forecast.days[...] : forecast.days.prefix(5)
    }

    var body: some View {
        VStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 14) {
                Text("Daily Max UV Index")
                    .font(.headline)
                UVLevelLegend()
                chart
            }
            .cardStyle()

            Grid(alignment: .leading, verticalSpacing: 12) {
                ForEach(visibleDays) { day in
                    if day.id != forecast.days.first?.id { Divider() }
                    row(for: day)
                }
            }
            .cardStyle()

            if forecast.days.count > 5 {
                Button(isShowingAllDays ? "Show Less" : "See Full 10-Day Forecast") {
                    withAnimation(.smooth) { isShowingAllDays.toggle() }
                }
                .buttonStyle(OrangeButtonStyle())
            }

            SunTipCard()
        }
    }

    private var chart: some View {
        let top = max(12, (forecast.days.map(\.maxUV).max() ?? 0) + 1)
        return Chart(forecast.days) { day in
            let reading = UVReading(uv: day.maxUV)
            BarMark(
                x: .value("Day", day.date, unit: .day),
                y: .value("Max UV", day.maxUV)
            )
            .foregroundStyle(reading.level.color.gradient)
            .clipShape(.rect(cornerRadius: 4))
            .annotation(position: .top, spacing: 2) {
                Text("\(reading.index)")
                    .font(.caption2.bold())
            }
        }
        .chartYScale(domain: 0...top)
        .chartXAxis {
            AxisMarks(values: .stride(by: .day)) {
                AxisValueLabel(format: .dateTime.weekday(.abbreviated), centered: true)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: [0, 3, 6, 8, 11])
        }
        .environment(\.timeZone, forecast.timeZone)
        .frame(height: 200)
    }

    private func row(for day: UVForecast.Day) -> some View {
        let reading = UVReading(uv: day.maxUV)
        let isToday = day.id == forecast.days.first?.id
        return GridRow {
            Text(isToday ? "Today" : forecast.dayText(day.date))
                .font(.subheadline.weight(isToday ? .semibold : .regular))
                .frame(width: 110, alignment: .leading)
            Circle()
                .fill(reading.level.color)
                .frame(width: 10, height: 10)
            Text("\(reading.index)")
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .frame(width: 26, alignment: .leading)
            Text(reading.level.name)
                .font(.subheadline)
                .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: day.weatherSymbol)
                .symbolRenderingMode(.palette)
                .foregroundStyle(day.weatherSymbol == "sun.max.fill" ? Color.orange : Color(.systemGray), day.weatherAccent)
                .font(.title3)
                .accessibilityLabel(day.weatherDescription)
        }
        .accessibilityElement(children: .combine)
    }
}
