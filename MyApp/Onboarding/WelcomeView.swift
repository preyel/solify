import SwiftUI

/// The setup flow new users see before the tabs. It has 4 steps,
/// shown one at a time with the progress dots at the top.
struct WelcomeView: View {
    @AppStorage(StorageKey.hasSeenWelcome) private var hasSeenWelcome = false
    @AppStorage(StorageKey.skinType) private var skinType = 0
    @AppStorage(StorageKey.notificationsEnabled) private var notificationsEnabled = true

    @State private var step = 0
    @State private var isMovingForward = true

    private let buttonTitles = ["Get started", "Next", "Next", "Done"]

    var body: some View {
        VStack(spacing: 0) {
            header

            ZStack {
                currentStep
                    .id(step)
                    .transition(.asymmetric(
                        insertion: .move(edge: isMovingForward ? .trailing : .leading).combined(with: .opacity),
                        removal: .move(edge: isMovingForward ? .leading : .trailing).combined(with: .opacity)
                    ))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .clipped()

            Button(action: goForward) {
                Text(buttonTitles[step])
                    .font(.title3.bold())
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.roundedRectangle(radius: 16))
            .controlSize(.extraLarge)
            .disabled(step == 1 && skinType == 0)
            .padding(.horizontal, 24)
            .padding(.bottom, 8)
        }
    }

    @ViewBuilder
    private var currentStep: some View {
        switch step {
        case 0: IntroStep()
        case 1: SkinTypeStep()
        case 2: SunscreenStep()
        default: RoutineStep()
        }
    }

    private var header: some View {
        ZStack {
            ProgressDots(current: step, total: buttonTitles.count)

            HStack {
                Button(action: goBack) {
                    Image(systemName: "chevron.left")
                        .font(.title3.weight(.semibold))
                        .frame(width: 44, height: 44)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Back")
                .opacity(step == 0 ? 0 : 1)
                .disabled(step == 0)

                Spacer()
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
    }

    private func goForward() {
        if step < buttonTitles.count - 1 {
            isMovingForward = true
            withAnimation(.smooth) { step += 1 }
        } else {
            finish()
        }
    }

    private func goBack() {
        isMovingForward = false
        withAnimation(.smooth) { step -= 1 }
    }

    private func finish() {
        Task {
            if notificationsEnabled {
                notificationsEnabled = await Reminders.requestPermission()
                await Reminders.refreshAll()
            }
            withAnimation { hasSeenWelcome = true }
        }
    }
}

#Preview {
    WelcomeView()
        .tint(.orange)
}
