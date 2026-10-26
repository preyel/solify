import SwiftUI

/// Step 1: "Let's get you set up!"
struct IntroStep: View {
    var body: some View {
        VStack(spacing: 16) {
            StepTitle("Let’s get you set up!")

            Text("We’ll personalize your sunscreen reminders.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Spacer()

            Image(systemName: "sun.max.fill")
                .font(.system(size: 140))
                .foregroundStyle(LinearGradient(colors: [.yellow, .orange], startPoint: .top, endPoint: .bottom))
                .accessibilityHidden(true)

            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.top, 32)
    }
}

#Preview {
    IntroStep()
}
