import SwiftUI
import UIKit

/// The picture, prompt and SPF / Water Resistance dropdowns shared by
/// the Apply Sunscreen and Change Sunscreen screens.
struct SunscreenForm: View {
    let prompt: String
    @Binding var spf: SPFLevel
    @Binding var waterResistance: WaterResistance

    var body: some View {
        VStack(spacing: 24) {
            SunscreenIllustration()

            Text(prompt)
                .font(.title3.weight(.medium))
                .multilineTextAlignment(.center)

            VStack(spacing: 16) {
                MenuField(title: "SPF", selection: $spf)
                MenuField(title: "Water Resistance", selection: $waterResistance)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
    }
}

/// The big orange circle with the sunscreen tube.
/// To use your own drawing, add a PNG named "SunscreenTube" to Assets.xcassets.
struct SunscreenIllustration: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(
                    colors: [Color(red: 1, green: 0.85, blue: 0.5), .orange],
                    startPoint: .top,
                    endPoint: .bottom
                ))

            if let tube = UIImage(named: "SunscreenTube") {
                Image(uiImage: tube)
                    .resizable()
                    .scaledToFit()
                    .padding(28)
            } else {
                Image(systemName: "sun.max.fill")
                    .font(.system(size: 90))
                    .foregroundStyle(.white)
                    .shadow(color: .orange.opacity(0.5), radius: 8)
            }
        }
        .frame(width: 190, height: 190)
        .accessibilityHidden(true)
    }
}

/// The big orange button plus the plain "Cancel" under it.
struct SheetButtons: View {
    let title: String
    let action: () -> Void
    let cancel: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            Button(action: action) {
                Text(title)
                    .font(.title3.bold())
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.roundedRectangle(radius: 16))
            .controlSize(.extraLarge)

            Button("Cancel", action: cancel)
                .foregroundStyle(.primary)
                .frame(minHeight: 44)
        }
    }
}

#Preview {
    SunscreenForm(prompt: "Select the sunscreen you’re using", spf: .constant(.veryHigh), waterResistance: .constant(.minutes80))
        .tint(.orange)
}
