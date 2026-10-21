import SwiftUI

struct RemoteView: View {
    var body: some View {
        ScrollView {
            TheaterPanel(showsDismiss: true)
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 28)
        }
    }
}

struct TheaterPanel: View {
    var showsDismiss: Bool
    @Environment(StageModel.self) private var model
    @State private var showMirror = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if showsDismiss {
                Button {
                    model.closeTheater()
                } label: {
                    Label("Library", systemImage: "chevron.left")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Theme.secondary)
                }
                .buttonStyle(.plain)
                Text(model.currentTitle.isEmpty ? "Stage" : model.currentTitle)
                    .font(.system(size: 34, weight: .medium, design: .serif))
                    .foregroundStyle(Theme.text)
                    .lineLimit(2)
            }
            ConnectionRow()
            SoundRow()
            ModeCapsule()
            PlacementCard()
            HStack {
                Spacer()
                RecenterButton { model.recenter() }
                Spacer()
            }
            TransportBar()
            if let playbackError = model.playbackError {
                Text(playbackError)
                    .font(.footnote)
                    .foregroundStyle(Theme.accent)
            }
            Button {
                showMirror = true
            } label: {
                Text("Watch in another app")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.text)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Theme.surface, in: Capsule())
                    .overlay(Capsule().stroke(Theme.line, lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
        .sheet(isPresented: $showMirror) {
            MirrorSheet()
        }
    }
}

struct TheaterFallback: View {
    @Environment(StageModel.self) private var model

    var body: some View {
        ZStack(alignment: .bottom) {
            TheaterMetalView()
                .ignoresSafeArea()
            if model.fallbackChrome {
                ScrollView {
                    TheaterPanel(showsDismiss: true)
                        .padding(16)
                }
                .frame(maxHeight: 340)
                .background(
                    LinearGradient(
                        colors: [Theme.background.opacity(0.02), Theme.background.opacity(0.94)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .ignoresSafeArea()
                )
            }
        }
        .task(id: hideToken) {
            guard model.fallbackChrome, model.isPlaying else { return }
            try? await Task.sleep(for: .seconds(4))
            guard model.isPlaying, !model.isScrubbing else { return }
            model.fallbackChrome = false
        }
    }

    private var hideToken: String {
        "\(model.fallbackChrome)-\(model.isPlaying)-\(model.isScrubbing)"
    }
}

struct TheaterMetalView: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> TheaterViewController {
        let controller = TheaterViewController()
        controller.isExternalDisplay = false
        return controller
    }

    func updateUIViewController(_ uiViewController: TheaterViewController, context: Context) {}
}
