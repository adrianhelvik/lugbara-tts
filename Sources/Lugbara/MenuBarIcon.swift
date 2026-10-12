import AppKit

/// The menu bar icon and logo: two lines of text, the first ending in a dot, and a sound wave below.
enum MenuBarIcon {
    /// `phase` shifts the wave sideways, so it moves while Lugbara reads.
    /// `alert` turns the dot into an exclamation mark.
    static func image(phase: CGFloat = 0, alert: Bool = false) -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
            guard let c = NSGraphicsContext.current?.cgContext else { return false }
            c.setStrokeColor(.black)
            c.setFillColor(.black)
            c.setLineWidth(1.7)
            c.setLineCap(.round)

            c.move(to: CGPoint(x: 2.7, y: 13.2))
            c.addLine(to: CGPoint(x: 9.9, y: 13.2))
            c.move(to: CGPoint(x: 2.7, y: 9.3))
            c.addLine(to: CGPoint(x: 12, y: 9.3))
            c.strokePath()

            let steps = 60
            for i in 0...steps {
                let t = CGFloat(i) / CGFloat(steps)
                let point = CGPoint(x: 2.7 + 12.6 * t, y: 4.8 + 1.8 * sin(t * 3 * .pi + phase))
                i == 0 ? c.move(to: point) : c.addLine(to: point)
            }
            c.strokePath()

            if alert {
                c.move(to: CGPoint(x: 14.6, y: 15.6))
                c.addLine(to: CGPoint(x: 14.6, y: 12.0))
                c.strokePath()
                c.fillEllipse(in: CGRect(x: 13.65, y: 8.6, width: 1.9, height: 1.9))
            } else {
                c.fillEllipse(in: CGRect(x: 12.05, y: 11.6, width: 3.2, height: 3.2))
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
