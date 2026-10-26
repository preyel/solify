# Solify

SwiftUI iOS app (sunscreen reminders). `SunSafe.xcodeproj` + source in `MyApp/` (target and scheme are still named `MyApp`; bundle ID `com.prek.Solify`). New `.swift` files in `MyApp/` are picked up automatically (synchronized folder).

The owner is new to Xcode/iOS: explain steps plainly. They design screens in Figma and send screenshots.

## Design rules
- Build Figma mockups with native, Apple-style SwiftUI (system fonts, native controls, haptics); ignore mockup fonts/sizes and fit to a phone screen.
- Overall theme is orange (`.tint(.orange)` at the app root). The 3 Home action buttons must stay the same orange.

## How the app works
- First launch shows a 4-step setup (`MyApp/Onboarding/`), gated by `hasSeenWelcome`. Tabs after that: Home, Forecast, Profile, Settings.
- Everything is saved with `@AppStorage`; key names live in `MyApp/StorageKey.swift`.
- Sunscreen: `spf` / `waterResistance` are the user's **default** (changed only by setup or "Change Sunscreen"). "Apply Sunscreen" can pick a different sunscreen for **one time only** (saved as `appliedSPF` / `appliedWaterResistance`). "Reapplied Now" always uses the default.
- Protection timer: 2 hours (`Reminders.reapplyInterval`).
- Notifications (`MyApp/Reminders/`): `Reminders.refreshAll()` rebuilds every pending notification (morning briefing at wake-up for 7 days; reapply reminder; outdoor-activity heads-ups; forecast-based weather alerts: UV jump, skies clearing, heat, rain). Call it after anything that affects them. iOS can't watch weather live, so alerts are scheduled ahead from the forecast and refreshed on app open, forecast refresh, and background app refresh (`Info.plist` at the project root holds the BG task ID + `fetch` mode).
- Reapply timing (`ReapplyPlanner` in `Reminders/ReapplyPlan.swift`): indoors (school/work) → wait until it ends; UV ≥ 8 or ≥ 95°F while out → 30 min earlier; past bedtime, or (within 2 h of sunset AND rest-of-day UV ≤ 3 AND no outdoor activity between the reminder and sunset) → postponed to the morning briefing. The plan (time + reason) is saved under `reapplyPlan` and shown on Home, the success screen and toasts. If a weather refresh moves it, a "Reminder moved" notification is sent.
- Every notification carries a `WeatherUpdate` (kind, headline, why, what to do, optional action); tapping it opens `WeatherUpdateView` (via `AppRouter`). The reapply screen has an "I've Reapplied" button.
- Settings tab (`MyApp/SettingsView.swift`): notifications / morning briefing / weather alert toggles, Strict Protection (low-UV postpone only when rest-of-day UV is 0, because UVA is present in daylight), Pause During Activities (off by default; a reminder that would fire mid outdoor activity waits until it ends, then the sunset rule may postpone it), default sunscreen, forecast location, redo setup, Open-Meteo credit.
- Profile tab (`MyApp/Profile/`): name, wake/bedtime, school/work/outdoor blocks (`RoutineStore`, `Routine`).
- Toasts (`MyApp/Home/Toast.swift`) pop up above the tab bar after Home actions; icons are SF Symbols on a teal circle (no emojis).
- App display name is "Solify" (project file and folder still say SunSafe); icon is `Assets.xcassets/AppIcon.appiconset`.
- Weather (`MyApp/Weather/`): real UV from Open-Meteo (free, no API key; non-commercial use only, so switch to their paid plan or WeatherKit if the app makes money). `WeatherStore.shared` holds location + forecast, caches them, refreshes when older than 30 min, and is passed in with `.environment`. Location is asked for only when the user taps "Use My Location"; they can search for a city instead.
- Forecast tab (`MyApp/Forecast/`): Today / Tomorrow / 10-Day, hourly chart (Swift Charts), rotating sun tips. Main buttons use `OrangeButtonStyle` / `.solifyOrange` to match Home.

## Testing
- Build: `xcodebuild -project SunSafe.xcodeproj -scheme MyApp -destination 'generic/platform=iOS Simulator' build`
- Set the Simulator's GPS with `xcrun simctl location <device> set 33.3062,-111.8413` (Chandler, AZ).
- Settings has a debug-only "Send Test Notifications" button.
- To re-test setup, uninstall the app from the Simulator. Don't write app settings with `simctl spawn … defaults write`; those survive uninstalling.
- The owner may click in the live Simulator panel at the same time as you.
