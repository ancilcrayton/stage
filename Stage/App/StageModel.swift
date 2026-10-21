import AVFoundation
import Foundation
import Observation
import PhotosUI
import UIKit

enum TrackingStatus: Equatable {
    case unavailable
    case denied
    case needsAirPods
    case tracking

    var title: String {
        switch self {
        case .unavailable: "Unavailable"
        case .denied: "Motion off"
        case .needsAirPods: "Connect"
        case .tracking: "Tracking"
        }
    }

    var isLive: Bool {
        self == .tracking
    }
}

@MainActor
@Observable
final class StageModel {
    static let shared = StageModel()

    var mode: DisplayMode = .drift
    var levelHorizon = true
    var screenSize = 0.72
    var curve = 0.35
    var phase: Phase = .library
    var glassesConnected = false
    var tracking: TrackingStatus = .needsAirPods
    var yawDegrees = 0.0
    var pitchDegrees = 0.0
    var rollDegrees = 0.0
    var sensorLocation = ""
    var framesPerSecond = 0.0
    var audioRoute = "Phone"
    var soundIsAirPods = false
    var showTuning = false
    var invertYaw = false
    var invertPitch = false
    var invertRoll = false
    var predictionMs = 30.0
    var smoothingMs = 45.0
    var driftSeconds = 1.5
    var pictureTurns = 0
    var currentTitle = ""
    var currentTime = 0.0
    var duration = 0.0
    var isPlaying = false
    var isScrubbing = false
    var playbackError: String?
    var mirrorError: String?
    var fallbackChrome = true

    let library = MediaLibrary()
    let player = MediaPlayer()
    let audio = AudioRouter()
    let head = HeadTracker()

    var onPresentationChange: (@MainActor () -> Void)?

    @ObservationIgnored private var pose = PoseFilter()
    @ObservationIgnored private var headSample = HeadSample()
    @ObservationIgnored private var lastTick = CACurrentMediaTime()
    @ObservationIgnored private var lastAnglePublish = 0.0
    @ObservationIgnored private var started = false
    @ObservationIgnored private var currentItemID: UUID?

    var prefersLandscape: Bool {
        !glassesConnected && phase == .theater
    }

    private init() {
        loadPreferences()
    }

    func start() {
        guard !started else { return }
        started = true
        lastTick = CACurrentMediaTime()
        head.start()
        audio.refresh()
    }

    func setGlassesConnected(_ connected: Bool) {
        guard glassesConnected != connected else { return }
        glassesConnected = connected
        onPresentationChange?()
    }

    func setTracking(_ status: TrackingStatus) {
        tracking = status
    }

    func ingest(_ sample: HeadSample, status: TrackingStatus) {
        headSample = sample
        if tracking != status {
            tracking = status
        }
        guard sample.connected else {
            yawDegrees = 0
            pitchDegrees = 0
            rollDegrees = 0
            sensorLocation = ""
            return
        }
        let now = CACurrentMediaTime()
        guard now - lastAnglePublish > 0.12 else { return }
        lastAnglePublish = now
        yawDegrees = degrees(sample.yaw, inverted: invertYaw)
        pitchDegrees = degrees(sample.pitch, inverted: invertPitch)
        rollDegrees = degrees(sample.roll, inverted: invertRoll)
        sensorLocation = sample.location
    }

    func integrateFrame() -> simd_quatf {
        let now = CACurrentMediaTime()
        let dt = Float(now - lastTick)
        lastTick = now
        pose.mode = mode
        pose.levelHorizon = levelHorizon
        pose.prediction = Float(predictionMs / 1000)
        pose.smoothingTau = Float(max(smoothingMs, 1) / 1000)
        pose.driftTau = Float(max(driftSeconds, 0.05))
        pose.invertYaw = invertYaw ? -1 : 1
        pose.invertPitch = invertPitch ? -1 : 1
        pose.invertRoll = invertRoll ? -1 : 1
        return pose.viewRotation(sample: headSample, dt: dt)
    }

    func setMode(_ mode: DisplayMode) {
        guard self.mode != mode else { return }
        self.mode = mode
        savePreferences()
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
    }

    func recenter() {
        head.recenter()
        headSample.yaw = 0
        headSample.pitch = 0
        headSample.roll = 0
        headSample.yawRate = 0
        headSample.pitchRate = 0
        headSample.rollRate = 0
        pose.reset()
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
    }

    func open(_ item: MediaItem) {
        guard let url = library.url(for: item) else {
            library.lastError = "That video is no longer available."
            return
        }
        currentItemID = item.id
        currentTitle = item.title
        currentTime = item.position
        duration = item.duration
        playbackError = nil
        fallbackChrome = true
        phase = .theater
        audio.activate()
        UIApplication.shared.isIdleTimerDisabled = true
        player.load(url: url, resume: item.position)
        onPresentationChange?()
    }

    func closeTheater() {
        player.pause()
        isPlaying = false
        phase = .library
        UIApplication.shared.isIdleTimerDisabled = false
        library.flush()
        savePreferences()
        onPresentationChange?()
    }

    func togglePlayback() {
        if player.isPlaying {
            player.pause()
            isPlaying = false
        } else {
            audio.activate()
            player.play()
            isPlaying = true
        }
    }

    func skip(_ seconds: Double) {
        player.skip(seconds)
    }

    func finishScrub() {
        isScrubbing = false
        player.seek(to: currentTime)
    }

    func updatePlayback(time: Double, duration: Double, playing: Bool) {
        if !isScrubbing, time.isFinite {
            currentTime = max(time, 0)
        }
        if duration.isFinite, duration > 0 {
            self.duration = duration
        }
        isPlaying = playing
        guard let currentItemID else { return }
        library.updateProgress(id: currentItemID, position: max(time, 0), duration: self.duration)
    }

    func noteFailure(_ message: String) {
        playbackError = message
        isPlaying = false
    }

    func openMirror(_ destination: MirrorDestination) {
        guard UIApplication.shared.canOpenURL(destination.url) else {
            mirrorError = "\(destination.title) isn’t installed."
            return
        }
        mirrorError = nil
        UIApplication.shared.open(destination.url)
    }

    func importFile(from url: URL) async {
        await library.importFile(from: url)
    }

    func importPhoto(_ item: PhotosPickerItem) async {
        await library.importPhoto(item)
    }

    func addLink(_ raw: String) {
        library.addLink(raw)
    }

    func savePreferences() {
        let defaults = UserDefaults.standard
        defaults.set(mode.rawValue, forKey: Key.mode)
        defaults.set(levelHorizon, forKey: Key.level)
        defaults.set(screenSize, forKey: Key.size)
        defaults.set(curve, forKey: Key.curve)
        defaults.set(invertYaw, forKey: Key.invertYaw)
        defaults.set(invertPitch, forKey: Key.invertPitch)
        defaults.set(invertRoll, forKey: Key.invertRoll)
        defaults.set(predictionMs, forKey: Key.prediction)
        defaults.set(smoothingMs, forKey: Key.smoothing)
        defaults.set(driftSeconds, forKey: Key.drift)
        defaults.set(pictureTurns, forKey: Key.turns)
    }

    private func loadPreferences() {
        let defaults = UserDefaults.standard
        if let raw = defaults.string(forKey: Key.mode), let stored = DisplayMode(rawValue: raw) {
            mode = stored
        }
        if defaults.object(forKey: Key.level) != nil {
            levelHorizon = defaults.bool(forKey: Key.level)
        }
        if defaults.object(forKey: Key.size) != nil {
            screenSize = defaults.double(forKey: Key.size)
        }
        if defaults.object(forKey: Key.curve) != nil {
            curve = defaults.double(forKey: Key.curve)
        }
        if defaults.object(forKey: Key.invertYaw) != nil {
            invertYaw = defaults.bool(forKey: Key.invertYaw)
        }
        if defaults.object(forKey: Key.invertPitch) != nil {
            invertPitch = defaults.bool(forKey: Key.invertPitch)
        }
        if defaults.object(forKey: Key.invertRoll) != nil {
            invertRoll = defaults.bool(forKey: Key.invertRoll)
        }
        if defaults.object(forKey: Key.prediction) != nil {
            predictionMs = defaults.double(forKey: Key.prediction)
        }
        if defaults.object(forKey: Key.smoothing) != nil {
            smoothingMs = defaults.double(forKey: Key.smoothing)
        }
        if defaults.object(forKey: Key.drift) != nil {
            driftSeconds = defaults.double(forKey: Key.drift)
        }
        if defaults.object(forKey: Key.turns) != nil {
            pictureTurns = defaults.integer(forKey: Key.turns)
        }
    }

    private func degrees(_ radians: Float, inverted: Bool) -> Double {
        let sign: Float = inverted ? -1 : 1
        return Double(radians * sign * 180 / .pi)
    }
}

enum Phase {
    case library
    case theater
}

private enum Key {
    static let mode = "stage.mode"
    static let level = "stage.level"
    static let size = "stage.size"
    static let curve = "stage.curve"
    static let invertYaw = "stage.invertYaw"
    static let invertPitch = "stage.invertPitch"
    static let invertRoll = "stage.invertRoll"
    static let prediction = "stage.prediction"
    static let smoothing = "stage.smoothing"
    static let drift = "stage.drift"
    static let turns = "stage.turns"
}

struct MirrorDestination: Identifiable {
    let id: String
    let title: String
    let detail: String
    let symbol: String
    let url: URL

    static let all: [MirrorDestination] = [
        MirrorDestination(
            id: "tv",
            title: "Apple TV",
            detail: "Opens as a fixed mirror. Head lock pauses until you come back.",
            symbol: "play.tv",
            url: URL(string: "videos://")!
        ),
        MirrorDestination(
            id: "netflix",
            title: "Netflix",
            detail: "Opens as a fixed mirror. Encrypted video can’t be head-locked.",
            symbol: "film",
            url: URL(string: "nflx://")!
        ),
        MirrorDestination(
            id: "youtube",
            title: "YouTube",
            detail: "Opens as a fixed mirror. Head lock pauses until you come back.",
            symbol: "play.rectangle",
            url: URL(string: "youtube://")!
        ),
        MirrorDestination(
            id: "safari",
            title: "Safari",
            detail: "Opens the browser as a fixed mirror.",
            symbol: "safari",
            url: URL(string: "https://www.apple.com")!
        ),
    ]
}
