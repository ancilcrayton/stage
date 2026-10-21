import AVFoundation
import Foundation
import QuartzCore

enum VideoRotation {
    case none
    case right
    case down
    case left

    init(_ transform: CGAffineTransform) {
        if transform.b > 0.5, transform.c < -0.5 {
            self = .right
        } else if transform.b < -0.5, transform.c > 0.5 {
            self = .left
        } else if transform.a < -0.5, transform.d < -0.5 {
            self = .down
        } else {
            self = .none
        }
    }

    var quarterTurns: Int {
        switch self {
        case .none: 0
        case .right: 1
        case .down: 2
        case .left: 3
        }
    }
}

@MainActor
final class MediaPlayer {
    let player: AVPlayer
    private var output: AVPlayerItemVideoOutput?
    private var timeToken: Any?
    private var observers: [NSObjectProtocol] = []
    private(set) var rotation = VideoRotation.none
    private(set) var storedAspect: Float = 16 / 9

    var isPlaying: Bool {
        player.rate > 0.01
    }

    var displayAspect: Float {
        let turns = (rotation.quarterTurns + StageModel.shared.pictureTurns) % 2
        guard storedAspect > 0 else { return 16 / 9 }
        return turns == 1 ? 1 / storedAspect : storedAspect
    }

    var shaderRotation: Float {
        Float((rotation.quarterTurns + StageModel.shared.pictureTurns) % 4)
    }

    init() {
        let player = AVPlayer()
        player.allowsExternalPlayback = false
        player.usesExternalPlaybackWhileExternalScreenIsActive = false
        player.preventsDisplaySleepDuringVideoPlayback = true
        player.actionAtItemEnd = .pause
        player.audiovisualBackgroundPlaybackPolicy = .continuesIfPossible
        self.player = player
    }

    func load(url: URL, resume: Double) {
        tearDownObservers()
        let item = AVPlayerItem(url: url)
        let output = AVPlayerItemVideoOutput(pixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferMetalCompatibilityKey as String: true,
        ])
        item.add(output)
        self.output = output
        rotation = .none
        storedAspect = 16 / 9
        player.replaceCurrentItem(with: item)
        observe(item)
        if resume > 0.5 {
            player.seek(
                to: CMTime(seconds: resume, preferredTimescale: 600),
                toleranceBefore: .zero,
                toleranceAfter: .zero
            )
        }
        player.play()
        Task { await inspect(item) }
    }

    func play() {
        player.play()
    }

    func pause() {
        player.pause()
    }

    func seek(to seconds: Double) {
        let target = max(seconds, 0)
        player.seek(
            to: CMTime(seconds: target, preferredTimescale: 600),
            toleranceBefore: .zero,
            toleranceAfter: .zero
        )
    }

    func skip(_ seconds: Double) {
        let current = player.currentTime().seconds
        let length = player.currentItem?.duration.seconds ?? 0
        var target = (current.isFinite ? current : 0) + seconds
        if length.isFinite, length > 0 {
            target = min(max(target, 0), length)
        } else {
            target = max(target, 0)
        }
        seek(to: target)
    }

    func copyFrame() -> CVPixelBuffer? {
        guard let output else { return nil }
        let time = output.itemTime(forHostTime: CACurrentMediaTime())
        guard output.hasNewPixelBuffer(forItemTime: time) else { return nil }
        return output.copyPixelBuffer(forItemTime: time, itemTimeForDisplay: nil)
    }

    private func observe(_ item: AVPlayerItem) {
        let interval = CMTime(seconds: 0.25, preferredTimescale: 600)
        timeToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { time in
            let seconds = time.seconds
            Task { @MainActor in
                let player = StageModel.shared.player
                let length = player.player.currentItem?.duration.seconds ?? 0
                StageModel.shared.updatePlayback(
                    time: seconds.isFinite ? seconds : 0,
                    duration: length.isFinite ? length : 0,
                    playing: player.isPlaying
                )
            }
        }
        observers.append(NotificationCenter.default.addObserver(
            forName: .AVPlayerItemFailedToPlayToEndTime,
            object: item,
            queue: .main
        ) { note in
            let message = (note.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error)?
                .localizedDescription ?? "Playback stopped."
            Task { @MainActor in
                StageModel.shared.noteFailure(message)
            }
        })
        observers.append(NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { _ in
            Task { @MainActor in
                StageModel.shared.isPlaying = false
            }
        })
    }

    private func inspect(_ item: AVPlayerItem) async {
        guard let track = try? await item.asset.loadTracks(withMediaType: .video).first else { return }
        let transform = await (try? track.load(.preferredTransform)) ?? .identity
        let size = await (try? track.load(.naturalSize)) ?? .zero
        let failed = item.status == .failed
        let message = item.error?.localizedDescription
        await MainActor.run {
            rotation = VideoRotation(transform)
            if size.width > 1, size.height > 1 {
                storedAspect = Float(size.width / size.height)
            }
            if failed {
                StageModel.shared.noteFailure(message ?? "This video can’t be played.")
            }
        }
    }

    private func tearDownObservers() {
        if let timeToken {
            player.removeTimeObserver(timeToken)
            self.timeToken = nil
        }
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
        }
        observers.removeAll()
    }
}
