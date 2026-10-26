import SwiftUI

/// One of the 3 orange buttons at the bottom of Home.
struct HomeActionButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.system(size: 26))
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .frame(maxWidth: .infinity, minHeight: 96)
            .background(.solifyOrange, in: .rect(cornerRadius: 18))
        }
        .buttonStyle(PressScaleButtonStyle())
    }
}

/// A full-width orange button that matches the Home buttons.
struct OrangeButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(.solifyOrange, in: .rect(cornerRadius: 14))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.snappy, value: configuration.isPressed)
    }
}

extension ShapeStyle where Self == LinearGradient {
    /// The orange used on all of Solify's main buttons.
    static var solifyOrange: LinearGradient {
        LinearGradient(colors: [.orange, Color(red: 1, green: 0.45, blue: 0)], startPoint: .top, endPoint: .bottom)
    }
}

/// Shrinks a button slightly while it's being pressed.
struct PressScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.snappy, value: configuration.isPressed)
    }
}

extension View {
    /// The rounded card background used on Home.
    func cardStyle() -> some View {
        cardStyle(Color.orange.opacity(0.1))
    }

    func cardStyle<Background: ShapeStyle>(_ background: Background) -> some View {
        padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(background, in: .rect(cornerRadius: 20))
    }
}
