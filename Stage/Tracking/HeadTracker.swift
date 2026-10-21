import CoreMotion
import Foundation

/// AirPods Pro motion. Yaw rate is taken from the vertical axis of Core Motion's
/// gravity-up frame, pitch rate from X, and roll rate from Y.
final class HeadTracker: NSObject, CMHeadphoneMotionManagerDelegate, @unchecked Sendable {
    private let manager = CMHeadphoneMotionManager()
    private let queue: OperationQueue = {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        queue.qualityOfService = .userInteractive
        return queue
    }()

    private let lock = NSLock()
    private var reference: CMAttitude?
    private var latestAttitude: CMAttitude?
    private var started = false

    func start() {
        guard !started else { return }
        started = true
        manager.delegate = self

        guard manager.isDeviceMotionAvailable else {
            publish(.unavailable)
            return
        }
        if CMHeadphoneMotionManager.authorizationStatus() == .denied {
            publish(.denied)
            return
        }

        manager.startConnectionStatusUpdates()
        manager.startDeviceMotionUpdates(to: queue) { [weak self] motion, _ in
            guard let self, let motion else { return }
            self.consume(motion)
        }
    }

    func recenter() {
        lock.lock()
        reference = latestAttitude?.copy() as? CMAttitude
        lock.unlock()
    }

    func headphoneMotionManagerDidDisconnect(_ manager: CMHeadphoneMotionManager) {
        lock.lock()
        latestAttitude = nil
        lock.unlock()
        let cleared = HeadSample()
        Task { @MainActor in
            StageModel.shared.ingest(cleared, status: .needsAirPods)
        }
    }

    private func consume(_ motion: CMDeviceMotion) {
        lock.lock()
        latestAttitude = motion.attitude.copy() as? CMAttitude
        if reference == nil {
            reference = motion.attitude.copy() as? CMAttitude
        }
        let relative = motion.attitude.copy() as? CMAttitude
        if let relative, let reference {
            relative.multiply(byInverseOf: reference)
        }
        let yaw = Float(relative?.yaw ?? 0)
        let pitch = Float(relative?.pitch ?? 0)
        let roll = Float(relative?.roll ?? 0)
        lock.unlock()

        let location = switch motion.sensorLocation {
        case .headphoneLeft: "Left"
        case .headphoneRight: "Right"
        default: "AirPods"
        }

        let sample = HeadSample(
            yaw: yaw,
            pitch: pitch,
            roll: roll,
            yawRate: Float(motion.rotationRate.z),
            pitchRate: Float(motion.rotationRate.x),
            rollRate: Float(motion.rotationRate.y),
            connected: true,
            location: location
        )
        Task { @MainActor in
            StageModel.shared.ingest(sample, status: .tracking)
        }
    }

    private func publish(_ status: TrackingStatus) {
        Task { @MainActor in
            StageModel.shared.setTracking(status)
        }
    }
}
