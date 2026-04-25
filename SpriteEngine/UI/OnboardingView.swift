import SwiftUI

struct OnboardingView: View {

    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var library: ROMLibrary
    @EnvironmentObject private var conversionQueue: ConversionQueue
    @Environment(\.appTheme) private var t

    @State private var step: OnboardingStep = .welcome
    @State private var isScanning = false
    @State private var scannedCount = 0

    enum OnboardingStep { case welcome, bios, roms, done }

    var body: some View {
        ZStack {
            t.surface.ignoresSafeArea()
            // Subtle radial glow behind content
            RadialGradient(
                colors: [t.accent.opacity(0.08), .clear],
                center: .center,
                startRadius: 0,
                endRadius: 400)
            .ignoresSafeArea()

            VStack(spacing: 0) {
                stepIndicator
                    .padding(.top, 32)

                Spacer()

                Group {
                    switch step {
                    case .welcome: welcomeStep
                    case .bios:    biosStep
                    case .roms:    romsStep
                    case .done:    doneStep
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal:   .move(edge: .leading).combined(with: .opacity)
                ))
                .animation(.easeInOut(duration: 0.28), value: step)

                Spacer()
            }
            .frame(maxWidth: 480)
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Step indicator

    private var stepIndicator: some View {
        HStack(spacing: 6) {
            ForEach(0..<4) { i in
                let active = stepIndex == i
                let done   = stepIndex > i
                Capsule()
                    .fill(done ? t.accent : (active ? t.accent.opacity(0.7) : t.divider))
                    .frame(width: active ? 24 : 8, height: 6)
                    .animation(.easeInOut(duration: 0.22), value: step)
            }
        }
    }

    private var stepIndex: Int {
        switch step {
        case .welcome: return 0
        case .bios:    return 1
        case .roms:    return 2
        case .done:    return 3
        }
    }

    // MARK: - Welcome

    private var welcomeStep: some View {
        VStack(spacing: 28) {
            ZStack {
                Circle()
                    .fill(t.accent.opacity(0.12))
                    .frame(width: 88, height: 88)
                Circle()
                    .fill(t.accent.opacity(0.18))
                    .frame(width: 64, height: 64)
                Image(systemName: "arcade.stick.console")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundColor(t.accent)
            }

            VStack(spacing: 10) {
                Text("Welcome to Sprite Engine")
                    .font(.system(size: 26, weight: .heavy))
                    .foregroundColor(t.text)
                    .multilineTextAlignment(.center)
                Text("A multi-system arcade emulator for Neo Geo, CPS, Sega,\nToaplan, and Konami. Let's get you set up in three quick steps.")
                    .font(.system(size: 14))
                    .foregroundColor(t.textMuted)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }

            primaryButton("Get Started") { withAnimation { step = .bios } }
        }
        .padding(.horizontal, 32)
    }

    // MARK: - BIOS step

    private var biosStep: some View {
        VStack(spacing: 24) {
            stepHeader(
                icon: "externaldrive.badge.checkmark",
                title: "Set Up BIOS Files",
                detail: "Sprite Engine needs BIOS files to run games. Point it to a folder containing the required archives."
            )

            // Directory picker card
            directorCard(
                url: appState.biosDirectoryURL,
                placeholder: "No folder chosen",
                pick: pickBIOS
            )

            // Per-file status
            VStack(spacing: 6) {
                biosFileRow("neogeo.zip", needed: "Neo Geo / MVS / AES")
                biosFileRow("qsound.zip", needed: "CPS-2 Q-Sound")
                biosFileRow("aes.zip",    needed: "Neo Geo AES (optional)")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(t.card)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(t.cardBorder, lineWidth: 1))

            navButtons(
                canContinue: appState.biosDirectoryURL != nil,
                onBack: { withAnimation { step = .welcome } },
                onNext: { withAnimation { step = .roms } }
            )
        }
        .padding(.horizontal, 32)
    }

    private func biosFileRow(_ filename: String, needed: String) -> some View {
        let found = biosFileExists(filename)
        return HStack(spacing: 10) {
            Image(systemName: found ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 13))
                .foregroundColor(found ? Color(hex: "30d158") : t.textFaint)
            Text(filename)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(t.text)
            Spacer()
            Text(needed)
                .font(.system(size: 11))
                .foregroundColor(t.textMuted)
        }
    }

    private func biosFileExists(_ name: String) -> Bool {
        guard let dir = appState.biosDirectoryURL else { return false }
        return FileManager.default.fileExists(atPath: dir.appendingPathComponent(name).path)
    }

    // MARK: - ROMs step

    private var romsStep: some View {
        VStack(spacing: 24) {
            stepHeader(
                icon: "folder.badge.plus",
                title: "Add Your ROMs",
                detail: "Add one or more folders containing your ROM files. Sprite Engine will scan them for .neo and .zip archives."
            )

            // Folder list
            VStack(spacing: 0) {
                ForEach(appState.romDirectoryURLs, id: \.self) { url in
                    HStack(spacing: 10) {
                        Image(systemName: "folder.fill")
                            .font(.system(size: 13))
                            .foregroundColor(t.accent)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(url.lastPathComponent)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(t.text)
                            Text(url.path)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(t.textMuted)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        Spacer()
                        Button {
                            appState.removeROMDirectory(url)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .font(.system(size: 15))
                                .foregroundColor(t.textFaint)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    Divider().background(t.divider).padding(.leading, 14)
                }
                Button(action: pickROMs) {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(t.accent)
                        Text("Add Folder…")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(t.accent)
                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
            }
            .background(t.card)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(
                appState.romDirectoryURLs.isEmpty ? t.cardBorder : t.accent.opacity(0.4),
                lineWidth: 1))

            // Scan result / status
            HStack(spacing: 10) {
                if isScanning {
                    ProgressView().scaleEffect(0.75)
                    Text("Scanning…")
                        .font(.system(size: 12))
                        .foregroundColor(t.textMuted)
                } else if scannedCount > 0 {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundColor(Color(hex: "30d158"))
                    Text("\(scannedCount) game\(scannedCount == 1 ? "" : "s") found")
                        .font(.system(size: 12))
                        .foregroundColor(t.text)
                } else if !appState.romDirectoryURLs.isEmpty {
                    Image(systemName: "tray")
                        .font(.system(size: 13))
                        .foregroundColor(t.textFaint)
                    Text("No supported ROMs found in those folders")
                        .font(.system(size: 12))
                        .foregroundColor(t.textMuted)
                } else {
                    Image(systemName: "info.circle")
                        .font(.system(size: 13))
                        .foregroundColor(t.textFaint)
                    Text("You can also import ROMs individually from the library")
                        .font(.system(size: 12))
                        .foregroundColor(t.textMuted)
                }
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(t.card)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(t.cardBorder, lineWidth: 1))

            navButtons(
                canContinue: true,
                onBack: { withAnimation { step = .bios } },
                onNext: { withAnimation { step = .done } }
            )
        }
        .padding(.horizontal, 32)
    }

    // MARK: - Done step

    private var doneStep: some View {
        VStack(spacing: 28) {
            ZStack {
                Circle()
                    .fill(Color(hex: "30d158").opacity(0.12))
                    .frame(width: 88, height: 88)
                Circle()
                    .fill(Color(hex: "30d158").opacity(0.18))
                    .frame(width: 64, height: 64)
                Image(systemName: "checkmark")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(Color(hex: "30d158"))
            }

            VStack(spacing: 10) {
                Text("You're all set!")
                    .font(.system(size: 26, weight: .heavy))
                    .foregroundColor(t.text)
                    .multilineTextAlignment(.center)
                Text(doneSubtitle)
                    .font(.system(size: 14))
                    .foregroundColor(t.textMuted)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }

            // Stats chips
            HStack(spacing: 10) {
                statChip(icon: "gamecontroller", value: "\(library.games.count)", label: "games")
                if !appState.isBIOSPresent {
                    statChip(icon: "exclamationmark.triangle", value: "BIOS", label: "not found")
                } else {
                    statChip(icon: "checkmark.shield", value: "BIOS", label: "ready")
                }
                let pending = conversionQueue.items.filter { $0.state.isPending }.count
                if pending > 0 {
                    statChip(icon: "arrow.triangle.2.circlepath", value: "\(pending)", label: "converting")
                }
            }

            primaryButton("Open Library") { appState.completeOnboarding() }

            if !appState.isBIOSPresent {
                Button("Configure BIOS in Settings") { appState.completeOnboarding(); appState.navigate(to: .settings) }
                    .font(.system(size: 12))
                    .foregroundColor(t.accent)
                    .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 32)
    }

    private var doneSubtitle: String {
        let count = library.games.count
        if count > 0 {
            return "\(count) game\(count == 1 ? "" : "s") ready to play. You can import more anytime from the library."
        }
        return "Your library is empty for now — import ROMs anytime from the library or drag-and-drop into the Import screen."
    }

    // MARK: - Shared sub-views

    private func stepHeader(icon: String, title: String, detail: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 28, weight: .semibold))
                .foregroundColor(t.accent)
                .frame(width: 56, height: 56)
                .background(t.accentSoft)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            VStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 20, weight: .heavy))
                    .foregroundColor(t.text)
                Text(detail)
                    .font(.system(size: 13))
                    .foregroundColor(t.textMuted)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }
        }
    }

    private func directorCard(url: URL?, placeholder: String, pick: @escaping () -> Void) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "folder")
                .font(.system(size: 16))
                .foregroundColor(url != nil ? t.accent : t.textFaint)
                .frame(width: 32, height: 32)
                .background(url != nil ? t.accentSoft : t.card)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 2) {
                if let url {
                    Text(url.lastPathComponent)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(t.text)
                    Text(url.path)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(t.textMuted)
                        .lineLimit(1)
                        .truncationMode(.middle)
                } else {
                    Text(placeholder)
                        .font(.system(size: 13))
                        .foregroundColor(t.textFaint)
                }
            }
            Spacer()
            Button("Choose…", action: pick)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(LinearGradient(colors: [t.playBtnStart, t.playBtnEnd],
                                           startPoint: .topLeading, endPoint: .bottomTrailing))
                .clipShape(RoundedRectangle(cornerRadius: 7))
                .shadow(color: t.accent.opacity(0.35), radius: 4, y: 2)
                .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(t.card)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(
            url != nil ? t.accent.opacity(0.4) : t.cardBorder, lineWidth: 1))
    }

    private func navButtons(canContinue: Bool,
                            onBack: @escaping () -> Void,
                            onNext: @escaping () -> Void) -> some View {
        HStack(spacing: 10) {
            Button(action: onBack) {
                HStack(spacing: 5) {
                    Image(systemName: "chevron.left").font(.system(size: 11, weight: .semibold))
                    Text("Back")
                }
                .font(.system(size: 13))
                .foregroundColor(t.textMuted)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(t.card)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(t.cardBorder, lineWidth: 1))
            }
            .buttonStyle(.plain)

            Spacer()

            if !canContinue {
                Button("Skip for now") { onNext() }
                    .font(.system(size: 12))
                    .foregroundColor(t.textMuted)
                    .buttonStyle(.plain)
            }

            primaryButton(canContinue ? "Continue" : "Continue anyway", action: onNext)
        }
    }

    private func primaryButton(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(label)
                    .font(.system(size: 14, weight: .bold))
                Image(systemName: "arrow.right")
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 10)
            .background(LinearGradient(colors: [t.playBtnStart, t.playBtnEnd],
                                       startPoint: .topLeading, endPoint: .bottomTrailing))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .shadow(color: t.accent.opacity(0.4), radius: 8, y: 3)
        }
        .buttonStyle(.plain)
    }

    private func statChip(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(t.accent)
            Text(value)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(t.text)
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(t.textMuted)
        }
        .frame(minWidth: 72)
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .background(t.card)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(t.cardBorder, lineWidth: 1))
    }

    // MARK: - File pickers

    private func pickBIOS() {
        let panel = NSOpenPanel()
        panel.title = "Choose BIOS Folder"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            DispatchQueue.main.async { appState.setBIOSDirectory(url) }
        }
    }

    private func pickROMs() {
        let panel = NSOpenPanel()
        panel.title = "Choose ROM Folder"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            DispatchQueue.main.async {
                appState.addROMDirectory(url)
                scanAllROMs()
            }
        }
    }

    private func scanAllROMs() {
        guard !appState.romDirectoryURLs.isEmpty else { return }
        isScanning = true
        let dirs = appState.romDirectoryURLs
        Task {
            await library.scan(directories: dirs)
            await MainActor.run {
                scannedCount = library.games.count
                isScanning   = false
            }
        }
    }
}
