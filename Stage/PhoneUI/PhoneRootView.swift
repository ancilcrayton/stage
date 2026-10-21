import SwiftUI

struct PhoneRootView: View {
    @Environment(StageModel.self) private var model

    var body: some View {
        @Bindable var model = model
        ZStack {
            Theme.background.ignoresSafeArea()
            if model.prefersLandscape {
                TheaterFallback()
            } else if model.phase == .theater {
                RemoteView()
            } else {
                LibraryView()
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $model.showTuning) {
            DebugHUD()
        }
    }
}
