import SwiftUI

// MARK: - Box art shape

enum BoxArtShape: CaseIterable {
    case tank, fighters, sword, wolf, blade, bubble, ball
}

// MARK: - Game art helpers

extension Game {
    private var colorSeed: Int {
        title.unicodeScalars.reduce(0) { ($0 &* 31) &+ Int($1.value) }
    }

    var boxArtShape: BoxArtShape {
        BoxArtShape.allCases[abs(colorSeed) % BoxArtShape.allCases.count]
    }

    var boxArtDarkColor: Color {
        let idx = abs(colorSeed) % 6
        let hues: [Double] = [0.0, 0.03, 0.1, 0.55, 0.6, 0.7]
        return Color(hue: hues[idx], saturation: 0.7, brightness: 0.07)
    }

    var boxArtAccentColor: Color {
        let idx = abs(colorSeed / 7) % 7
        let hues:       [Double] = [0.02, 0.06, 0.55, 0.58, 0.65, 0.75, 0.0]
        let saturations:[Double] = [0.9,  0.85, 0.8,  0.85, 0.75, 0.7,  0.95]
        let brightnesses:[Double] = [0.85, 0.8,  0.75, 0.8,  0.7,  0.65, 0.9]
        return Color(hue: hues[idx], saturation: saturations[idx], brightness: brightnesses[idx])
    }
}

// MARK: - Box art shape Canvas layer

private struct ShapeLayer: View {
    let shape: BoxArtShape
    let w: CGFloat
    let h: CGFloat
    let color: Color

    var body: some View {
        Canvas { ctx, _ in
            let c = color
            switch shape {
            case .tank:     drawTank(ctx: &ctx, w: w, h: h, c: c)
            case .fighters: drawFighters(ctx: &ctx, w: w, h: h, c: c)
            case .sword:    drawSword(ctx: &ctx, w: w, h: h, c: c)
            case .wolf:     drawWolf(ctx: &ctx, w: w, h: h, c: c)
            case .blade:    drawBlade(ctx: &ctx, w: w, h: h, c: c)
            case .bubble:   drawBubble(ctx: &ctx, w: w, h: h, c: c)
            case .ball:     drawBall(ctx: &ctx, w: w, h: h, c: c)
            }
        }
        .frame(width: w, height: h)
    }

    // MARK: Shape drawing

    private func drawTank(ctx: inout GraphicsContext, w: CGFloat, h: CGFloat, c: Color) {
        let lw: CGFloat = 1.8
        // Body
        var p = Path()
        p.addRoundedRect(in: CGRect(x: w*0.08, y: h*0.32, width: w*0.84, height: h*0.12), cornerSize: CGSize(width: 3, height: 3))
        ctx.fill(p, with: .color(c.opacity(0.14)))
        ctx.stroke(p, with: .color(c), lineWidth: lw)
        // Turret
        var t = Path()
        t.addRoundedRect(in: CGRect(x: w*0.18, y: h*0.19, width: w*0.64, height: h*0.14), cornerSize: CGSize(width: 3, height: 3))
        ctx.fill(t, with: .color(c.opacity(0.09)))
        ctx.stroke(t, with: .color(c), lineWidth: lw)
        // Wheels
        ctx.stroke(Path(ellipseIn: CGRect(x: w*0.25-w*0.085, y: h*0.46-w*0.085, width: w*0.17, height: w*0.17)), with: .color(c), lineWidth: lw)
        ctx.stroke(Path(ellipseIn: CGRect(x: w*0.75-w*0.085, y: h*0.46-w*0.085, width: w*0.17, height: w*0.17)), with: .color(c), lineWidth: lw)
        // Barrel + crossbar
        var b = Path()
        b.addRoundedRect(in: CGRect(x: w*0.42, y: h*0.08, width: w*0.07, height: h*0.13), cornerSize: CGSize(width: 2, height: 2))
        ctx.stroke(b, with: .color(c), lineWidth: lw)
        var l = Path(); l.move(to: CGPoint(x: w*0.35, y: h*0.25)); l.addLine(to: CGPoint(x: w*0.65, y: h*0.25))
        ctx.stroke(l, with: .color(c), lineWidth: lw)
    }

    private func drawFighters(ctx: inout GraphicsContext, w: CGFloat, h: CGFloat, c: Color) {
        let lw: CGFloat = 1.6
        ctx.stroke(Path(ellipseIn: CGRect(x: w*0.22, y: h*0.18, width: w*0.24, height: w*0.24)), with: .color(c), lineWidth: lw)
        ctx.stroke(Path(ellipseIn: CGRect(x: w*0.54, y: h*0.18, width: w*0.24, height: w*0.24)), with: .color(c), lineWidth: lw)
        var arc = Path()
        arc.move(to: CGPoint(x: w*0.22, y: h*0.5))
        arc.addCurve(to: CGPoint(x: w*0.78, y: h*0.5),
                     control1: CGPoint(x: w*0.25, y: h*0.25),
                     control2: CGPoint(x: w*0.75, y: h*0.25))
        ctx.stroke(arc, with: .color(c), lineWidth: lw)
        var l1 = Path(); l1.move(to: CGPoint(x: w*0.28, y: h*0.42)); l1.addLine(to: CGPoint(x: w*0.38, y: h*0.62))
        ctx.stroke(l1, with: .color(c), lineWidth: lw)
        var l2 = Path(); l2.move(to: CGPoint(x: w*0.72, y: h*0.42)); l2.addLine(to: CGPoint(x: w*0.62, y: h*0.62))
        ctx.stroke(l2, with: .color(c), lineWidth: lw)
        var l3 = Path(); l3.move(to: CGPoint(x: w*0.38, y: h*0.62)); l3.addLine(to: CGPoint(x: w*0.62, y: h*0.62))
        ctx.stroke(l3, with: .color(c), lineWidth: lw)
    }

    private func drawSword(ctx: inout GraphicsContext, w: CGFloat, h: CGFloat, c: Color) {
        let lw: CGFloat = 1.8
        var blade = Path(); blade.move(to: CGPoint(x: w*0.5, y: h*0.05)); blade.addLine(to: CGPoint(x: w*0.5, y: h*0.7))
        ctx.stroke(blade, with: .color(c), lineWidth: lw)
        var tip = Path(); tip.move(to: CGPoint(x: w*0.5, y: h*0.05)); tip.addLine(to: CGPoint(x: w*0.44, y: h*0.2)); tip.addLine(to: CGPoint(x: w*0.56, y: h*0.2)); tip.closeSubpath()
        ctx.fill(tip, with: .color(c.opacity(0.25)))
        var guard_ = Path(); guard_.move(to: CGPoint(x: w*0.18, y: h*0.38)); guard_.addLine(to: CGPoint(x: w*0.82, y: h*0.38))
        ctx.stroke(guard_, with: .color(c), lineWidth: lw)
        ctx.fill(Path(ellipseIn: CGRect(x: w*0.46, y: h*0.34, width: w*0.08, height: w*0.08)), with: .color(c.opacity(0.5)))
    }

    private func drawWolf(ctx: inout GraphicsContext, w: CGFloat, h: CGFloat, c: Color) {
        let lw: CGFloat = 1.6
        var body = Path()
        body.move(to: CGPoint(x: w*0.22, y: h*0.6))
        body.addCurve(to: CGPoint(x: w*0.5, y: h*0.08),
                      control1: CGPoint(x: w*0.18, y: h*0.28),
                      control2: CGPoint(x: w*0.5, y: h*0.08))
        body.addCurve(to: CGPoint(x: w*0.78, y: h*0.6),
                      control1: CGPoint(x: w*0.5, y: h*0.08),
                      control2: CGPoint(x: w*0.82, y: h*0.28))
        ctx.stroke(body, with: .color(c), lineWidth: lw)
        ctx.stroke(Path(ellipseIn: CGRect(x: w*0.35, y: h*0.21, width: w*0.3, height: w*0.3)), with: .color(c), lineWidth: lw)
        var e1 = Path(); e1.move(to: CGPoint(x: w*0.37, y: h*0.14)); e1.addLine(to: CGPoint(x: w*0.3, y: h*0.04))
        var e2 = Path(); e2.move(to: CGPoint(x: w*0.63, y: h*0.14)); e2.addLine(to: CGPoint(x: w*0.7, y: h*0.04))
        ctx.stroke(e1, with: .color(c), lineWidth: lw)
        ctx.stroke(e2, with: .color(c), lineWidth: lw)
    }

    private func drawBlade(ctx: inout GraphicsContext, w: CGFloat, h: CGFloat, c: Color) {
        let lw: CGFloat = 1.7
        var d1 = Path(); d1.move(to: CGPoint(x: w*0.28, y: h*0.08)); d1.addLine(to: CGPoint(x: w*0.72, y: h*0.72))
        ctx.stroke(d1, with: .color(c), lineWidth: lw)
        var d2 = Path(); d2.move(to: CGPoint(x: w*0.72, y: h*0.08)); d2.addLine(to: CGPoint(x: w*0.28, y: h*0.72))
        ctx.stroke(d2, with: .color(c.opacity(0.5)), style: StrokeStyle(lineWidth: lw, dash: [5, 3]))
        ctx.stroke(Path(ellipseIn: CGRect(x: w*0.4, y: h*0.3, width: w*0.2, height: w*0.2)), with: .color(c), lineWidth: lw)
        ctx.fill(Path(ellipseIn: CGRect(x: w*0.45, y: h*0.35, width: w*0.1, height: w*0.1)), with: .color(c.opacity(0.4)))
        var g1 = Path(); g1.move(to: CGPoint(x: w*0.15, y: h*0.4)); g1.addLine(to: CGPoint(x: w*0.38, y: h*0.4))
        var g2 = Path(); g2.move(to: CGPoint(x: w*0.85, y: h*0.4)); g2.addLine(to: CGPoint(x: w*0.62, y: h*0.4))
        ctx.stroke(g1, with: .color(c), lineWidth: lw)
        ctx.stroke(g2, with: .color(c), lineWidth: lw)
    }

    private func drawBubble(ctx: inout GraphicsContext, w: CGFloat, h: CGFloat, c: Color) {
        let lw: CGFloat = 1.6
        for (cx, cy, r) in [(w*0.3, h*0.28, w*0.12), (w*0.63, h*0.2, w*0.09),
                             (w*0.56, h*0.46, w*0.14), (w*0.28, h*0.52, w*0.07),
                             (w*0.72, h*0.43, w*0.08)] {
            ctx.stroke(Path(ellipseIn: CGRect(x: cx-r, y: cy-r, width: r*2, height: r*2)), with: .color(c), lineWidth: lw)
        }
    }

    private func drawBall(ctx: inout GraphicsContext, w: CGFloat, h: CGFloat, c: Color) {
        let lw: CGFloat = 1.6
        ctx.stroke(Path(ellipseIn: CGRect(x: w*0.28, y: h*0.14, width: w*0.44, height: w*0.44)), with: .color(c), lineWidth: lw)
        var seam1 = Path()
        seam1.move(to: CGPoint(x: w*0.28, y: h*0.18))
        seam1.addQuadCurve(to: CGPoint(x: w*0.72, y: h*0.18), control: CGPoint(x: w*0.5, y: h*0.36))
        ctx.stroke(seam1, with: .color(c), lineWidth: lw)
        var seam2 = Path()
        seam2.move(to: CGPoint(x: w*0.19, y: h*0.4))
        seam2.addQuadCurve(to: CGPoint(x: w*0.81, y: h*0.4), control: CGPoint(x: w*0.5, y: h*0.58))
        ctx.stroke(seam2, with: .color(c), lineWidth: lw)
        var vert = Path(); vert.move(to: CGPoint(x: w*0.5, y: h*0.14)); vert.addLine(to: CGPoint(x: w*0.5, y: h*0.58))
        ctx.stroke(vert, with: .color(c), lineWidth: lw)
    }
}

// MARK: - BoxArtView

struct BoxArtView: View {
    let game: Game
    var size: CGFloat = 146

    private var artHeight: CGFloat { size * 1.38 }

    var body: some View {
        let c1 = game.boxArtDarkColor
        let c2 = game.boxArtAccentColor

        ZStack {
            // Background gradient
            RoundedRectangle(cornerRadius: 6)
                .fill(LinearGradient(
                    stops: [
                        .init(color: c1, location: 0),
                        .init(color: c2.opacity(0.2), location: 0.75),
                        .init(color: c2.opacity(0.07), location: 1),
                    ],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))

            // Radial glow
            RadialGradient(
                stops: [.init(color: c2.opacity(0.28), location: 0), .init(color: .clear, location: 1)],
                center: UnitPoint(x: 0.5, y: 0.38),
                startRadius: 0, endRadius: size * 0.55
            )

            // Shape
            ShapeLayer(shape: game.boxArtShape, w: size, h: artHeight, color: c2)
                .opacity(0.26)

            // Scan lines
            Canvas { ctx, sz in
                var y: CGFloat = 0
                while y <= sz.height {
                    var line = Path()
                    line.move(to: CGPoint(x: 0, y: y))
                    line.addLine(to: CGPoint(x: sz.width, y: y))
                    ctx.stroke(line, with: .color(.black.opacity(0.09)), lineWidth: 1)
                    y += 5
                }
            }

            // Bottom fade
            LinearGradient(
                stops: [.init(color: .clear, location: 0.4), .init(color: .black.opacity(0.75), location: 1)],
                startPoint: .top, endPoint: .bottom
            )
        }
        .frame(width: size, height: artHeight)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

// MARK: - GameCardView

struct GameCardView: View {
    let game: Game
    let onTap: () -> Void

    @Environment(\.appTheme) private var t
    @State private var hovered = false

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                ZStack(alignment: .topLeading) {
                    BoxArtView(game: game, size: 146)
                    SystemBadge(system: game.system)
                        .padding(6)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(game.title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(t.text)
                        .lineLimit(1)
                    HStack {
                        Text(game.system.shortGenre)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(t.tagText)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(t.tag)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                            .textCase(.uppercase)
                        Spacer()
                        if let year = game.releaseYear {
                            Text(String(year))
                                .font(.system(size: 10))
                                .foregroundColor(t.textFaint)
                        }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.top, 7)
                .padding(.bottom, 9)
            }
        }
        .buttonStyle(.plain)
        .background(hovered ? t.cardHover : t.card)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10)
            .strokeBorder(hovered ? t.cardBorderHover : t.cardBorder, lineWidth: 1))
        .shadow(color: hovered ? .black.opacity(0.35) : .clear, radius: 16, y: 10)
        .offset(y: hovered ? -4 : 0)
        .animation(.easeInOut(duration: 0.18), value: hovered)
        .onHover { hovered = $0 }
    }
}

// MARK: - System badge

private struct SystemBadge: View {
    let system: EmulatorSystem

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(system.badgeColor)
                .frame(width: 7, height: 7)
            Text(system.shortName)
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(.white.opacity(0.8))
                .kerning(0.5)
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 3)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 5))
        .overlay(RoundedRectangle(cornerRadius: 5)
            .strokeBorder(.white.opacity(0.12), lineWidth: 0.5))
    }
}

// MARK: - EmulatorSystem display helpers

extension EmulatorSystem {
    var shortName: String {
        switch self {
        case .neoGeoAES:  return "NEO·AES"
        case .neoGeoMVS:  return "NEO·MVS"
        case .neoGeoCD:   return "NEO·CD"
        case .cps1:       return "CPS-1"
        case .cps2:       return "CPS-2"
        case .segaSys16:  return "SYS-16"
        case .segaSys18:  return "SYS-18"
        case .toaplan1:   return "TP-1"
        case .toaplan2:   return "TP-2"
        case .konamiGX:   return "KNM·GX"
        case .irem:       return "IREM"
        case .taito:      return "TAITO"
        }
    }

    var shortGenre: String {
        switch self {
        case .neoGeoAES, .neoGeoMVS: return "Neo Geo"
        case .neoGeoCD:               return "Neo Geo CD"
        case .cps1:                   return "CPS-1"
        case .cps2:                   return "CPS-2"
        case .segaSys16:              return "Sega Sys 16"
        case .segaSys18:              return "Sega Sys 18"
        case .toaplan1:               return "Toaplan 1"
        case .toaplan2:               return "Toaplan 2"
        case .konamiGX:               return "Konami GX"
        case .irem:                   return "Irem"
        case .taito:                  return "Taito"
        }
    }

    var badgeColor: Color {
        switch self {
        case .neoGeoAES, .neoGeoMVS, .neoGeoCD:
            return Color(red: 1,    green: 0.84, blue: 0.04)
        case .cps1:
            return Color(red: 0,    green: 0.62, blue: 0.88)
        case .cps2:
            return Color(red: 0,    green: 0.44, blue: 0.77)
        case .segaSys16, .segaSys18:
            return Color(red: 0.1,  green: 0.72, blue: 0.35)
        case .toaplan1, .toaplan2:
            return Color(red: 0.85, green: 0.25, blue: 0.20)
        case .konamiGX:
            return Color(red: 0.55, green: 0.18, blue: 0.80)
        case .irem:
            return Color(red: 0.90, green: 0.50, blue: 0.10)
        case .taito:
            return Color(red: 0.15, green: 0.55, blue: 0.75)
        }
    }

    var isNeoGeo: Bool { self == .neoGeoAES || self == .neoGeoMVS || self == .neoGeoCD }
}

extension Game {
    // Placeholder — real metadata would come from GameDB enrichment in a future phase
    var releaseYear: Int? { nil }
}

