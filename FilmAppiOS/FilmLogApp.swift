import SwiftUI

@main
struct FilmLogApp: App {
    @StateObject private var store = FilmLogStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
        }
    }
}
