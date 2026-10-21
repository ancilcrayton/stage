import AVKit
import SwiftUI

struct AirPlayRoutePicker: UIViewRepresentable {
    func makeUIView(context: Context) -> AVRoutePickerView {
        let picker = AVRoutePickerView()
        picker.prioritizesVideoDevices = false
        picker.tintColor = ThemeUI.accent
        picker.activeTintColor = ThemeUI.accent
        return picker
    }

    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {}
}

struct SoundRow: View {
    @Environment(StageModel.self) private var model

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(model.soundIsAirPods ? "Sound" : "Switch sound to AirPods")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(model.soundIsAirPods ? Theme.text : Theme.accent)
                Text(model.audioRoute)
                    .font(.caption)
                    .foregroundStyle(Theme.secondary)
                    .lineLimit(1)
            }
            Spacer()
            AirPlayRoutePicker()
                .frame(width: 44, height: 44)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Theme.line, lineWidth: 1))
    }
}

struct TransportBar: View {
    @Environment(StageModel.self) private var model

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text(clock(model.currentTime))
                Spacer()
                Text(clock(model.duration))
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(Theme.secondary)

            Slider(
                value: Binding(
                    get: { min(max(model.currentTime, 0), max(model.duration, 1)) },
                    set: { model.currentTime = $0 }
                ),
                in: 0 ... max(model.duration, 1),
                onEditingChanged: { editing in
                    model.isScrubbing = editing
                    if !editing {
                        model.finishScrub()
                    }
                }
            )
            .tint(Theme.accent)
            .disabled(model.duration <= 0)

            HStack(spacing: 28) {
                transportButton("gobackward.10") { model.skip(-10) }
                Button {
                    model.togglePlayback()
                } label: {
                    Image(systemName: model.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title2)
                        .foregroundStyle(Color.black)
                        .frame(width: 64, height: 64)
                        .background(Theme.accent, in: Circle())
                }
                .buttonStyle(.plain)
                transportButton("goforward.10") { model.skip(10) }
            }
        }
    }

    private func transportButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(Theme.text)
                .frame(width: 48, height: 48)
        }
        .buttonStyle(.plain)
    }
}
