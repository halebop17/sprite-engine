import SwiftUI
import AppKit

/// Full-screen image viewer. Click outside / Esc / X dismisses. Arrow keys
/// navigate when there's more than one image in the gallery.
struct ImageLightboxView: View {

    /// Source images. Use `[image]` for a single-shot lightbox.
    let images: [NSImage]
    /// Currently displayed index. Bound so arrow keys + tab strip can move it.
    @Binding var index: Int
    /// Set to nil/false by the host to dismiss.
    let onDismiss: () -> Void

    @State private var keyMonitor: Any?

    var body: some View {
        ZStack {
            Color.black.opacity(0.85)
                .ignoresSafeArea()
                .onTapGesture(perform: onDismiss)

            if images.indices.contains(index) {
                Image(nsImage: images[index])
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding(40)
                    .shadow(color: .black.opacity(0.6), radius: 30, y: 12)
            }

            VStack {
                HStack {
                    Spacer()
                    Button(action: onDismiss) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(.white.opacity(0.85), .black.opacity(0.5))
                    }
                    .buttonStyle(.plain)
                    .padding(20)
                    .keyboardShortcut(.cancelAction)
                }
                Spacer()
                if images.count > 1 {
                    HStack(spacing: 14) {
                        Button { step(-1) } label: {
                            Image(systemName: "chevron.left.circle.fill")
                                .font(.system(size: 28))
                                .foregroundStyle(.white.opacity(0.85), .black.opacity(0.5))
                        }
                        .buttonStyle(.plain)
                        .disabled(index == 0)

                        Text("\(index + 1) / \(images.count)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.85))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(.black.opacity(0.5))
                            .clipShape(Capsule())

                        Button { step(1) } label: {
                            Image(systemName: "chevron.right.circle.fill")
                                .font(.system(size: 28))
                                .foregroundStyle(.white.opacity(0.85), .black.opacity(0.5))
                        }
                        .buttonStyle(.plain)
                        .disabled(index >= images.count - 1)
                    }
                    .padding(.bottom, 24)
                }
            }
        }
        .onAppear {
            keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { e in
                switch e.keyCode {
                case 53: onDismiss(); return nil                  // Esc
                case 123: step(-1);   return nil                  // Left
                case 124: step(1);    return nil                  // Right
                default: return e
                }
            }
        }
        .onDisappear {
            if let m = keyMonitor { NSEvent.removeMonitor(m); keyMonitor = nil }
        }
    }

    private func step(_ delta: Int) {
        let next = index + delta
        if images.indices.contains(next) { index = next }
    }
}
