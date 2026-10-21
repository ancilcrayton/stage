import SwiftUI
import UIKit

enum Theme {
    static let background = Color(red: 7 / 255, green: 8 / 255, blue: 12 / 255)
    static let surface = Color(red: 18 / 255, green: 20 / 255, blue: 26 / 255)
    static let text = Color(red: 244 / 255, green: 241 / 255, blue: 234 / 255)
    static let secondary = Color(red: 154 / 255, green: 149 / 255, blue: 140 / 255)
    static let accent = Color(red: 231 / 255, green: 177 / 255, blue: 90 / 255)
    static let line = Color.white.opacity(0.08)
}

enum ThemeUI {
    static let background = UIColor(red: 7 / 255, green: 8 / 255, blue: 12 / 255, alpha: 1)
    static let accent = UIColor(red: 231 / 255, green: 177 / 255, blue: 90 / 255, alpha: 1)
}

func clock(_ seconds: Double) -> String {
    guard seconds.isFinite, seconds > 0 else { return "0:00" }
    let total = Int(seconds.rounded(.down))
    let hours = total / 3600
    let minutes = (total % 3600) / 60
    let secs = total % 60
    if hours > 0 {
        return String(format: "%d:%02d:%02d", hours, minutes, secs)
    }
    return String(format: "%d:%02d", minutes, secs)
}

struct PhoneHosted: View {
    var body: some View {
        PhoneRootView()
            .environment(StageModel.shared)
    }
}

struct StatusPill: View {
    var title: String
    var value: String
    var live: Bool

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(live ? Theme.accent : Theme.secondary.opacity(0.45))
                .frame(width: 6, height: 6)
            Text(title)
                .foregroundStyle(Theme.secondary)
            Text(value)
                .foregroundStyle(Theme.text)
        }
        .font(.caption.weight(.medium))
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Theme.surface, in: Capsule())
        .overlay(Capsule().stroke(Theme.line, lineWidth: 1))
    }
}

struct ModeCapsule: View {
    @Environment(StageModel.self) private var model

    var body: some View {
        HStack(spacing: 4) {
            ForEach(DisplayMode.allCases) { mode in
                let selected = model.mode == mode
                Button {
                    model.setMode(mode)
                } label: {
                    Text(mode.title)
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .foregroundStyle(selected ? Color.black : Theme.text)
                        .background(selected ? Theme.accent : Color.clear, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Theme.surface, in: Capsule())
        .overlay(Capsule().stroke(Theme.line, lineWidth: 1))
        .animation(.spring(duration: 0.35, bounce: 0.18), value: model.mode)
    }
}

struct PlacementCard: View {
    @Environment(StageModel.self) private var model

    var body: some View {
        @Bindable var model = model
        VStack(alignment: .leading, spacing: 16) {
            Toggle(isOn: $model.levelHorizon) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Level")
                        .foregroundStyle(Theme.text)
                    Text("Keep the horizon flat")
                        .font(.caption)
                        .foregroundStyle(Theme.secondary)
                }
            }
            .tint(Theme.accent)
            .onChange(of: model.levelHorizon) { _, _ in model.savePreferences() }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Size")
                        .foregroundStyle(Theme.text)
                    Spacer()
                    Text(model.mode.detail)
                        .font(.caption)
                        .foregroundStyle(Theme.secondary)
                }
                Slider(value: $model.screenSize, in: 0.15 ... 1)
                    .tint(Theme.accent)
                    .onChange(of: model.screenSize) { _, _ in model.savePreferences() }
            }
        }
        .padding(16)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Theme.line, lineWidth: 1))
    }
}

struct RecenterButton: View {
    var diameter: CGFloat = 120
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: diameter * 0.22, weight: .medium))
                Text("Recenter")
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(Theme.text)
            .frame(width: diameter, height: diameter)
            .background(Theme.surface, in: Circle())
            .overlay(Circle().stroke(Theme.accent.opacity(0.85), lineWidth: 1.5))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Recenter")
    }
}
