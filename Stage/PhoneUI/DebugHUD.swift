import SwiftUI

struct DebugHUD: View {
    @Environment(StageModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var model = model
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    readout
                    invert("Invert yaw", isOn: $model.invertYaw)
                    invert("Invert pitch", isOn: $model.invertPitch)
                    invert("Invert roll", isOn: $model.invertRoll)
                    slider("Prediction", value: $model.predictionMs, range: 0 ... 80, suffix: "ms")
                    slider("Smoothing", value: $model.smoothingMs, range: 0 ... 120, suffix: "ms")
                    slider("Drift", value: $model.driftSeconds, range: 0.4 ... 4, suffix: "s")
                    slider("Curve", value: $model.curve, range: 0 ... 1, suffix: "")
                    Button {
                        model.pictureTurns = (model.pictureTurns + 1) % 4
                        model.savePreferences()
                    } label: {
                        HStack {
                            Text("Rotate picture")
                            Spacer()
                            Text("\(model.pictureTurns * 90)°")
                                .foregroundStyle(Theme.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Theme.text)
                    Text("Assign the Recenter shortcut to the Action button in Settings. Yaw drift is normal with AirPods. Recenter when the screen wanders.")
                        .font(.footnote)
                        .foregroundStyle(Theme.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(20)
            }
            .background(Theme.background)
            .navigationTitle("Tuning")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        model.savePreferences()
                        dismiss()
                    }
                    .foregroundStyle(Theme.accent)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationBackground(Theme.background)
    }

    private var readout: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(String(format: "Yaw %+.1f°   Pitch %+.1f°   Roll %+.1f°", model.yawDegrees, model.pitchDegrees, model.rollDegrees))
            Text(String(format: "%.0f fps  ·  %@  ·  %@", model.framesPerSecond, model.audioRoute, model.glassesConnected ? "Glasses" : "Phone screen"))
            if !model.sensorLocation.isEmpty {
                Text(model.sensorLocation)
            }
        }
        .font(.caption.monospaced())
        .foregroundStyle(Theme.text)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func invert(_ title: String, isOn: Binding<Bool>) -> some View {
        Toggle(title, isOn: isOn)
            .tint(Theme.accent)
            .foregroundStyle(Theme.text)
            .onChange(of: isOn.wrappedValue) { _, _ in model.savePreferences() }
    }

    private func slider(_ title: String, value: Binding<Double>, range: ClosedRange<Double>, suffix: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                Spacer()
                Text(suffix.isEmpty ? String(format: "%.2f", value.wrappedValue) : String(format: "%.0f %@", value.wrappedValue, suffix))
                    .foregroundStyle(Theme.secondary)
                    .monospacedDigit()
            }
            .font(.subheadline)
            .foregroundStyle(Theme.text)
            Slider(value: value, in: range)
                .tint(Theme.accent)
                .onChange(of: value.wrappedValue) { _, _ in model.savePreferences() }
        }
    }
}
