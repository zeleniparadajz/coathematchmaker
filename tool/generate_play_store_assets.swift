import AppKit
import Foundation

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let logoURL = root.appendingPathComponent("assets/images/coa.png")
let out = root.appendingPathComponent("play_store")
let graphics = out.appendingPathComponent("graphics")
let shots = out.appendingPathComponent("screenshots")

try FileManager.default.createDirectory(at: graphics, withIntermediateDirectories: true)
try FileManager.default.createDirectory(at: shots, withIntermediateDirectories: true)

let court = NSColor(calibratedRed: 0.27, green: 0.85, blue: 0.54, alpha: 1)
let courtDark = NSColor(calibratedRed: 0.05, green: 0.29, blue: 0.15, alpha: 1)
let lime = NSColor(calibratedRed: 0.87, green: 0.99, blue: 0.83, alpha: 1)
let clay = NSColor(calibratedRed: 0.90, green: 0.42, blue: 0.23, alpha: 1)
let ink = NSColor(calibratedRed: 0.07, green: 0.21, blue: 0.12, alpha: 1)
let mist = NSColor(calibratedRed: 0.98, green: 0.97, blue: 0.94, alpha: 1)
let white = NSColor.white

func image(_ width: CGFloat, _ height: CGFloat, draw: @escaping () -> Void) -> NSImage {
    return NSImage(size: NSSize(width: width, height: height), flipped: true) { _ in
        draw()
        return true
    }
}

func save(_ image: NSImage, _ path: URL) {
    guard
        let tiff = image.tiffRepresentation,
        let bitmap = NSBitmapImageRep(data: tiff),
        let png = bitmap.representation(using: .png, properties: [:])
    else { fatalError("Could not encode \(path.path)") }
    try! png.write(to: path)
}

func rect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ color: NSColor, radius: CGFloat = 0) {
    color.setFill()
    let r = NSRect(x: x, y: y, width: w, height: h)
    if radius > 0 {
        NSBezierPath(roundedRect: r, xRadius: radius, yRadius: radius).fill()
    } else {
        r.fill()
    }
}

func oval(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ color: NSColor) {
    color.setFill()
    NSBezierPath(ovalIn: NSRect(x: x, y: y, width: w, height: h)).fill()
}

func line(_ text: String, _ x: CGFloat, _ y: CGFloat, _ size: CGFloat, _ color: NSColor = ink, weight: NSFont.Weight = .bold, width: CGFloat = 900) {
    let style = NSMutableParagraphStyle()
    style.lineBreakMode = .byWordWrapping
    let attrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: size, weight: weight),
        .foregroundColor: color,
        .paragraphStyle: style
    ]
    NSString(string: text).draw(in: NSRect(x: x, y: y, width: width, height: size * 3.2), withAttributes: attrs)
}

func pill(_ text: String, _ x: CGFloat, _ y: CGFloat, _ bg: NSColor = lime, _ fg: NSColor = courtDark, icon: String? = nil) {
    let label = icon == nil ? text : "\(icon!)  \(text)"
    let width = max(86, CGFloat(label.count) * 12 + 38)
    rect(x, y, width, 34, bg, radius: 17)
    line(label, x + 18, y + 7, 15, fg, weight: .heavy, width: width - 28)
}

func drawLogo(_ x: CGFloat, _ y: CGFloat, _ size: CGFloat) {
    if let logo = NSImage(contentsOf: logoURL) {
        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(ovalIn: NSRect(x: x, y: y, width: size, height: size)).addClip()
        logo.draw(in: NSRect(x: x, y: y, width: size, height: size))
        NSGraphicsContext.restoreGraphicsState()
    } else {
        oval(x, y, size, size, lime)
        line("COA", x + size * 0.18, y + size * 0.38, size * 0.18, courtDark, weight: .heavy, width: size)
    }
}

func drawHeader(_ title: String, width: CGFloat, tablet: Bool = false) {
    drawLogo(54, 52, tablet ? 64 : 54)
    line("COA - \(title)", 128, tablet ? 61 : 58, tablet ? 42 : 42, courtDark, weight: .heavy, width: width - 260)
    drawLogo(width - 116, 44, tablet ? 72 : 66)
}

func drawBottomNav(_ width: CGFloat, _ height: CGFloat) {
    rect(42, height - 190, width - 84, 136, lime, radius: 54)
    let items = [("▦", "Home"), ("♣", "Igrači"), ("♜", "Turniri"), ("⌕", "Mečevi"), ("▮", "Ranking"), ("□", "Poruke")]
    let step = (width - 120) / CGFloat(items.count)
    for (i, item) in items.enumerated() {
        let x = 70 + CGFloat(i) * step
        if i == 0 { rect(x - 18, height - 174, 88, 42, court.withAlphaComponent(0.30), radius: 21) }
        line(item.0, x + 8, height - 169, 31, courtDark, weight: .heavy, width: 60)
        line(item.1, x - 4, height - 116, 16, courtDark, weight: .heavy, width: 90)
    }
}

func drawHeroCard(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) {
    rect(x, y, w, h, court, radius: 48)
    rect(x, y, w, h, courtDark.withAlphaComponent(0.48), radius: 48)
    drawLogo(x + 42, y + 42, 126)
    line("Milos Nikcevic", x + 194, y + 54, 42, white, weight: .heavy, width: w - 240)
    pill("220 pts  |  18W 6L", x + 194, y + 108, white.withAlphaComponent(0.18), white)
    rect(x + 42, y + h - 150, (w - 112) / 2, 92, white.withAlphaComponent(0.14), radius: 26)
    rect(x + 70 + (w - 112) / 2, y + h - 150, (w - 112) / 2, 92, white.withAlphaComponent(0.14), radius: 26)
    line("24", x + 118, y + h - 132, 30, white, weight: .heavy, width: 90)
    line("Mečevi", x + 118, y + h - 96, 20, white.withAlphaComponent(0.75), weight: .bold, width: 140)
    line("3", x + 146 + (w - 112) / 2, y + h - 132, 30, white, weight: .heavy, width: 90)
    line("Titule", x + 146 + (w - 112) / 2, y + h - 96, 20, white.withAlphaComponent(0.75), weight: .bold, width: 140)
    rect(x + 42, y + h - 250, w - 84, 66, white.withAlphaComponent(0.14), radius: 24)
    line("⚡  2 aktivna izazova čekaju potvrdu", x + 72, y + h - 232, 22, white, weight: .heavy, width: w - 120)
}

func drawStat(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ value: String, _ label: String, _ color: NSColor) {
    rect(x, y, w, h, white, radius: 34)
    rect(x + 32, y + 30, 72, 72, color.withAlphaComponent(0.14), radius: 20)
    line(value, x + 32, y + h - 88, 44, ink, weight: .heavy, width: w - 64)
    line(label, x + 32, y + h - 40, 22, ink.withAlphaComponent(0.52), weight: .heavy, width: w - 64)
}

func drawPlayerCard(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ name: String, _ clayMode: Bool = false) {
    rect(x, y, w, h, clayMode ? clay : courtDark, radius: 44)
    rect(x, y, w, h, (clayMode ? courtDark : court).withAlphaComponent(0.56), radius: 44)
    oval(x + w - 290, y - 120, 420, 420, white.withAlphaComponent(0.08))
    pill("Montenegro", x + 34, y + 34, white.withAlphaComponent(0.9), courtDark, icon: "⌖")
    pill("Aktivan", x + w - 156, y + 34, lime, courtDark, icon: "⚡")
    drawLogo(x + 46, y + h - 190, 86)
    line(name, x + 46, y + h - 122, 48, white, weight: .heavy, width: w - 92)
    line("Montenegro  |  Tenis", x + 46, y + h - 72, 24, white.withAlphaComponent(0.86), weight: .bold, width: w - 92)
    pill("1 susret", x + 46, y + h - 36, white.withAlphaComponent(0.9), courtDark, icon: "⌕")
    pill("180 pts", x + 182, y + h - 36, white.withAlphaComponent(0.9), courtDark, icon: "▮")
}

func drawMatchCard(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ player1: String, _ player2: String, _ status: String, _ score: String, confirmed: Bool = false) {
    rect(x, y, w, 330, white, radius: 36)
    line(player1, x + 78, y + 42, 32, ink, weight: .heavy, width: w - 280)
    line("vs", x + 78, y + 82, 28, ink, weight: .heavy, width: w - 280)
    line(player2, x + 78, y + 120, 32, ink, weight: .heavy, width: w - 280)
    pill(status, x + w - 252, y + 50, (confirmed ? court : clay).withAlphaComponent(0.15), confirmed ? courtDark : clay)
    rect(x + 32, y + 184, w - 64, 72, court.withAlphaComponent(0.10), radius: 22)
    line("▣  \(score)   🏆 \(player1)", x + 58, y + 203, 26, ink, weight: .heavy, width: w - 110)
    line(confirmed ? "Meč potvrđen i sačuvan" : "Rezultat čeka potvrdu druge strane", x + 38, y + 278, 23, ink.withAlphaComponent(0.55), weight: .bold, width: w - 76)
}

func drawRankingPoster(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ name: String, _ rank: String, _ points: String, _ color: NSColor) {
    rect(x, y, w, 205, color.withAlphaComponent(0.84), radius: 32)
    oval(x + w - 220, y - 78, 330, 330, white.withAlphaComponent(0.12))
    drawLogo(x + 36, y + 48, 94)
    line(name, x + 154, y + 50, 31, white, weight: .heavy, width: w - 300)
    line("\(points)  |  18W", x + 154, y + 91, 22, white.withAlphaComponent(0.86), weight: .bold, width: w - 300)
    line(rank, x + w - 112, y + 54, 54, white, weight: .heavy, width: 90)
    line("Ranking", x + w - 122, y + 119, 16, white.withAlphaComponent(0.86), weight: .bold, width: 100)
}

func drawTournament(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ title: String, _ status: String) {
    rect(x, y, w, 180, white, radius: 34)
    rect(x + 32, y + 44, 82, 82, lime, radius: 24)
    line("🏆", x + 52, y + 62, 34, courtDark, weight: .heavy, width: 50)
    line(title, x + 142, y + 44, 31, ink, weight: .heavy, width: w - 330)
    line("Budva  |  Hard  |  Round-robin", x + 142, y + 86, 23, ink.withAlphaComponent(0.55), weight: .bold, width: w - 330)
    pill(status, x + w - 152, y + 62)
}

func drawPhoneDashboard() {
    let w: CGFloat = 1080, h: CGFloat = 1920
    save(image(w, h) {
        rect(0, 0, w, h, mist)
        drawHeader("Dashboard", width: w)
        line("Tvoja liga, mečevi i ranking na jednom mjestu.", 54, 150, 32, ink.withAlphaComponent(0.56), weight: .bold, width: 890)
        drawHeroCard(54, 250, w - 108, 480)
        line("Liga danas", 54, 800, 42, ink, weight: .heavy, width: 600)
        drawStat(54, 870, 466, 250, "128", "Igrača", court)
        drawStat(560, 870, 466, 250, "7", "Aktivni turniri", clay)
        drawStat(54, 1160, 466, 250, "24", "Moji mečevi", court)
        drawStat(560, 1160, 466, 250, "3", "Titule", clay)
        line("Top 5 ranking", 54, 1470, 42, ink, weight: .heavy, width: 600)
        drawRankingPoster(54, 1540, w - 108, "Milos Nikcevic", "1", "220 pts", NSColor(calibratedRed: 0.33, green: 0.66, blue: 1, alpha: 1))
        drawBottomNav(w, h)
    }, shots.appendingPathComponent("phone_01_dashboard.png"))
}

func drawPhonePlayers() {
    let w: CGFloat = 1080, h: CGFloat = 1920
    save(image(w, h) {
        rect(0, 0, w, h, mist)
        drawHeader("Igrači", width: w)
        line("Pronađi partnera, pogledaj profil i dogovori meč.", 54, 150, 32, ink.withAlphaComponent(0.56), weight: .bold, width: 880)
        rect(54, 242, w - 108, 86, white, radius: 43)
        line("⌕  Pronađi igrača", 92, 264, 28, ink.withAlphaComponent(0.55), weight: .bold, width: 600)
        drawPlayerCard(54, 380, w - 108, 540, "Roy")
        drawPlayerCard(54, 970, w - 108, 540, "Patricio", true)
        drawBottomNav(w, h)
    }, shots.appendingPathComponent("phone_02_players.png"))
}

func drawPhoneMatches() {
    let w: CGFloat = 1080, h: CGFloat = 1920
    save(image(w, h) {
        rect(0, 0, w, h, mist)
        drawHeader("Mečevi", width: w)
        line("Challenge, rezultat i potvrda obje strane.", 54, 150, 32, ink.withAlphaComponent(0.56), weight: .bold, width: 880)
        drawMatchCard(54, 250, w - 108, "Milos Nikcevic", "Coa Boričić", "waiting confirmation", "6-4, 4-6, 6-3")
        drawMatchCard(54, 620, w - 108, "Milica Markovic", "Ljubo Tala", "confirmed", "7-5, 6-4", confirmed: true)
        rect(54, 1030, w - 108, 360, lime.withAlphaComponent(0.72), radius: 34)
        line("Lokacija meča", 92, 1076, 26, ink.withAlphaComponent(0.55), weight: .bold, width: 600)
        line("Budva, Montenegro", 92, 1130, 38, ink, weight: .heavy, width: 700)
        line("📍", w - 230, 1110, 82, clay, weight: .heavy, width: 120)
        pill("Open in Google Maps", 92, 1300, white.withAlphaComponent(0.8), courtDark)
        drawBottomNav(w, h)
    }, shots.appendingPathComponent("phone_03_match.png"))
}

func drawPhoneRanking() {
    let w: CGFloat = 1080, h: CGFloat = 1920
    save(image(w, h) {
        rect(0, 0, w, h, mist)
        drawHeader("Ranking", width: w)
        line("Jasna rang lista po poenima i pobjedama.", 54, 150, 32, ink.withAlphaComponent(0.56), weight: .bold, width: 880)
        drawRankingPoster(54, 250, w - 108, "Milos Nikcevic", "1", "220 pts", NSColor(calibratedRed: 0.33, green: 0.66, blue: 1, alpha: 1))
        drawRankingPoster(54, 500, w - 108, "Coa Boričić", "2", "196 pts", NSColor(calibratedRed: 1.0, green: 0.59, blue: 0.27, alpha: 1))
        drawRankingPoster(54, 750, w - 108, "Milica Markovic", "3", "174 pts", NSColor(calibratedRed: 0.93, green: 0.29, blue: 0.52, alpha: 1))
        drawRankingPoster(54, 1000, w - 108, "Ljubo Tala", "4", "120 pts", NSColor(calibratedRed: 0.56, green: 0.32, blue: 0.96, alpha: 1))
        drawBottomNav(w, h)
    }, shots.appendingPathComponent("phone_04_ranking.png"))
}

func drawTabletDashboard() {
    let w: CGFloat = 1600, h: CGFloat = 2560
    save(image(w, h) {
        rect(0, 0, w, h, mist)
        drawHeader("Dashboard", width: w, tablet: true)
        line("Pregled lige za igrače i administratore.", 92, 170, 34, ink.withAlphaComponent(0.56), weight: .bold, width: 1200)
        drawHeroCard(92, 280, 660, 430)
        drawMatchCard(92, 770, 660, "Milos Nikcevic", "Coa Boričić", "confirmed", "6-4, 6-3", confirmed: true)
        line("Top ranking", 820, 280, 44, ink, weight: .heavy, width: 500)
        drawRankingPoster(820, 360, 688, "Milos Nikcevic", "1", "220 pts", NSColor(calibratedRed: 0.33, green: 0.66, blue: 1, alpha: 1))
        drawRankingPoster(820, 610, 688, "Coa Boričić", "2", "196 pts", NSColor(calibratedRed: 1.0, green: 0.59, blue: 0.27, alpha: 1))
        drawRankingPoster(820, 860, 688, "Milica Markovic", "3", "174 pts", NSColor(calibratedRed: 0.93, green: 0.29, blue: 0.52, alpha: 1))
    }, shots.appendingPathComponent("tablet_01_dashboard.png"))
}

func drawTabletTournaments() {
    let w: CGFloat = 1600, h: CGFloat = 2560
    save(image(w, h) {
        rect(0, 0, w, h, mist)
        drawHeader("Turniri", width: w, tablet: true)
        line("Žrijebovi, učesnici, galerije i rezultati.", 92, 170, 34, ink.withAlphaComponent(0.56), weight: .bold, width: 1200)
        drawTournament(92, 280, 680, "Budva masters", "active")
        drawTournament(92, 500, 680, "Montenegro Open", "upcoming")
        rect(92, 760, 680, 360, lime.withAlphaComponent(0.72), radius: 34)
        line("Lokacija turnira", 130, 806, 26, ink.withAlphaComponent(0.55), weight: .bold, width: 600)
        line("Budva, Montenegro", 130, 860, 38, ink, weight: .heavy, width: 520)
        line("📍", 620, 845, 82, clay, weight: .heavy, width: 120)
        drawPlayerCard(840, 280, 668, 540, "Roy")
        drawMatchCard(840, 880, 668, "Milica Markovic", "Ljubo Tala", "waiting", "7-6, 4-6, 6-2")
    }, shots.appendingPathComponent("tablet_02_tournaments.png"))
}

func drawFeature() {
    save(image(1024, 500) {
        rect(0, 0, 1024, 500, mist)
        rect(0, 0, 1024, 500, NSColor(calibratedRed: 0.95, green: 1.0, blue: 0.90, alpha: 1))
        oval(700, -230, 560, 560, court.withAlphaComponent(0.20))
        oval(-180, 250, 390, 390, clay.withAlphaComponent(0.12))
        oval(395, 355, 230, 230, lime.withAlphaComponent(0.70))

        drawLogo(64, 52, 78)
        line("COA", 162, 64, 46, courtDark, weight: .heavy, width: 150)
        line("The Matchmaker", 162, 111, 24, courtDark.withAlphaComponent(0.76), weight: .heavy, width: 280)
        line("Find players.\nCreate matches.\nRun tournaments.", 64, 176, 45, ink, weight: .heavy, width: 430)
        line("Tennis community app for local leagues, clubs and players.", 68, 365, 21, ink.withAlphaComponent(0.62), weight: .bold, width: 420)
        pill("Challenges", 68, 423, white.withAlphaComponent(0.92), courtDark, icon: "⌕")
        pill("Ranking", 214, 423, white.withAlphaComponent(0.92), courtDark, icon: "▮")
        pill("Tournaments", 338, 423, white.withAlphaComponent(0.92), courtDark, icon: "🏆")

        let px: CGFloat = 600
        let py: CGFloat = 28
        let pw: CGFloat = 305
        let ph: CGFloat = 560
        rect(px - 12, py - 12, pw + 24, ph + 24, NSColor.black, radius: 58)
        rect(px, py, pw, ph, mist, radius: 46)
        rect(px + 100, py + 15, 105, 30, NSColor.black, radius: 15)

        let sx = px + 26
        let sy = py + 62
        let sw = pw - 52
        drawLogo(sx, sy, 22)
        line("COA - Dashboard", sx + 36, sy + 1, 17, courtDark, weight: .heavy, width: 190)
        drawLogo(sx + sw - 32, sy - 4, 30)

        rect(sx, sy + 48, sw, 150, court, radius: 24)
        rect(sx, sy + 48, sw, 150, courtDark.withAlphaComponent(0.38), radius: 24)
        drawLogo(sx + 18, sy + 69, 54)
        line("Marko Markovic", sx + 88, sy + 72, 19, white, weight: .heavy, width: 150)
        pill("0 pts | 0W 0L", sx + 88, sy + 102, white.withAlphaComponent(0.20), white)
        rect(sx + 16, sy + 134, 94, 42, white.withAlphaComponent(0.14), radius: 16)
        rect(sx + 126, sy + 134, 94, 42, white.withAlphaComponent(0.14), radius: 16)
        line("0", sx + 48, sy + 139, 14, white, weight: .heavy, width: 40)
        line("Mečevi", sx + 38, sy + 157, 11, white.withAlphaComponent(0.82), weight: .bold, width: 65)
        line("0", sx + 158, sy + 139, 14, white, weight: .heavy, width: 40)
        line("Titule", sx + 150, sy + 157, 11, white.withAlphaComponent(0.82), weight: .bold, width: 65)

        line("Liga danas", sx, sy + 220, 23, ink, weight: .heavy, width: 180)
        drawMiniStat(sx, sy + 252, 118, 88, "1", "Igrača", court)
        drawMiniStat(sx + 134, sy + 252, 118, 88, "0", "Turniri", clay)
        drawMiniStat(sx, sy + 354, 118, 88, "0", "Mečevi", court)
        drawMiniStat(sx + 134, sy + 354, 118, 88, "0", "Titule", clay)

        rect(sx, py + ph - 78, sw, 48, lime, radius: 24)
        line("Home     Igrači     Turniri     Mečevi", sx + 22, py + ph - 62, 11, courtDark, weight: .heavy, width: sw - 40)
    }, graphics.appendingPathComponent("feature_graphic.png"))
}

func drawMiniStat(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ value: String, _ label: String, _ color: NSColor) {
    rect(x, y, w, h, white, radius: 18)
    rect(x + 12, y + 12, 28, 28, color.withAlphaComponent(0.14), radius: 9)
    line(value, x + 14, y + h - 41, 24, ink, weight: .heavy, width: w - 28)
    line(label, x + 14, y + h - 17, 12, ink.withAlphaComponent(0.55), weight: .heavy, width: w - 28)
}

func drawPhoneShell(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) {
    rect(x - 18, y - 18, w + 36, h + 36, NSColor.black, radius: 80)
    rect(x, y, w, h, mist, radius: 62)
    rect(x + w * 0.34, y + 18, w * 0.32, 44, NSColor.black, radius: 22)
}

func drawMiniAppHeader(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ title: String) {
    drawLogo(x + 28, y + 32, 34)
    line("COA - \(title)", x + 76, y + 34, 24, courtDark, weight: .heavy, width: w - 150)
    drawLogo(x + w - 72, y + 24, 44)
}

func drawMarketingPhone(_ filename: String, title: String, subtitle: String, accent: NSColor = court, content: @escaping (_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> Void) {
    let w: CGFloat = 1080, h: CGFloat = 1920
    save(image(w, h) {
        rect(0, 0, w, h, mist)
        oval(720, -120, 480, 480, accent.withAlphaComponent(0.18))
        oval(-170, 1320, 450, 450, clay.withAlphaComponent(0.12))
        line(title, 72, 86, 58, courtDark, weight: .heavy, width: 900)
        line(subtitle, 72, 230, 30, ink.withAlphaComponent(0.60), weight: .bold, width: 820)
        let px: CGFloat = 180
        let py: CGFloat = 390
        let pw: CGFloat = 720
        let ph: CGFloat = 1370
        drawPhoneShell(px, py, pw, ph)
        content(px + 40, py + 82, pw - 80, ph - 140)
    }, shots.appendingPathComponent(filename))
}

func drawStoreDashboard() {
    drawMarketingPhone(
        "phone_01_dashboard.png",
        title: "Sve za tvoju tenis ligu",
        subtitle: "Profil, statistika, mečevi i ranking na jednom mjestu."
    ) { x, y, w, h in
        drawMiniAppHeader(x, y, w, "Dashboard")
        rect(x + 20, y + 106, w - 40, 250, court, radius: 34)
        rect(x + 20, y + 106, w - 40, 250, courtDark.withAlphaComponent(0.42), radius: 34)
        drawLogo(x + 48, y + 136, 88)
        line("Milos Nikcevic", x + 154, y + 144, 31, white, weight: .heavy, width: w - 210)
        pill("220 pts  |  18W 6L", x + 154, y + 190, white.withAlphaComponent(0.20), white)
        rect(x + 48, y + 270, 190, 54, white.withAlphaComponent(0.15), radius: 20)
        rect(x + 260, y + 270, 190, 54, white.withAlphaComponent(0.15), radius: 20)
        line("24 Mečevi", x + 72, y + 286, 18, white, weight: .heavy, width: 150)
        line("3 Titule", x + 286, y + 286, 18, white, weight: .heavy, width: 150)
        line("Liga danas", x + 20, y + 390, 30, ink, weight: .heavy, width: 300)
        drawStat(x + 20, y + 444, 280, 156, "128", "Igrača", court)
        drawStat(x + 320, y + 444, 280, 156, "7", "Turniri", clay)
        drawStat(x + 20, y + 624, 280, 156, "24", "Moji mečevi", court)
        drawStat(x + 320, y + 624, 280, 156, "3", "Titule", clay)
        line("Top ranking", x + 20, y + 820, 30, ink, weight: .heavy, width: 320)
        drawRankingPoster(x + 20, y + 872, w - 40, "Milos Nikcevic", "1", "220 pts", NSColor(calibratedRed: 0.33, green: 0.66, blue: 1, alpha: 1))
        rect(x + 24, y + h - 88, w - 48, 70, lime, radius: 30)
        line("Home      Igrači      Turniri      Mečevi      Ranking", x + 58, y + h - 64, 15, courtDark, weight: .heavy, width: w - 100)
    }
}

func drawStorePlayers() {
    drawMarketingPhone(
        "phone_02_players.png",
        title: "Pronađi partnera za meč",
        subtitle: "Pregledaj igrače, status i formu prije nego pošalješ challenge.",
        accent: court
    ) { x, y, w, h in
        drawMiniAppHeader(x, y, w, "Igrači")
        rect(x + 20, y + 110, w - 40, 58, white, radius: 29)
        line("⌕  Pronađi igrača", x + 46, y + 127, 19, ink.withAlphaComponent(0.55), weight: .bold, width: 300)
        drawPlayerCard(x + 20, y + 208, w - 40, 360, "Roy")
        drawPlayerCard(x + 20, y + 604, w - 40, 360, "Patricio", true)
        rect(x + 24, y + h - 88, w - 48, 70, lime, radius: 30)
        line("Home      Igrači      Turniri      Mečevi      Ranking", x + 58, y + h - 64, 15, courtDark, weight: .heavy, width: w - 100)
    }
}

func drawStoreMatches() {
    drawMarketingPhone(
        "phone_03_match.png",
        title: "Challenge bez varanja",
        subtitle: "Rezultat se čuva tek kad ga potvrde obje strane.",
        accent: clay
    ) { x, y, w, h in
        drawMiniAppHeader(x, y, w, "Mečevi")
        drawMatchCard(x + 20, y + 122, w - 40, "Milos Nikcevic", "Coa Boričić", "waiting", "6-4, 4-6, 6-3")
        drawMatchCard(x + 20, y + 482, w - 40, "Milica Markovic", "Ljubo Tala", "confirmed", "7-5, 6-4", confirmed: true)
        rect(x + 20, y + 862, w - 40, 150, lime.withAlphaComponent(0.76), radius: 28)
        line("Lokacija meča", x + 50, y + 896, 18, ink.withAlphaComponent(0.55), weight: .bold, width: 300)
        line("Budva, Montenegro", x + 50, y + 932, 27, ink, weight: .heavy, width: 390)
        line("📍", x + w - 126, y + 910, 52, clay, weight: .heavy, width: 80)
        rect(x + 24, y + h - 88, w - 48, 70, lime, radius: 30)
        line("Home      Igrači      Turniri      Mečevi      Ranking", x + 58, y + h - 64, 15, courtDark, weight: .heavy, width: w - 100)
    }
}

func drawStoreRanking() {
    drawMarketingPhone(
        "phone_04_ranking.png",
        title: "Ranking koji ima smisla",
        subtitle: "Poeni, pobjede i potvrđeni mečevi jasno su prikazani.",
        accent: NSColor(calibratedRed: 0.33, green: 0.66, blue: 1, alpha: 1)
    ) { x, y, w, h in
        drawMiniAppHeader(x, y, w, "Ranking")
        drawRankingPoster(x + 20, y + 128, w - 40, "Milos Nikcevic", "1", "220 pts", NSColor(calibratedRed: 0.33, green: 0.66, blue: 1, alpha: 1))
        drawRankingPoster(x + 20, y + 364, w - 40, "Coa Boričić", "2", "196 pts", NSColor(calibratedRed: 1.0, green: 0.59, blue: 0.27, alpha: 1))
        drawRankingPoster(x + 20, y + 600, w - 40, "Milica Markovic", "3", "174 pts", NSColor(calibratedRed: 0.93, green: 0.29, blue: 0.52, alpha: 1))
        drawRankingPoster(x + 20, y + 836, w - 40, "Ljubo Tala", "4", "120 pts", NSColor(calibratedRed: 0.56, green: 0.32, blue: 0.96, alpha: 1))
        rect(x + 24, y + h - 88, w - 48, 70, lime, radius: 30)
        line("Home      Igrači      Turniri      Mečevi      Ranking", x + 58, y + h - 64, 15, courtDark, weight: .heavy, width: w - 100)
    }
}

func drawTabletMarketing() {
    let w: CGFloat = 1600, h: CGFloat = 2560
    save(image(w, h) {
        rect(0, 0, w, h, mist)
        oval(1120, -160, 620, 620, court.withAlphaComponent(0.16))
        line("COA za klubove i lokalne lige", 120, 120, 72, courtDark, weight: .heavy, width: 1180)
        line("Admin turniri, igrači, mečevi, potvrde rezultata i ranking u čistom tablet prikazu.", 120, 300, 38, ink.withAlphaComponent(0.60), weight: .bold, width: 1200)
        rect(120, 520, 1360, 1560, NSColor.black, radius: 72)
        rect(150, 550, 1300, 1500, mist, radius: 52)
        drawMiniAppHeader(210, 620, 1180, "Dashboard")
        drawHeroCard(210, 760, 560, 360)
        drawMatchCard(210, 1170, 560, "Milos Nikcevic", "Coa Boričić", "confirmed", "6-4, 6-3", confirmed: true)
        line("Top ranking", 840, 760, 44, ink, weight: .heavy, width: 460)
        drawRankingPoster(840, 840, 500, "Milos Nikcevic", "1", "220 pts", NSColor(calibratedRed: 0.33, green: 0.66, blue: 1, alpha: 1))
        drawRankingPoster(840, 1090, 500, "Coa Boričić", "2", "196 pts", NSColor(calibratedRed: 1.0, green: 0.59, blue: 0.27, alpha: 1))
        drawTournament(840, 1390, 500, "Budva masters", "active")
    }, shots.appendingPathComponent("tablet_01_dashboard.png"))

    save(image(w, h) {
        rect(0, 0, w, h, mist)
        oval(-180, 1800, 620, 620, clay.withAlphaComponent(0.13))
        line("Turniri spremni za sezonu", 120, 120, 72, courtDark, weight: .heavy, width: 1180)
        line("Žrijebovi, učesnici, galerije i lokacije za svaki turnir.", 120, 300, 38, ink.withAlphaComponent(0.60), weight: .bold, width: 1200)
        rect(120, 520, 1360, 1560, NSColor.black, radius: 72)
        rect(150, 550, 1300, 1500, mist, radius: 52)
        drawMiniAppHeader(210, 620, 1180, "Turniri")
        drawTournament(210, 760, 560, "Budva masters", "active")
        drawTournament(210, 990, 560, "Montenegro Open", "upcoming")
        rect(210, 1260, 560, 260, lime.withAlphaComponent(0.72), radius: 34)
        line("Lokacija turnira", 250, 1302, 24, ink.withAlphaComponent(0.55), weight: .bold, width: 360)
        line("Budva, Montenegro", 250, 1355, 36, ink, weight: .heavy, width: 420)
        line("📍", 640, 1324, 66, clay, weight: .heavy, width: 90)
        drawPlayerCard(840, 760, 500, 420, "Roy")
        drawMatchCard(840, 1240, 500, "Milica Markovic", "Ljubo Tala", "waiting", "7-6, 4-6, 6-2")
    }, shots.appendingPathComponent("tablet_02_tournaments.png"))
}

drawFeature()
drawPhoneDashboard()
drawPhonePlayers()
drawPhoneMatches()
drawPhoneRanking()
drawTabletDashboard()
drawTabletTournaments()
drawStoreDashboard()
drawStorePlayers()
drawStoreMatches()
drawStoreRanking()
drawTabletMarketing()

print("Generated Play Store assets in \(out.path)")
