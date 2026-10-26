import SwiftUI

/// "Highest UV expected between 12 PM and 3 PM."
struct PeakTimeCard: View {
    let forecast: UVForecast
    let day: UVForecast.Day

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "sun.max.fill")
                .font(.title)
                .foregroundStyle(LinearGradient(colors: [.yellow, .orange], startPoint: .top, endPoint: .bottom))
                .accessibilityHidden(true)
            Text(message)
                .font(.subheadline.weight(.medium))
            Spacer(minLength: 0)
        }
        .cardStyle()
    }

    private var message: String {
        guard let window = forecast.peakWindow(on: day) else {
            return "UV stays low all day. Sunscreen is still a good idea for long stretches outside."
        }
        return "Highest UV expected between \(forecast.hourText(window.lowerBound)) and \(forecast.hourText(window.upperBound))."
    }
}

/// Sunrise, sunset, peak time, max UV and (for today) the UV right now.
struct DayDetailsCard: View {
    let forecast: UVForecast
    let day: UVForecast.Day
    let now: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Details")
                .font(.headline)

            if let sunrise = day.sunrise {
                row("Sunrise", systemImage: "sunrise.fill", value: forecast.timeText(sunrise))
            }
            if let sunset = day.sunset {
                row("Sunset", systemImage: "sunset.fill", value: forecast.timeText(sunset))
            }
            if let peak = forecast.peakHour(on: day) {
                row("Peak UV Time", systemImage: "clock.fill", value: forecast.hourText(peak.time))
            }
            let max = UVReading(uv: day.maxUV)
            row("Max UV Index", systemImage: "sun.max.fill", value: "\(max.index) (\(max.level.name))")
            if let now, let uvNow = forecast.uv(at: now) {
                let reading = UVReading(uv: uvNow)
                row("UV Right Now", systemImage: "gauge.with.needle.fill", value: "\(reading.index) (\(reading.level.name))")
            }
        }
        .cardStyle()
    }

    private func row(_ title: String, systemImage: String, value: String) -> some View {
        HStack {
            Label {
                Text(title)
            } icon: {
                Image(systemName: systemImage)
                    .foregroundStyle(.orange)
            }
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .font(.subheadline)
        .accessibilityElement(children: .combine)
    }
}

/// A table of the UV every 2 hours during daylight.
struct HourlyTableCard: View {
    let forecast: UVForecast
    let day: UVForecast.Day

    private var rows: [UVForecast.Hour] {
        let calendar = forecast.calendar
        let firstHour = day.sunrise.map { calendar.component(.hour, from: $0) } ?? 6
        let lastHour = day.sunset.map { calendar.component(.hour, from: $0) + 1 } ?? 20
        return forecast.hours(on: day).filter { hour in
            let h = calendar.component(.hour, from: hour.time)
            return h % 2 == 0 && h >= firstHour && h <= lastHour
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Hourly")
                .font(.headline)

            Grid(alignment: .leading, verticalSpacing: 10) {
                GridRow {
                    Text("Time")
                    Text("UV Index").gridCellColumns(2)
                    Text("Level")
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

                ForEach(rows) { hour in
                    let reading = UVReading(uv: hour.uv)
                    Divider()
                    GridRow {
                        Text(forecast.hourText(hour.time))
                            .frame(width: 64, alignment: .leading)
                        Circle()
                            .fill(reading.level.color)
                            .frame(width: 10, height: 10)
                        Text("\(reading.index)")
                            .monospacedDigit()
                            .frame(width: 36, alignment: .leading)
                        Text(reading.level.name)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .font(.subheadline)
                    .accessibilityElement(children: .combine)
                }
            }
        }
        .cardStyle()
    }
}

/// The 5 UV levels with their colors and number ranges.
struct UVLevelLegend: View {
    var body: some View {
        HStack(alignment: .top, spacing: 4) {
            ForEach(UVReading.Level.allCases) { level in
                VStack(spacing: 4) {
                    Circle()
                        .fill(level.color)
                        .frame(width: 12, height: 12)
                    Text(level.rangeLabel)
                        .font(.caption.weight(.semibold))
                        .monospacedDigit()
                    Text(level.name)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .combine)
            }
        }
    }
}

struct UVGuideCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("UV Index Guide")
                .font(.headline)
            UVLevelLegend()
        }
        .cardStyle()
    }
}

/// A sun safety tip that switches to a new one every few seconds (or when tapped).
struct SunTipCard: View {
    private struct Tip {
        let symbol: String
        let text: String
    }

    private static let tips = [
        Tip(symbol: "sunglasses.fill", text: "Wear UV-blocking sunglasses to protect your eyes."),
        Tip(symbol: "umbrella.fill", text: "Seek shade when UV is strongest, usually around midday."),
        Tip(symbol: "clock.fill", text: "Reapply sunscreen at least every 2 hours."),
        Tip(symbol: "water.waves", text: "Reapply right after swimming or sweating, even if your sunscreen is water-resistant."),
        Tip(symbol: "cloud.sun.fill", text: "Clouds don’t block UV. Up to 80% of it still gets through."),
        Tip(symbol: "drop.fill", text: "Use about a shot glass’s worth of sunscreen to cover your whole body."),
        Tip(symbol: "tshirt.fill", text: "Tightly woven clothing and a wide-brimmed hat add extra protection."),
        Tip(symbol: "sun.horizon.fill", text: "Plan outdoor activities for early morning or late afternoon when UV is lower."),
        Tip(symbol: "snowflake", text: "Snow, sand and water reflect UV, so you can burn faster near them."),
        Tip(symbol: "timer", text: "Apply sunscreen about 15 minutes before heading outside."),
        Tip(symbol: "figure.stand", text: "Don’t forget your ears, neck, and the tops of your feet."),
    ]

    @State private var index = Int.random(in: 0..<tips.count)

    var body: some View {
        let tip = Self.tips[index]

        ZStack {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: tip.symbol)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(Color.teal.gradient, in: .circle)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Sun Protection Tip")
                        .font(.headline)
                    Text(tip.text)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .id(index)
            .transition(.push(from: .trailing))
        }
        .frame(minHeight: 72, alignment: .top)
        .clipped()
        .cardStyle()
        .contentShape(.rect)
        .onTapGesture(perform: showNextTip)
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(8))
                guard !Task.isCancelled else { break }
                showNextTip()
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAction(named: "Next tip", showNextTip)
    }

    private func showNextTip() {
        withAnimation(.smooth) { index = (index + 1) % Self.tips.count }
    }
}

/// Shown when the forecast couldn't load.
struct ForecastErrorCard: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 40))
                .foregroundStyle(.orange)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Try Again", action: retry)
                .buttonStyle(OrangeButtonStyle())
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(Color.orange.opacity(0.1), in: .rect(cornerRadius: 20))
    }
}
