import SwiftUI

struct MirrorSheet: View {
    @Environment(StageModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("These apps play on the glasses as a normal mirror. Stage can’t see their picture, so Pin, Follow, and Drift pause until you come back.")
                        .font(.subheadline)
                        .foregroundStyle(Theme.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.bottom, 6)
                    ForEach(MirrorDestination.all) { destination in
                        Button {
                            model.openMirror(destination)
                            dismiss()
                        } label: {
                            HStack(alignment: .top, spacing: 14) {
                                Image(systemName: destination.symbol)
                                    .font(.title3)
                                    .foregroundStyle(Theme.accent)
                                    .frame(width: 28)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(destination.title)
                                        .font(.body.weight(.semibold))
                                        .foregroundStyle(Theme.text)
                                    Text(destination.detail)
                                        .font(.footnote)
                                        .foregroundStyle(Theme.secondary)
                                        .multilineTextAlignment(.leading)
                                }
                                Spacer(minLength: 0)
                            }
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(Theme.line, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    if let mirrorError = model.mirrorError {
                        Text(mirrorError)
                            .font(.footnote)
                            .foregroundStyle(Theme.accent)
                    }
                }
                .padding(20)
            }
            .background(Theme.background)
            .navigationTitle("Another app")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(Theme.secondary)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationBackground(Theme.background)
    }
}
