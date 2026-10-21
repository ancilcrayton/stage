import AVFoundation
import Foundation

@MainActor
final class AudioRouter {
    private var observer: NSObjectProtocol?

    func activate() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .moviePlayback, options: [.allowBluetoothA2DP])
            try session.setActive(true)
        } catch {
            StageModel.shared.playbackError = "Audio didn’t start. \(error.localizedDescription)"
        }
        publish()
        observe()
    }

    func refresh() {
        publish()
        observe()
    }

    func publish() {
        let outputs = AVAudioSession.sharedInstance().currentRoute.outputs
        let name = outputs.map(\.portName).joined(separator: ", ")
        let model = StageModel.shared
        model.audioRoute = name.isEmpty ? "Phone" : name
        model.soundIsAirPods = outputs.contains { output in
            if output.portName.localizedCaseInsensitiveContains("airpod") {
                return true
            }
            switch output.portType {
            case .bluetoothA2DP, .bluetoothLE, .headphones:
                return true
            default:
                return false
            }
        }
    }

    private func observe() {
        guard observer == nil else { return }
        observer = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                StageModel.shared.audio.publish()
            }
        }
    }
}
