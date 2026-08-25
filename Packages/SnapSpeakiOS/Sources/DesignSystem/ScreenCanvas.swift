import SwiftUI

public extension View {
    /// Warm canvas behind `ScrollView` / `List` / `Form` without fighting system chrome.
    func snapspeakCanvas() -> some View {
        self
            .scrollContentBackground(.hidden)
            .background(Colors.background)
    }
}
