import Foundation
import simd

enum DisplayMode: String, CaseIterable, Identifiable, Codable {
    case pin
    case follow
    case drift

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .pin: "Pin"
        case .follow: "Follow"
        case .drift: "Drift"
        }
    }

    var detail: String {
        switch self {
        case .pin: "Locked in the room"
        case .follow: "Stays in front of you"
        case .drift: "Stays put, then eases back"
        }
    }
}

struct HeadSample: Sendable {
    var yaw: Float = 0
    var pitch: Float = 0
    var roll: Float = 0
    var yawRate: Float = 0
    var pitchRate: Float = 0
    var rollRate: Float = 0
    var connected = false
    var location = ""
}

/// Turns a head sample into the rotation applied to the virtual screen.
///
/// Head yaw is positive when you turn left, in Core Motion's gravity-up frame.
/// The returned quaternion is applied to screen points: identity keeps the
/// screen centered. Pin counters the head so the screen stays where Recenter
/// left it.
struct PoseFilter {
    var mode: DisplayMode = .drift
    var levelHorizon = true
    var prediction: Float = 0.030
    var smoothingTau: Float = 0.045
    var driftTau: Float = 1.5
    var invertYaw: Float = 1
    var invertPitch: Float = 1
    var invertRoll: Float = 1

    private var anchorYaw: Float = 0
    private var anchorPitch: Float = 0
    private var smoothedYaw: Float = 0
    private var smoothedPitch: Float = 0
    private var smoothedRoll: Float = 0
    private var primed = false

    mutating func reset() {
        anchorYaw = 0
        anchorPitch = 0
        smoothedYaw = 0
        smoothedPitch = 0
        smoothedRoll = 0
        primed = false
    }

    mutating func viewRotation(sample: HeadSample, dt rawDt: Float) -> simd_quatf {
        guard sample.connected else {
            reset()
            return simd_quatf(ix: 0, iy: 0, iz: 0, r: 1)
        }

        let dt = min(max(rawDt, 0), 0.1)
        let yaw = sample.yaw * invertYaw + sample.yawRate * invertYaw * prediction
        let pitch = sample.pitch * invertPitch + sample.pitchRate * invertPitch * prediction
        let roll = levelHorizon ? 0 : sample.roll * invertRoll + sample.rollRate * invertRoll * prediction

        switch mode {
        case .follow:
            anchorYaw = yaw
            anchorPitch = pitch
        case .pin:
            break
        case .drift:
            let alpha = 1 - exp(-dt / max(driftTau, 0.05))
            anchorYaw += wrapAngle(yaw - anchorYaw) * alpha
            anchorPitch += (pitch - anchorPitch) * alpha
        }

        let targetYaw: Float
        let targetPitch: Float
        let targetRoll: Float
        if mode == .follow {
            targetYaw = 0
            targetPitch = 0
            targetRoll = 0
        } else {
            targetYaw = wrapAngle(anchorYaw - yaw)
            targetPitch = anchorPitch - pitch
            targetRoll = -roll
        }

        let alpha: Float = primed ? (1 - exp(-dt / max(smoothingTau, 0.001))) : 1
        primed = true
        smoothedYaw += wrapAngle(targetYaw - smoothedYaw) * alpha
        smoothedPitch += (targetPitch - smoothedPitch) * alpha
        smoothedRoll += (targetRoll - smoothedRoll) * alpha
        return euler(yaw: smoothedYaw, pitch: smoothedPitch, roll: smoothedRoll)
    }
}

func wrapAngle(_ angle: Float) -> Float {
    var value = angle
    let turn = Float.pi * 2
    while value > .pi {
        value -= turn
    }
    while value < -.pi {
        value += turn
    }
    return value
}

func euler(yaw: Float, pitch: Float, roll: Float) -> simd_quatf {
    let aroundY = simd_quatf(angle: yaw, axis: SIMD3<Float>(0, 1, 0))
    let aroundX = simd_quatf(angle: pitch, axis: SIMD3<Float>(1, 0, 0))
    let aroundZ = simd_quatf(angle: roll, axis: SIMD3<Float>(0, 0, 1))
    return simd_mul(aroundY, simd_mul(aroundX, aroundZ))
}
