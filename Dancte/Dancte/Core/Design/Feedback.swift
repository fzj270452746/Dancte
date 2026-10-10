import UIKit

// MARK: - Toast
//
// One text prompt for the entire app. Every confirmation, warning and error
// goes through here so feedback always looks and behaves the same.

enum Toast {

    enum Kind {
        case info, success, warning, error, love

        var symbol: String {
            switch self {
            case .info:    return "info.circle.fill"
            case .success: return "checkmark.circle.fill"
            case .warning: return "exclamationmark.triangle.fill"
            case .error:   return "xmark.octagon.fill"
            case .love:    return "heart.fill"
            }
        }

        var color: UIColor {
            switch self {
            case .info:    return Palette.cyan
            case .success: return Palette.lime
            case .warning: return Palette.amber
            case .error:   return Palette.magenta
            case .love:    return Palette.magenta
            }
        }
    }

    private static var current: UIView?
    private static var dismissWork: DispatchWorkItem?

    @discardableResult
    static func show(_ message: String, kind: Kind = .info, detail: String? = nil, duration: TimeInterval = 2.4) -> UIView? {
        guard let host = hostWindow() else { return nil }

        current?.removeFromSuperview()
        dismissWork?.cancel()

        let card = SurfaceCard(colors: [UIColor(hex: 0x22262F), UIColor(hex: 0x14161D)],
                               radius: 22,
                               border: kind.color.withAlphaComponent(0.35),
                               glow: kind.color)
        card.alpha = 0
        host.addSubview(card)

        let iconTile = UIView()
        iconTile.backgroundColor = kind.color.withAlphaComponent(0.16)
        iconTile.layer.cornerRadius = 16
        iconTile.layer.cornerCurve = .continuous
        iconTile.translatesAutoresizingMaskIntoConstraints = false

        let icon = UIImageView(image: UIImage(systemName: kind.symbol,
                                              withConfiguration: UIImage.SymbolConfiguration(pointSize: 17, weight: .bold)))
        icon.tintColor = kind.color
        icon.contentMode = .center
        iconTile.addSubviews(icon)

        let titleLabel = UILabel()
        titleLabel.text = message
        titleLabel.font = .dancte(15, .bold)
        titleLabel.textColor = Palette.text
        titleLabel.numberOfLines = 0

        let column = UIStackView(axis: .vertical, spacing: 2)
        column.addArrangedSubview(titleLabel)
        if let detail {
            let detailLabel = UILabel()
            detailLabel.text = detail
            detailLabel.font = Typo.caption
            detailLabel.textColor = Palette.textMuted
            detailLabel.numberOfLines = 0
            column.addArrangedSubview(detailLabel)
        }

        card.addSubviews(iconTile, column)

        let topInset = (host.safeAreaInsets.top > 0 ? host.safeAreaInsets.top : 20) + 10

        NSLayoutConstraint.activate([
            card.leadingAnchor.constraint(equalTo: host.leadingAnchor, constant: 16),
            card.trailingAnchor.constraint(equalTo: host.trailingAnchor, constant: -16),
            card.topAnchor.constraint(equalTo: host.topAnchor, constant: topInset),

            iconTile.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 12),
            iconTile.topAnchor.constraint(equalTo: card.topAnchor, constant: 12),
            iconTile.widthAnchor.constraint(equalToConstant: 34),
            iconTile.heightAnchor.constraint(equalToConstant: 34),
            icon.centerXAnchor.constraint(equalTo: iconTile.centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: iconTile.centerYAnchor),

            column.leadingAnchor.constraint(equalTo: iconTile.trailingAnchor, constant: 12),
            column.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            column.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            column.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -14)
        ])

        host.layoutIfNeeded()
        card.transform = CGAffineTransform(translationX: 0, y: -28).scaledBy(x: 0.96, y: 0.96)
        UIView.animate(withDuration: 0.38, delay: 0, usingSpringWithDamping: 0.78, initialSpringVelocity: 0.4) {
            card.alpha = 1
            card.transform = .identity
        }

        let work = DispatchWorkItem { [weak card] in
            guard let card else { return }
            UIView.animate(withDuration: 0.3, animations: {
                card.alpha = 0
                card.transform = CGAffineTransform(translationX: 0, y: -22)
            }, completion: { _ in card.removeFromSuperview() })
        }
        dismissWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: work)

        current = card
        return card
    }

    static func success(_ message: String, detail: String? = nil) { show(message, kind: .success, detail: detail) }
    static func error(_ message: String, detail: String? = nil) { show(message, kind: .error, detail: detail, duration: 3.0) }
    static func warning(_ message: String, detail: String? = nil) { show(message, kind: .warning, detail: detail) }

    private static func hostWindow() -> UIWindow? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let window = scenes.flatMap(\.windows).first { $0.isKeyWindow } ?? scenes.first?.windows.first
        return window
    }
}

// MARK: - Loading overlay

/// The studio loader. Every account action — signing in, registering, signing
/// out, deleting — plays this for a randomised beat of roughly a second so the
/// transition reads as work being done rather than a jump cut.
final class LoadingOverlay: UIView {

    private let ring = CAShapeLayer()
    private let track = CAShapeLayer()
    private let mark: BrandMarkView
    private let messageLabel = UILabel()
    private var didFinish = false

    private init(message: String?) {
        mark = BrandMarkView(size: 62)
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = Palette.ink.withAlphaComponent(0.9)

        let card = SurfaceCard(colors: [UIColor(hex: 0x1B1F29), UIColor(hex: 0x0E1015)],
                               radius: 32,
                               border: Palette.strokeHi.withAlphaComponent(0.5),
                               glow: Palette.lime)
        addSubview(card)

        let ringContainer = UIView()
        ringContainer.translatesAutoresizingMaskIntoConstraints = false
        ringContainer.backgroundColor = .clear

        // Each shape layer has to carry the container's bounds, or its anchor
        // point defaults to (0, 0) and the spin orbits that corner instead of
        // rotating the arc in place.
        let ringFrame = CGRect(x: 0, y: 0, width: 100, height: 100)

        track.frame = ringFrame
        track.path = UIBezierPath(ovalIn: ringFrame.insetBy(dx: 6, dy: 6)).cgPath
        track.fillColor = UIColor.clear.cgColor
        track.strokeColor = Palette.strokeHi.withAlphaComponent(0.45).cgColor
        track.lineWidth = 3
        ringContainer.layer.addSublayer(track)

        ring.frame = ringFrame
        ring.path = UIBezierPath(ovalIn: ringFrame.insetBy(dx: 6, dy: 6)).cgPath
        ring.fillColor = UIColor.clear.cgColor
        ring.strokeColor = Palette.lime.cgColor
        ring.lineWidth = 3
        ring.lineCap = .round
        ring.strokeStart = 0
        ring.strokeEnd = 0.28
        ringContainer.layer.addSublayer(ring)

        ringContainer.addSubviews(mark)

        messageLabel.text = message ?? "Loading"
        messageLabel.font = .dancte(14, .semibold)
        messageLabel.textColor = Palette.textMuted
        messageLabel.textAlignment = .center

        let column = UIStackView(axis: .vertical, spacing: 20, alignment: .center)
        column.addArrangedSubview(ringContainer)
        column.addArrangedSubview(messageLabel)

        card.addSubviews(column)

        NSLayoutConstraint.activate([
            card.centerXAnchor.constraint(equalTo: centerXAnchor),
            card.centerYAnchor.constraint(equalTo: centerYAnchor),
            card.widthAnchor.constraint(equalToConstant: 208),
            card.heightAnchor.constraint(equalToConstant: 208),

            ringContainer.widthAnchor.constraint(equalToConstant: 100),
            ringContainer.heightAnchor.constraint(equalToConstant: 100),
            mark.centerXAnchor.constraint(equalTo: ringContainer.centerXAnchor),
            mark.centerYAnchor.constraint(equalTo: ringContainer.centerYAnchor),

            column.centerXAnchor.constraint(equalTo: card.centerXAnchor),
            column.centerYAnchor.constraint(equalTo: card.centerYAnchor)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func setMessage(_ message: String) {
        messageLabel.text = message
    }

    private func startAnimating() {
        let spin = CABasicAnimation(keyPath: "transform.rotation.z")
        spin.toValue = CGFloat.pi * 2
        spin.duration = 1.1
        spin.repeatCount = .infinity
        spin.isRemovedOnCompletion = false
        ring.add(spin, forKey: "spin")

        let grow = CABasicAnimation(keyPath: "strokeEnd")
        grow.fromValue = 0.12
        grow.toValue = 0.82
        grow.duration = 0.9
        grow.autoreverses = true
        grow.repeatCount = .infinity
        grow.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        ring.add(grow, forKey: "grow")

        UIView.animate(withDuration: 0.9, delay: 0, options: [.repeat, .autoreverse, .curveEaseInOut]) {
            self.mark.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        }
    }

    // MARK: Presentation

    @discardableResult
    static func present(on host: UIView, message: String? = nil) -> LoadingOverlay {
        let overlay = LoadingOverlay(message: message)
        host.addSubview(overlay)
        overlay.pinEdges(to: host)
        overlay.alpha = 0
        UIView.animate(withDuration: 0.22) { overlay.alpha = 1 }
        overlay.startAnimating()
        return overlay
    }

    func dismiss(completion: (() -> Void)? = nil) {
        guard !didFinish else { return }
        didFinish = true
        UIView.animate(withDuration: 0.24, animations: {
            self.alpha = 0
            self.transform = CGAffineTransform(scaleX: 1.04, y: 1.04)
        }, completion: { _ in
            self.removeFromSuperview()
            completion?()
        })
    }

    /// Runs `work` after the loader has been on screen for a randomised beat.
    static func beat(on host: UIView,
                     message: String? = nil,
                     range: ClosedRange<Double> = 0.9...1.4,
                     then work: @escaping () -> Void) {
        let overlay = present(on: host, message: message)
        let delay = Double.random(in: range)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            overlay.dismiss(completion: work)
        }
    }
}

extension UIViewController {
    /// Convenience: covers the whole screen, including the custom tab bar.
    func runLoadingBeat(_ message: String? = nil, then work: @escaping () -> Void) {
        let host = navigationController?.view ?? view!
        if let existing = host.subviews.compactMap({ $0 as? LoadingOverlay }).first {
            existing.setMessage(message ?? "Loading")
            DispatchQueue.main.asyncAfter(deadline: .now() + Double.random(in: 0.9...1.4)) {
                existing.dismiss(completion: work)
            }
            return
        }
        LoadingOverlay.beat(on: host, message: message, then: work)
    }
}
