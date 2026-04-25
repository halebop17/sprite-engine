import SwiftUI
import UniformTypeIdentifiers

struct MediaTabView: View {

    let game: Game

    @Environment(\.appTheme) private var t
    @State private var items: [GameMediaItem] = []
    @State private var editingLabel: UUID?
    @State private var labelDraft = ""
    @State private var lightboxItem: GameMediaItem?

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            screenshotsSection
            documentsSection
        }
        .onAppear { items = GameMediaStore.load(for: game.id) }
        .sheet(item: $lightboxItem) { item in
            LightboxView(item: item, gameID: game.id)
        }
    }

    // MARK: - Screenshots

    private var screenshotsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("SCREENSHOTS")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(t.textFaint)
                    .kerning(0.8)
                Spacer()
                addButton("+ Add Image", action: pickImage)
            }

            let images = items.filter { $0.kind == .image }
            if images.isEmpty {
                emptyState(icon: "photo.on.rectangle", message: "No screenshots yet")
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)], spacing: 10) {
                    ForEach(images) { item in
                        ScreenshotCard(
                            item: item,
                            game: game,
                            isEditingLabel: editingLabel == item.id,
                            labelDraft: $labelDraft,
                            onTap: { lightboxItem = item },
                            onStartEdit: {
                                editingLabel = item.id
                                labelDraft = item.label
                            },
                            onCommitLabel: { commitLabel(item) },
                            onDelete: { deleteItem(item) }
                        )
                    }
                }
            }
        }
    }

    // MARK: - Documents

    private var documentsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("DOCUMENTS")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(t.textFaint)
                    .kerning(0.8)
                Spacer()
                addButton("+ Add PDF", action: pickPDF)
            }

            let pdfs = items.filter { $0.kind == .pdf }
            if pdfs.isEmpty {
                emptyState(icon: "doc.text", message: "No documents yet")
            } else {
                VStack(spacing: 0) {
                    ForEach(pdfs) { item in
                        PDFRow(item: item, game: game, onDelete: { deleteItem(item) })
                        if item.id != pdfs.last?.id {
                            Divider().background(t.divider).padding(.leading, 14)
                        }
                    }
                }
                .background(t.card)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(t.cardBorder, lineWidth: 1))
            }
        }
    }

    // MARK: - Helpers

    private func addButton(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(t.accent)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(t.accentSoft)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }

    private func emptyState(icon: String, message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(t.textFaint)
            Text(message)
                .font(.system(size: 13))
                .foregroundColor(t.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(t.card)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(t.cardBorder, lineWidth: 1))
    }

    // MARK: - File pickers

    private func pickImage() {
        let panel = NSOpenPanel()
        panel.title = "Add Screenshot"
        panel.allowedContentTypes = [.png, .jpeg, .tiff, .bmp, .gif, .heic]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.begin { response in
            guard response == .OK else { return }
            DispatchQueue.main.async {
                for url in panel.urls {
                    let label = url.deletingPathExtension().lastPathComponent
                    if let item = GameMediaStore.addItem(sourceURL: url, kind: .image, label: label, gameID: game.id) {
                        items.append(item)
                    }
                }
                GameMediaStore.save(items, for: game.id)
            }
        }
    }

    private func pickPDF() {
        let panel = NSOpenPanel()
        panel.title = "Add PDF Document"
        panel.allowedContentTypes = [.pdf]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.begin { response in
            guard response == .OK else { return }
            DispatchQueue.main.async {
                for url in panel.urls {
                    let label = url.deletingPathExtension().lastPathComponent
                    if let item = GameMediaStore.addItem(sourceURL: url, kind: .pdf, label: label, gameID: game.id) {
                        items.append(item)
                    }
                }
                GameMediaStore.save(items, for: game.id)
            }
        }
    }

    // MARK: - Mutations

    private func deleteItem(_ item: GameMediaItem) {
        GameMediaStore.delete(item, gameID: game.id)
        items.removeAll { $0.id == item.id }
        GameMediaStore.save(items, for: game.id)
    }

    private func commitLabel(_ item: GameMediaItem) {
        if let idx = items.firstIndex(where: { $0.id == item.id }) {
            items[idx].label = labelDraft
        }
        editingLabel = nil
        GameMediaStore.save(items, for: game.id)
    }
}

// MARK: - Lightbox

private struct LightboxView: View {
    let item: GameMediaItem
    let gameID: UUID
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let img = GameMediaStore.image(for: item, gameID: gameID) {
                Image(nsImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding(32)
            }
            VStack {
                HStack {
                    Text(item.label.isEmpty ? item.filename : item.label)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.75))
                        .padding(.leading, 16)
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(.white.opacity(0.7))
                            .padding(14)
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.escape, modifiers: [])
                }
                Spacer()
            }
        }
        .frame(minWidth: 520, minHeight: 380)
        .onTapGesture { dismiss() }
    }
}

// MARK: - Screenshot card

private struct ScreenshotCard: View {
    let item: GameMediaItem
    let game: Game
    let isEditingLabel: Bool
    @Binding var labelDraft: String
    let onTap: () -> Void
    let onStartEdit: () -> Void
    let onCommitLabel: () -> Void
    let onDelete: () -> Void

    @Environment(\.appTheme) private var t
    @State private var hovered = false

    var body: some View {
        VStack(spacing: 0) {
            // Image thumbnail
            ZStack(alignment: .topTrailing) {
                if let img = GameMediaStore.image(for: item, gameID: game.id) {
                    Image(nsImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(minHeight: 100, maxHeight: 120)
                        .clipped()
                        .contentShape(Rectangle())
                        .onTapGesture(perform: onTap)
                } else {
                    Rectangle()
                        .fill(t.systemTabsBg)
                        .frame(height: 100)
                    Image(systemName: "photo")
                        .font(.system(size: 24))
                        .foregroundColor(t.textFaint)
                }
                if hovered {
                    Button(action: onDelete) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.white)
                            .shadow(radius: 2)
                    }
                    .buttonStyle(.plain)
                    .padding(6)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 6))

            // Label
            if isEditingLabel {
                TextField("Label", text: $labelDraft, onCommit: onCommitLabel)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11))
                    .foregroundColor(t.text)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 5)
            } else {
                Text(item.label.isEmpty ? "Untitled" : item.label)
                    .font(.system(size: 11))
                    .foregroundColor(hovered ? t.text : t.textMuted)
                    .lineLimit(1)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 5)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .onTapGesture(count: 2, perform: onStartEdit)
            }
        }
        .background(t.card)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8)
            .strokeBorder(hovered ? t.accent.opacity(0.5) : t.cardBorder, lineWidth: 1))
        .onHover { hovered = $0 }
        .animation(.easeInOut(duration: 0.14), value: hovered)
        .help("Click to view full size")
    }
}

// MARK: - PDF row

private struct PDFRow: View {
    let item: GameMediaItem
    let game: Game
    let onDelete: () -> Void

    @Environment(\.appTheme) private var t
    @State private var hovered = false

    private func openInSystem() {
        let url = GameMediaStore.url(for: item, gameID: game.id)
        NSWorkspace.shared.open(url)
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "doc.richtext")
                .font(.system(size: 18))
                .foregroundColor(t.accent)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.label.isEmpty ? item.filename : item.label)
                    .font(.system(size: 13))
                    .foregroundColor(t.text)
                    .lineLimit(1)
                Text(GameMediaStore.fileSize(for: item, gameID: game.id))
                    .font(.system(size: 11))
                    .foregroundColor(t.textMuted)
            }

            Spacer()

            Button(action: openInSystem) {
                Image(systemName: "arrow.up.right.square")
                    .font(.system(size: 15))
                    .foregroundColor(hovered ? t.accent : t.textFaint)
            }
            .buttonStyle(.plain)
            .help("Open in default PDF viewer")

            if hovered {
                Button(action: onDelete) {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 15))
                        .foregroundColor(t.textFaint)
                }
                .buttonStyle(.plain)
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .onTapGesture(count: 2, perform: openInSystem)
        .onHover { hovered = $0 }
        .animation(.easeInOut(duration: 0.14), value: hovered)
        .help("Double-click to open")
    }
}
