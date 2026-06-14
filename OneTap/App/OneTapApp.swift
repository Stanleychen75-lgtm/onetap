import SwiftUI

@main
struct OneTapApp: App {
    var body: some Scene {
        WindowGroup {
            SearchView()
                .tint(Theme.accent)
        }
    }
}
