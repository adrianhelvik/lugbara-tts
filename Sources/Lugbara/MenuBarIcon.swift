import AppKit

/// The menu bar icon: two lines of text, and a third line that is a sound wave.
enum MenuBarIcon {
    /// `phase` shifts the wave sideways, so it moves while Lugbara reads.
    /// `alert` shortens the top line and puts a dot at its end.
    static func image(phase: CGFloat = 0, alert: Bool = false) -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
            guard let c = NSGraphicsContext.current?.cgContext else { return false }
            c.setStrokeColor(.black)
            c.setFillColor(.black)
            c.setLineWidth(1.7)
            c.setLineCap(.round)

            c.move(to: CGPoint(x: 2.5, y: 14))
            c.addLine(to: CGPoint(x: alert ? 10.5 : 15.5, y: 14))
            c.move(to: CGPoint(x: 2.5, y: 9.5))
            c.addLine(to: CGPoint(x: 11, y: 9.5))
            c.strokePath()

            let steps = 60
            for i in 0...steps {
                let t = CGFloat(i) / CGFloat(steps)
                let point = CGPoint(x: 2.5 + 13 * t, y: 4.2 + 2.2 * sin(t * 3 * .pi + phase))
                i == 0 ? c.move(to: point) : c.addLine(to: point)
            }
            c.strokePath()

            if alert {
                c.fillEllipse(in: CGRect(x: 13, y: 11.8, width: 4.4, height: 4.4))
            }
            return true
        }
        image.isTemplate = true
        return image
    }
}

/// Moves the wave in the menu bar icon while Lugbara reads.
@MainActor
final class IconAnimation: ObservableObject {
    @Published private(set) var phase: CGFloat = 0
    private var timer: Timer?

    func setRunning(_ running: Bool) {
        timer?.invalidate()
        timer = nil
        guard running else { phase = 0; return }
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 12, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.phase -= 0.5 }
        }
    }
}
