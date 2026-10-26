import SwiftUI
import Playgrounds

struct ContentView: View {
    var body: some View {
        TabView {
            Tab("Home", systemImage: "house") {
                HomeView()
            }
            Tab("Forecast", systemImage: "sun.max") {
                ForecastView()
            }
            Tab("Profile", systemImage: "person") {
                ProfileView()
            }
            Tab("Settings", systemImage: "gearshape") {
                SettingsView()
            }
        }
    }
}

#Preview {
    ContentView()
}

#Playground {
    _ = 1 + 2
}
