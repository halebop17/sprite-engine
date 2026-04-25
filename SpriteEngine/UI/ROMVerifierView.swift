import SwiftUI

struct ROMVerifierView: View {

    @EnvironmentObject private var library: ROMLibrary
    @Environment(\.appTheme) private var t

    @State private var results:    [GameVerificationResult] = []
    @State private var isRunning   = false
    @State private var progress    = 0
    @State private var total       = 0
    @State private var done        = false
    @State private var expandedID: UUID? = nil
    @State private var filter: Filter = .all

    enum Filter: String, CaseIterable {
        case all    = "All"
        case issues = "Issues"
        case ok     = "OK"
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            Divider().background(t.divider)

            if !done && !isRunning {
                emptyState
            } else if isRunning {
                progressView
            } else {
                resultList
            }
        }
        .background(t.surface)
        .frame(minWidth: 560, minHeight: 480)
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack(spacing: 12) {
            BackButton()
            Spacer()
            Text("ROM Verifier")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(t.text)
            Spacer()
            if done {
                Picker("", selection: $filter) {
                    ForEach(Filter.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .frame(width: 180)
            }
            Button(isRunning ? "Running…" : "Verify All ROMs") {
                runVerification()
            }
            .disabled(isRunning)
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isRunning ? t.textFaint : t.accent, in: RoundedRectangle(cornerRadius: 7))
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(t.toolbar)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.shield")
                .font(.system(size: 48))
                .foregroundColor(t.textFaint)
            Text("Check every ROM in your library against\nFBNeo's built-in database of required files and CRC checksums.")
                .font(.system(size: 13))
                .foregroundColor(t.textMuted)
                .multilineTextAlignment(.center)
            Button("Start Verification") { runVerification() }
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 8)
                .background(t.accent, in: RoundedRectangle(cornerRadius: 8))
                .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Progress

    private var progressView: some View {
        VStack(spacing: 14) {
            ProgressView(value: total > 0 ? Double(progress) / Double(total) : 0)
                .progressViewStyle(.linear)
                .frame(width: 320)
                .accentColor(t.accent)
            Text("Checking \(progress) of \(total) games…")
                .font(.system(size: 12))
                .foregroundColor(t.textMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Result list

    private var resultList: some View {
        let filtered = results.filter { r in
            switch filter {
            case .all:    return true
            case .issues: return !r.status.isOK
            case .ok:     return r.status.isOK
            }
        }
        let okCount      = results.filter { $0.status.isOK }.count
        let issueCount   = results.count - okCount

        return VStack(spacing: 0) {
            // Summary bar
            HStack(spacing: 20) {
                Label("\(okCount) OK", systemImage: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Label("\(issueCount) issues", systemImage: "exclamationmark.triangle.fill")
                    .foregroundColor(issueCount > 0 ? .orange : t.textFaint)
                Spacer()
                Text("\(results.count) games checked")
                    .foregroundColor(t.textMuted)
            }
            .font(.system(size: 12, weight: .semibold))
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(t.toolbar)

            Divider().background(t.divider)

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(filtered) { result in
                        gameRow(result)
                        Divider().background(t.divider).padding(.leading, 16)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    // MARK: - Game row

    @ViewBuilder
    private func gameRow(_ result: GameVerificationResult) -> some View {
        let expanded = expandedID == result.id
        let problemFiles = result.files.filter { !$0.status.isOK }

        VStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    expandedID = expanded ? nil : result.id
                }
            } label: {
                HStack(spacing: 10) {
                    // Status icon
                    statusIcon(result.status)
                        .frame(width: 20)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(result.game.title)
                            .font(.system(size: 13))
                            .foregroundColor(t.text)
                            .lineLimit(1)
                        Text(result.status.label)
                            .font(.system(size: 11))
                            .foregroundColor(result.status.isOK ? t.textMuted : .orange)
                    }

                    Spacer()

                    if !result.status.isOK && !result.files.isEmpty {
                        Image(systemName: expanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 10))
                            .foregroundColor(t.textFaint)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if expanded && !result.files.isEmpty {
                fileList(result.files)
                    .padding(.bottom, 6)
            }
        }
    }

    @ViewBuilder
    private func fileList(_ files: [ROMFileResult]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(files.filter { !$0.status.isOK }) { file in
                HStack(spacing: 8) {
                    Image(systemName: fileStatusIcon(file.status))
                        .font(.system(size: 10))
                        .foregroundColor(fileStatusColor(file.status))
                        .frame(width: 14)
                    Text(file.name)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(t.text)
                    Spacer()
                    Text(file.status.label)
                        .font(.system(size: 10))
                        .foregroundColor(fileStatusColor(file.status))
                        .lineLimit(1)
                }
                .padding(.horizontal, 40)
                .padding(.vertical, 3)
            }
        }
        .padding(.top, 4)
        .background(t.card.opacity(0.5))
    }

    // MARK: - Helpers

    @ViewBuilder
    private func statusIcon(_ status: GameVerificationStatus) -> some View {
        switch status {
        case .ok:
            Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
        case .issues(let m, _) where m > 0:
            Image(systemName: "xmark.circle.fill").foregroundColor(.red)
        case .issues:
            Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.orange)
        case .unknownGame:
            Image(systemName: "questionmark.circle.fill").foregroundColor(t.textFaint)
        }
    }

    private func fileStatusIcon(_ s: ROMFileStatus) -> String {
        switch s {
        case .ok:       return "checkmark.circle"
        case .missing:  return "xmark.circle"
        case .wrongCRC: return "exclamationmark.triangle"
        case .optional: return "minus.circle"
        }
    }

    private func fileStatusColor(_ s: ROMFileStatus) -> Color {
        switch s {
        case .ok:       return .green
        case .missing:  return .red
        case .wrongCRC: return .orange
        case .optional: return t.textFaint
        }
    }

    // MARK: - Run

    private func runVerification() {
        guard !isRunning else { return }
        done      = false
        results   = []
        isRunning = true
        expandedID = nil

        ROMVerifier.shared.verify(
            games: library.games,
            onProgress: { idx, count in
                self.progress = idx
                self.total    = count
            },
            completion: { res in
                self.results   = res.sorted { !$0.status.isOK && $1.status.isOK }
                self.isRunning = false
                self.done      = true
            }
        )
    }
}
