import Charts
import SwiftUI

/// The hourly UV curve for one day, over colored bands for each UV level.
/// Press and drag on it to see the UV at any hour.
struct UVDayChart: View {
    let forecast: UVForecast
    let day: UVForecast.Day
    /// The current time if this is today (grays out the past and marks "now").
    let now: Date?

    @State private var selectedTime: Date?

    private var hours: [UVForecast.Hour] { forecast.hours(on: day) }
    private var dayEnd: Date { day.date.addingTimeInterval(24 * 3600) }
    private var top: Double { max(12, (hours.map(\.uv).max() ?? 0) + 1) }

    private var selectedHour: UVForecast.Hour? {
        guard let selectedTime else { return nil }
        return hours.min { abs($0.time.timeIntervalSince(selectedTime)) < abs($1.time.timeIntervalSince(selectedTime)) }
    }

    var body: some View {
        Chart {
            // Colored background bands: green (low) up to purple (extreme).
            ForEach(UVReading.Level.allCases) { level in
                RectangleMark(
                    xStart: .value("Start", day.date),
                    xEnd: .value("End", dayEnd),
                    yStart: .value("From", level.chartBounds.lower),
                    yEnd: .value("To", min(level.chartBounds.upper, top))
                )
                .foregroundStyle(level.color.opacity(0.4))
            }

            // Gray out the part of today that's already over.
            if let now {
                RectangleMark(
                    xStart: .value("Start", day.date),
                    xEnd: .value("Now", now),
                    yStart: .value("From", 0),
                    yEnd: .value("To", top)
                )
                .foregroundStyle(Color.gray.opacity(0.25))
            }

            // Dashed lines around the hours when UV is strongest.
            if let window = forecast.peakWindow(on: day) {
                ForEach([window.lowerBound, window.upperBound], id: \.self) { edge in
                    RuleMark(x: .value("Peak", edge))
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                        .foregroundStyle(Color.secondary)
                }
            }

            ForEach(hours) { hour in
                LineMark(x: .value("Time", hour.time), y: .value("UV", hour.uv))
                    .interpolationMethod(.monotone)
                    .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                    .foregroundStyle(Color.primary)
            }

            if let peak = forecast.peakHour(on: day), peak.uv >= 1 {
                PointMark(x: .value("Time", peak.time), y: .value("UV", peak.uv))
                    .foregroundStyle(Color.primary)
                    .annotation(position: .top, spacing: 4) {
                        Text("\(UVReading(uv: peak.uv).index)")
                            .font(.caption.bold())
                    }
            }

            if let now, let uvNow = forecast.uv(at: now) {
                PointMark(x: .value("Now", now), y: .value("UV", uvNow))
                    .symbolSize(110)
                    .foregroundStyle(.orange)
            }

            if let hour = selectedHour {
                RuleMark(x: .value("Selected", hour.time))
                    .foregroundStyle(Color.primary.opacity(0.5))
                    .annotation(position: .top, overflowResolution: .init(x: .fit(to: .chart), y: .disabled)) {
                        selectionBubble(for: hour)
                    }
            }
        }
        .chartXScale(domain: day.date...dayEnd)
        .chartYScale(domain: 0...top)
        .chartXAxis {
            AxisMarks(values: .stride(by: .hour, count: 6)) {
                AxisGridLine()
                AxisValueLabel(format: .dateTime.hour())
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: [0, 3, 6, 8, 11]) {
                AxisValueLabel()
            }
        }
        .chartXSelection(value: $selectedTime)
        .environment(\.timeZone, forecast.timeZone)
        .frame(height: 220)
        .sensoryFeedback(.selection, trigger: selectedHour?.time)
        .accessibilityLabel("Hourly UV chart")
        .accessibilityValue(accessibilitySummary)
    }

    private func selectionBubble(for hour: UVForecast.Hour) -> some View {
        let reading = UVReading(uv: hour.uv)
        return VStack(spacing: 2) {
            Text(forecast.hourText(hour.time))
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text("UV \(reading.index) · \(reading.level.name)")
                .font(.caption.bold())
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(.systemBackground), in: .rect(cornerRadius: 10))
        .shadow(color: .black.opacity(0.12), radius: 6, y: 2)
    }

    private var accessibilitySummary: String {
        guard let peak = forecast.peakHour(on: day) else { return "No data" }
        return "Peaks at \(UVReading(uv: peak.uv).index) around \(forecast.hourText(peak.time))"
    }
}

extension UVForecast {
    /// Like "2 PM", in the forecast place's time zone.
    func hourText(_ date: Date) -> String {
        var style = Date.FormatStyle().hour()
        style.timeZone = timeZone
        return date.formatted(style)
    }

    /// Like "2:15 PM", in the forecast place's time zone.
    func timeText(_ date: Date) -> String {
        var style = Date.FormatStyle(date: .omitted, time: .shortened)
        style.timeZone = timeZone
        return date.formatted(style)
    }

    /// Like "Mon, Oct 19", in the forecast place's time zone.
    func dayText(_ date: Date) -> String {
        var style = Date.FormatStyle().weekday(.abbreviated).month(.abbreviated).day()
        style.timeZone = timeZone
        return date.formatted(style)
    }
}
