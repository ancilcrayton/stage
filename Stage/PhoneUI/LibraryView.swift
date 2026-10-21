import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

struct LibraryView: View {
    @Environment(StageModel.self) private var model
    @State private var importingFile = false
    @State private var showLink = false
    @State private var linkText = ""
    @State private var photoItem: PhotosPickerItem?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                ConnectionRow()
                if !model.glassesConnected {
                    Text("Plug the glasses into USB-C. Until they connect, playback fills the phone and the glasses mirror it.")
                        .font(.footnote)
                        .foregroundStyle(Theme.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                ModeCapsule()
                Text(model.mode.detail)
                    .font(.footnote)
                    .foregroundStyle(Theme.secondary)
                PlacementCard()
                HStack {
                    Spacer()
                    RecenterButton(diameter: 96) { model.recenter() }
                    Spacer()
                }

                if let error = model.library.lastError {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(Theme.accent)
                }

                if !model.library.continueWatching.isEmpty {
                    sectionTitle("Continue")
                    ForEach(model.library.continueWatching.prefix(3)) { item in
                        MediaRow(item: item)
                    }
                }

                sectionTitle("Library")
                if model.library.items.isEmpty {
                    empty
                } else {
                    ForEach(model.library.items) { item in
                        MediaRow(item: item)
                            .contextMenu {
                                Button("Remove", role: .destructive) {
                                    model.library.remove(item)
                                }
                            }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .safeAreaInset(edge: .bottom) { addBar }
        .fileImporter(
            isPresented: $importingFile,
            allowedContentTypes: [.movie, .mpeg4Movie, .quickTimeMovie]
        ) { result in
            if case let .success(url) = result {
                Task { await model.importFile(from: url) }
            }
        }
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task { await model.importPhoto(item) }
            photoItem = nil
        }
        .sheet(isPresented: $showLink) { linkSheet }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Stage")
                .font(.system(size: 44, weight: .medium, design: .serif))
                .foregroundStyle(Theme.text)
            Text("Private cinema")
                .font(.subheadline)
                .foregroundStyle(Theme.secondary)
        }
        .padding(.top, 8)
    }

    private var empty: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Nothing here yet")
                .font(.title3.weight(.medium))
                .foregroundStyle(Theme.text)
            Text("Add a video from Files, Photos, or a direct link. The glasses show a test card until it plays, so you can try Pin and Drift first.")
                .font(.subheadline)
                .foregroundStyle(Theme.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Theme.line, lineWidth: 1))
    }

    private var addBar: some View {
        HStack(spacing: 8) {
            addButton("folder", "Files") { importingFile = true }
            PhotosPicker(selection: $photoItem, matching: .videos) {
                addLabel("photo", "Photos")
            }
            .buttonStyle(.plain)
            addButton("link", "Link") { showLink = true }
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(Theme.background.opacity(0.94))
        .overlay(alignment: .top) { Rectangle().fill(Theme.line).frame(height: 1) }
    }

    private var linkSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("A direct MP4 or HLS link you have the right to play.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondary)
                TextField("https://", text: $linkText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                    .padding(14)
                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .foregroundStyle(Theme.text)
                Spacer()
            }
            .padding(20)
            .background(Theme.background)
            .navigationTitle("Video link")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showLink = false }
                        .foregroundStyle(Theme.secondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        model.addLink(linkText)
                        linkText = ""
                        showLink = false
                    }
                    .foregroundStyle(Theme.accent)
                }
            }
        }
        .presentationDetents([.medium])
        .presentationBackground(Theme.background)
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(Theme.secondary)
            .textCase(.uppercase)
            .tracking(1.1)
    }

    private func addButton(_ symbol: String, _ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { addLabel(symbol, title) }
            .buttonStyle(.plain)
    }

    private func addLabel(_ symbol: String, _ title: String) -> some View {
        HStack(spacing: 6) {
            if model.library.isImporting {
                ProgressView().controlSize(.small).tint(Theme.accent)
            } else {
                Image(systemName: symbol)
            }
            Text(title)
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(Theme.text)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Theme.surface, in: Capsule())
        .overlay(Capsule().stroke(Theme.line, lineWidth: 1))
    }
}

struct ConnectionRow: View {
    @Environment(StageModel.self) private var model

    var body: some View {
        HStack(spacing: 8) {
            StatusPill(
                title: "Glasses",
                value: model.glassesConnected ? "Connected" : "Phone",
                live: model.glassesConnected
            )
            StatusPill(
                title: "AirPods",
                value: model.tracking.title,
                live: model.tracking.isLive
            )
            Spacer(minLength: 0)
            Button {
                model.showTuning = true
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.body.weight(.medium))
                    .foregroundStyle(Theme.secondary)
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Tuning")
        }
    }
}

private struct MediaRow: View {
    @Environment(StageModel.self) private var model
    let item: MediaItem

    var body: some View {
        Button {
            model.open(item)
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Text(item.title)
                        .font(.body.weight(.medium))
                        .foregroundStyle(Theme.text)
                        .lineLimit(1)
                    Spacer()
                    Text(clock(item.duration))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(Theme.secondary)
                }
                progress
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Theme.line, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var progress: some View {
        if item.duration > 0, item.position > 0 {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.08))
                    Capsule()
                        .fill(Theme.accent)
                        .frame(width: geo.size.width * min(item.position / item.duration, 1))
                }
            }
            .frame(height: 3)
        }
    }
}
