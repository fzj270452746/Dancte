import UIKit

// MARK: - Brand mark

/// Dancte's logo, drawn wherever the brand appears: a rounded gradient tile
/// holding an abstract figure mid-move — a crescent torso, a head and a planted
/// leg. The delivered `logo` asset is used when it is installed; the same mark
/// is drawn in code underneath it, so the brand still shows — crisp at any size
/// — if that file has not shipped.
final class BrandMarkView: UIView {

    /// Resolved once for the whole app: every mark on screen is the same file.
    /// A brand asset is read straight from the catalog rather than through
    /// `Assets`, which looks for the dancer's own media first.
    private static let deliveredLogo = UIImage(named: "logo")

    var colors: [UIColor] = Grad.lime { didSet { setNeedsDisplay() } }
    var glyphColor: UIColor = Palette.ink { didSet { setNeedsDisplay() } }

    init(size: CGFloat, colors: [UIColor] = Grad.lime) {
        self.colors = colors
        super.init(frame: CGRect(x: 0, y: 0, width: size, height: size))
        backgroundColor = .clear
        isOpaque = false
        translatesAutoresizingMaskIntoConstraints = false
        widthAnchor.constraint(equalToConstant: size).isActive = true
        heightAnchor.constraint(equalToConstant: size).isActive = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        let side = min(rect.width, rect.height)
        let tile = CGRect(x: (rect.width - side) / 2, y: (rect.height - side) / 2, width: side, height: side)
        let radius = side * 0.32

        // The delivered logo brings its own gradient, figure and rounded
        // corners, so it fills the tile as-is.
        if let logo = BrandMarkView.deliveredLogo {
            logo.draw(in: tile)
            return
        }

        ctx.saveGState()
        let path = UIBezierPath(roundedRect: tile, cornerRadius: radius)
        ctx.addPath(path.cgPath)
        ctx.clip()
        if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                     colors: colors.map(\.cgColor) as CFArray,
                                     locations: [0, 1]) {
            ctx.drawLinearGradient(gradient,
                                   start: CGPoint(x: tile.minX, y: tile.minY),
                                   end: CGPoint(x: tile.maxX, y: tile.maxY),
                                   options: [])
        }
        ctx.restoreGState()

        // Figure: crescent torso, head, planted leg.
        let unit = side
        ctx.setStrokeColor(glyphColor.cgColor)
        ctx.setFillColor(glyphColor.cgColor)
        ctx.setLineCap(.round)
        ctx.setLineWidth(unit * 0.115)

        let torso = UIBezierPath()
        torso.addArc(withCenter: CGPoint(x: tile.midX - unit * 0.02, y: tile.midY + unit * 0.06),
                     radius: unit * 0.20,
                     startAngle: .pi * 0.86,
                     endAngle: .pi * 1.92,
                     clockwise: true)
        ctx.addPath(torso.cgPath)
        ctx.strokePath()

        let headRadius = unit * 0.085
        ctx.fillEllipse(in: CGRect(x: tile.midX + unit * 0.10 - headRadius,
                                   y: tile.midY - unit * 0.27 - headRadius,
                                   width: headRadius * 2, height: headRadius * 2))

        ctx.move(to: CGPoint(x: tile.midX - unit * 0.14, y: tile.midY + unit * 0.26))
        ctx.addLine(to: CGPoint(x: tile.midX - unit * 0.26, y: tile.midY + unit * 0.38))
        ctx.strokePath()
    }
}

// MARK: - Surface

final class SurfaceCard: UIView {

    private let gradient = CAGradientLayer()
    private var glowColor: UIColor?

    init(colors: [UIColor] = Grad.card,
         radius: CGFloat = Metric.cardRadius,
         border: UIColor? = Palette.stroke,
         glow: UIColor? = nil) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = .clear

        gradient.colors = colors.map(\.cgColor)
        gradient.startPoint = CGPoint(x: 0, y: 0)
        gradient.endPoint = CGPoint(x: 1, y: 1)
        gradient.cornerRadius = radius
        gradient.cornerCurve = .continuous
        layer.insertSublayer(gradient, at: 0)

        layer.cornerRadius = radius
        layer.cornerCurve = .continuous
        if let border {
            layer.borderWidth = 1
            layer.borderColor = border.cgColor
        }
        if let glow {
            glowColor = glow
            layer.shadowColor = glow.cgColor
            layer.shadowOpacity = 0.28
            layer.shadowRadius = 24
            layer.shadowOffset = CGSize(width: 0, height: 12)
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        gradient.frame = bounds
        CATransaction.commit()
    }

    func setColors(_ colors: [UIColor]) {
        gradient.colors = colors.map(\.cgColor)
    }

    func setBorderColor(_ color: UIColor?) {
        layer.borderColor = color?.cgColor
        layer.borderWidth = color == nil ? 0 : 1
    }
}

/// A hairline that reads as a seam rather than a divider.
final class SeamView: UIView {
    init(color: UIColor = Palette.stroke) {
        super.init(frame: .zero)
        backgroundColor = color
        translatesAutoresizingMaskIntoConstraints = false
        heightAnchor.constraint(equalToConstant: 1).isActive = true
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

// MARK: - Buttons

enum PillStyle {
    case primary
    case inverted
    case outline
    case ghost
    case danger
    case custom(colors: [UIColor], foreground: UIColor)
}

final class PillButton: UIControl {

    var onTap: (() -> Void)?

    private let titleLabel = UILabel()
    private let iconView = UIImageView()
    private let gradient = CAGradientLayer()
    private let stack = UIStackView(axis: .horizontal, spacing: 8, alignment: .center, distribution: .fill)
    private let height: CGFloat
    private var style: PillStyle

    var title: String {
        get { titleLabel.text ?? "" }
        set { titleLabel.text = newValue; accessibilityLabel = newValue }
    }

    init(_ title: String, symbol: String? = nil, style: PillStyle = .primary, height: CGFloat = 54) {
        self.style = style
        self.height = height
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        gradient.startPoint = CGPoint(x: 0, y: 0)
        gradient.endPoint = CGPoint(x: 1, y: 1)
        gradient.cornerRadius = height / 2
        gradient.cornerCurve = .continuous
        layer.insertSublayer(gradient, at: 0)
        layer.cornerRadius = height / 2
        layer.cornerCurve = .continuous

        titleLabel.text = title
        titleLabel.font = .dancte(height >= 50 ? 17 : 15, .bold)
        titleLabel.textAlignment = .center
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.minimumScaleFactor = 0.8

        iconView.contentMode = .scaleAspectFit
        iconView.setContentHuggingPriority(.required, for: .horizontal)
        iconView.isHidden = symbol == nil
        if let symbol {
            iconView.image = UIImage(systemName: symbol,
                                     withConfiguration: UIImage.SymbolConfiguration(pointSize: height * 0.36, weight: .bold))
        }

        stack.addArrangedSubview(iconView)
        stack.addArrangedSubview(titleLabel)
        stack.isUserInteractionEnabled = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -20),
            heightAnchor.constraint(equalToConstant: height)
        ])

        accessibilityTraits = .button
        accessibilityLabel = title
        applyStyle()
        addTarget(self, action: #selector(handleTap), for: .touchUpInside)
        addTarget(self, action: #selector(handleDown), for: [.touchDown, .touchDragEnter])
        addTarget(self, action: #selector(handleUp), for: [.touchUpOutside, .touchDragExit, .touchCancel])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        gradient.frame = bounds
        gradient.cornerRadius = bounds.height / 2
        CATransaction.commit()
    }

    func setStyle(_ style: PillStyle) {
        self.style = style
        applyStyle()
    }

    func setSymbol(_ name: String?) {
        guard let name else { iconView.isHidden = true; return }
        iconView.isHidden = false
        iconView.image = UIImage(systemName: name,
                                 withConfiguration: UIImage.SymbolConfiguration(pointSize: height * 0.36, weight: .bold))
    }

    private func applyStyle() {
        switch style {
        case .primary:
            gradient.colors = Grad.lime.map(\.cgColor)
            titleLabel.textColor = Palette.ink
            iconView.tintColor = Palette.ink
            layer.borderWidth = 0
            layer.shadowColor = Palette.lime.cgColor
            layer.shadowOpacity = 0.32
            layer.shadowRadius = 18
            layer.shadowOffset = CGSize(width: 0, height: 10)
        case .inverted:
            gradient.colors = [Palette.text, UIColor(hex: 0xD8DEE9)].map(\.cgColor)
            titleLabel.textColor = Palette.ink
            iconView.tintColor = Palette.ink
            layer.borderWidth = 0
            layer.shadowOpacity = 0
        case .outline:
            gradient.colors = [UIColor.clear.cgColor, UIColor.clear.cgColor]
            titleLabel.textColor = Palette.text
            iconView.tintColor = Palette.text
            layer.borderWidth = 1.4
            layer.borderColor = Palette.strokeHi.cgColor
            layer.shadowOpacity = 0
        case .ghost:
            gradient.colors = [Palette.surfaceHi.cgColor, Palette.surface.cgColor]
            titleLabel.textColor = Palette.text
            iconView.tintColor = Palette.text
            layer.borderWidth = 0
            layer.shadowOpacity = 0
        case .danger:
            gradient.colors = Grad.magenta.map(\.cgColor)
            titleLabel.textColor = .white
            iconView.tintColor = .white
            layer.borderWidth = 0
            layer.shadowOpacity = 0
        case let .custom(colors, foreground):
            gradient.colors = colors.map(\.cgColor)
            titleLabel.textColor = foreground
            iconView.tintColor = foreground
            layer.borderWidth = 0
            layer.shadowOpacity = 0
        }
    }

    override var isEnabled: Bool {
        didSet {
            UIView.animate(withDuration: 0.2) {
                self.alpha = self.isEnabled ? 1 : 0.4
            }
        }
    }

    override var isHighlighted: Bool {
        didSet {
            UIView.animate(withDuration: 0.12) {
                self.transform = self.isHighlighted ? CGAffineTransform(scaleX: 0.97, y: 0.97) : .identity
            }
        }
    }

    @objc private func handleTap() {
        Haptics.tap()
        onTap?()
    }

    @objc private func handleDown() { isHighlighted = true }
    @objc private func handleUp() { isHighlighted = false }
}

final class IconButton: UIControl {

    enum Background {
        case glass
        case solid(UIColor)
        case outline
        case gradient([UIColor])
        case clear
    }

    var onTap: (() -> Void)?

    private let iconView = UIImageView()
    private let gradient = CAGradientLayer()
    private let size: CGFloat
    private var background: Background
    private var tint: UIColor
    private let pointSize: CGFloat

    var isActive: Bool = false {
        didSet { refreshTint() }
    }

    init(symbol: String,
         size: CGFloat = 44,
         background: Background = .glass,
         tint: UIColor = Palette.text,
         pointSize: CGFloat = 17) {
        self.size = size
        self.background = background
        self.tint = tint
        self.pointSize = pointSize
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        gradient.startPoint = CGPoint(x: 0, y: 0)
        gradient.endPoint = CGPoint(x: 1, y: 1)
        gradient.cornerRadius = size / 2
        layer.insertSublayer(gradient, at: 0)
        layer.cornerRadius = size / 2
        layer.cornerCurve = .continuous

        iconView.contentMode = .center
        iconView.isUserInteractionEnabled = false
        iconView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(iconView)
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: size),
            heightAnchor.constraint(equalToConstant: size),
            iconView.centerXAnchor.constraint(equalTo: centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])

        setSymbol(symbol)
        applyBackground()
        accessibilityTraits = .button
        addTarget(self, action: #selector(handleTap), for: .touchUpInside)
        addTarget(self, action: #selector(handleDown), for: [.touchDown, .touchDragEnter])
        addTarget(self, action: #selector(handleUp), for: [.touchUpOutside, .touchDragExit, .touchCancel])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func setSymbol(_ name: String, weight: UIImage.SymbolWeight = .semibold) {
        iconView.image = UIImage(systemName: name,
                                 withConfiguration: UIImage.SymbolConfiguration(pointSize: pointSize, weight: weight))
        accessibilityLabel = name
    }

    func setBackground(_ background: Background) {
        self.background = background
        applyBackground()
    }

    func setTint(_ color: UIColor) {
        tint = color
        refreshTint()
    }

    private func refreshTint() {
        iconView.tintColor = isActive ? Palette.ink : tint
    }

    private func applyBackground() {
        switch background {
        case .glass:
            gradient.colors = [UIColor(hex: 0x2A2F3D).withAlphaComponent(0.9).cgColor,
                               UIColor(hex: 0x161A23).withAlphaComponent(0.9).cgColor]
            layer.borderWidth = 1
            layer.borderColor = Palette.strokeHi.withAlphaComponent(0.6).cgColor
            refreshTint()
        case let .solid(color):
            gradient.colors = [color.cgColor, color.cgColor]
            layer.borderWidth = 0
            refreshTint()
        case .outline:
            gradient.colors = [UIColor.clear.cgColor, UIColor.clear.cgColor]
            layer.borderWidth = 1.4
            layer.borderColor = Palette.strokeHi.cgColor
            refreshTint()
        case let .gradient(colors):
            gradient.colors = colors.map(\.cgColor)
            layer.borderWidth = 0
            iconView.tintColor = Palette.ink
        case .clear:
            gradient.colors = [UIColor.clear.cgColor, UIColor.clear.cgColor]
            layer.borderWidth = 0
            refreshTint()
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        gradient.frame = bounds
        gradient.cornerRadius = bounds.height / 2
        CATransaction.commit()
    }

    override var isHighlighted: Bool {
        didSet {
            UIView.animate(withDuration: 0.12) {
                self.transform = self.isHighlighted ? CGAffineTransform(scaleX: 0.92, y: 0.92) : .identity
            }
        }
    }

    @objc private func handleTap() { Haptics.tap(); onTap?() }
    @objc private func handleDown() { isHighlighted = true }
    @objc private func handleUp() { isHighlighted = false }
}

// MARK: - Whole-row control

/// The base class for a control that paints a whole row or card — an avatar, a
/// tile, a stack of labels — and wants every point inside itself to belong to
/// it.
///
/// A `UIControl` only starts tracking a touch that lands on the control itself.
/// Leave an inner view interactive and a tap on it is delivered there instead:
/// the touch still reaches the control's `touchesBegan` up the responder chain,
/// but `beginTracking` never runs, so there is no highlight, no `touchUpInside`
/// and no action. On a row whose avatar, labels and tile cover everything but a
/// few points of bare background, that reads as "I have to tap it several times
/// before anything happens" — the taps that work are the ones that happen to
/// find the background.
///
/// Subclasses therefore claim every point, with one exception: a control nested
/// inside the row — a real button — keeps its own touches, which is what a
/// button is for. Decoration that needs no touches should still be marked
/// `isUserInteractionEnabled = false` where that is clearer than relying on
/// this rule.
class RowControl: UIControl {

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard !isHidden, alpha > 0.01, isUserInteractionEnabled,
              super.point(inside: point, with: event) else { return nil }
        for subview in subviews.reversed() {
            let hit = subview.hitTest(convert(point, to: subview), with: event)
            if let hit, ownsItsTouches(hit) { return hit }
        }
        return self
    }

    /// True when a hit inside this control belongs to something nested below it
    /// that handles its own touches, rather than to the row itself.
    private func ownsItsTouches(_ hit: UIView) -> Bool {
        var node: UIView? = hit
        while let view = node, view !== self {
            if view is UIControl || view is UITextView || view is UITextField { return true }
            node = view.superview
        }
        return false
    }
}

/// A plain control that runs a closure. Handy for making an arbitrary view
/// tappable without exposing gesture plumbing at the call site. It claims every
/// point inside itself, so a card laid over it cannot swallow the tap.
final class ClosureControl: RowControl {

    var onTap: (() -> Void)?

    init(onTap: (() -> Void)? = nil) {
        self.onTap = onTap
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        addAction(UIAction { [weak self] _ in
            Haptics.tap()
            self?.onTap?()
        }, for: .touchUpInside)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var isHighlighted: Bool {
        didSet {
            UIView.animate(withDuration: 0.12) {
                self.alpha = self.isHighlighted ? 0.7 : 1
            }
        }
    }
}

// MARK: - Chips

final class ChipView: UIControl {

    var onTap: (() -> Void)?

    private let label = UILabel()
    private let iconView = UIImageView()
    private let stack = UIStackView(axis: .horizontal, spacing: 6, alignment: .center)
    private let accent: UIColor
    private let horizontalPadding: CGFloat

    var isOn: Bool = false {
        didSet { refresh() }
    }

    init(text: String, symbol: String? = nil, accent: UIColor = Palette.lime,
         horizontalPadding: CGFloat = 15, fontSize: CGFloat = 13.5) {
        self.accent = accent
        self.horizontalPadding = horizontalPadding
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        layer.cornerRadius = 18
        layer.cornerCurve = .continuous
        layer.borderWidth = 1

        label.text = text
        label.font = .dancte(fontSize, .semibold)
        label.isUserInteractionEnabled = false
        accessibilityLabel = text
        accessibilityTraits = .button

        if let symbol {
            iconView.image = UIImage(systemName: symbol,
                                     withConfiguration: UIImage.SymbolConfiguration(pointSize: fontSize - 1, weight: .bold))
            iconView.isUserInteractionEnabled = false
            iconView.setContentHuggingPriority(.required, for: .horizontal)
            stack.addArrangedSubview(iconView)
        }
        stack.addArrangedSubview(label)
        stack.isUserInteractionEnabled = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: horizontalPadding),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -horizontalPadding),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 9),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -9)
        ])

        refresh()
        addTarget(self, action: #selector(handleTap), for: .touchUpInside)
        addTarget(self, action: #selector(handleDown), for: [.touchDown, .touchDragEnter])
        addTarget(self, action: #selector(handleUp), for: [.touchUpOutside, .touchDragExit, .touchCancel])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func setText(_ text: String) {
        label.text = text
        accessibilityLabel = text
        invalidateIntrinsicContentSize()
    }

    /// A chip is exactly as wide as its label plus the padding, so it hugs its
    /// content instead of stretching when it sits in a stack view.
    override var intrinsicContentSize: CGSize {
        let content = stack.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
        return CGSize(width: content.width + horizontalPadding * 2,
                      height: content.height + 18)
    }

    private func refresh() {
        if isOn {
            backgroundColor = accent
            layer.borderColor = accent.cgColor
            label.textColor = Palette.ink
            iconView.tintColor = Palette.ink
        } else {
            backgroundColor = Palette.surfaceHi.withAlphaComponent(0.7)
            layer.borderColor = Palette.stroke.cgColor
            label.textColor = Palette.textMuted
            iconView.tintColor = Palette.textMuted
        }
    }

    override var isHighlighted: Bool {
        didSet {
            UIView.animate(withDuration: 0.12) {
                self.transform = self.isHighlighted ? CGAffineTransform(scaleX: 0.95, y: 0.95) : .identity
            }
        }
    }

    @objc private func handleTap() { Haptics.selection(); onTap?() }
    @objc private func handleDown() { isHighlighted = true }
    @objc private func handleUp() { isHighlighted = false }
}

// MARK: - Avatar

final class AvatarView: UIView {

    private let imageView = UIImageView()
    private let initialsLabel = UILabel()
    private let ringLayer = CAShapeLayer()
    private var size: CGFloat

    init(size: CGFloat = 52, ring: UIColor? = nil) {
        self.size = size
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = Palette.surfaceHi
        layer.cornerRadius = size / 2
        layer.cornerCurve = .continuous
        clipsToBounds = true

        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(imageView)

        initialsLabel.font = .dancte(size * 0.36, .heavy)
        initialsLabel.textColor = Palette.ink
        initialsLabel.textAlignment = .center
        initialsLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(initialsLabel)

        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: size),
            heightAnchor.constraint(equalToConstant: size),
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor),
            imageView.topAnchor.constraint(equalTo: topAnchor),
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor),
            initialsLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            initialsLabel.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])

        if let ring { applyRing(ring) }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(displayName: String, assetName: String, seed: String, ring: UIColor? = nil) {
        if let image = Assets.image(assetName) {
            imageView.image = image
            initialsLabel.isHidden = true
        } else {
            // No portrait in the pack: initials, not an invented face.
            imageView.image = nil
            initialsLabel.text = Initials.of(displayName)
            initialsLabel.textColor = Palette.text
            initialsLabel.isHidden = initialsLabel.text?.isEmpty ?? true
        }
        accessibilityLabel = displayName
        if let ring { applyRing(ring) }
    }

    func configure(user: User?, ring: UIColor? = nil) {
        let name = user?.displayName ?? "Dancte Dancer"
        configure(displayName: name, assetName: user?.avatarName ?? "", seed: user?.id ?? name, ring: ring)
    }

    private func applyRing(_ color: UIColor) {
        layer.borderWidth = 2
        layer.borderColor = color.cgColor
    }
}

/// Avatar with a live status ring and an optional online dot.
final class RingedAvatarView: UIView {

    let avatar: AvatarView
    private let ringLayer = CAGradientLayer()
    private let ringMask = CAShapeLayer()
    private let dot = UIView()

    init(size: CGFloat = 60, showsDot: Bool = false) {
        avatar = AvatarView(size: size - 8)
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        ringLayer.startPoint = CGPoint(x: 0, y: 0)
        ringLayer.endPoint = CGPoint(x: 1, y: 1)
        ringLayer.colors = Grad.lime.map(\.cgColor)
        ringLayer.cornerRadius = size / 2
        layer.addSublayer(ringLayer)

        addSubview(avatar)

        dot.backgroundColor = Palette.lime
        dot.layer.cornerRadius = 6
        dot.layer.borderWidth = 2.5
        dot.layer.borderColor = Palette.ink.cgColor
        dot.isHidden = !showsDot
        dot.translatesAutoresizingMaskIntoConstraints = false
        addSubview(dot)

        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: size),
            heightAnchor.constraint(equalToConstant: size),
            avatar.centerXAnchor.constraint(equalTo: centerXAnchor),
            avatar.centerYAnchor.constraint(equalTo: centerYAnchor),
            dot.widthAnchor.constraint(equalToConstant: 12),
            dot.heightAnchor.constraint(equalToConstant: 12),
            dot.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -1),
            dot.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -2)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        ringLayer.frame = bounds
        ringLayer.cornerRadius = bounds.height / 2
        CATransaction.commit()
    }

    func setRingColors(_ colors: [UIColor]) {
        ringLayer.colors = colors.map(\.cgColor)
    }

    func configure(user: User?) {
        avatar.configure(user: user)
    }

    func configure(displayName: String, assetName: String, seed: String, ring: UIColor? = nil) {
        avatar.configure(displayName: displayName, assetName: assetName, seed: seed, ring: ring)
    }
}

// MARK: - Section header

final class SectionHeader: UIView {

    private let actionButton = UIButton(type: .system)
    var onAction: (() -> Void)?

    init(eyebrow: String?, title: String, actionTitle: String? = nil, accent: UIColor = Palette.lime) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = Typo.title
        titleLabel.textColor = Palette.text
        titleLabel.numberOfLines = 2

        let column = UIStackView(axis: .vertical, spacing: 2)
        if let eyebrow {
            column.addArrangedSubview(UILabel.eyebrow(eyebrow))
        }
        column.addArrangedSubview(titleLabel)

        let row = UIStackView(axis: .horizontal, spacing: 12, alignment: .bottom)
        row.addArrangedSubview(column)
        row.addArrangedSubview(UIView())

        if let actionTitle {
            actionButton.setAttributedTitle(NSAttributedString(
                string: actionTitle,
                attributes: [.font: UIFont.dancte(14, .bold), .foregroundColor: accent]
            ), for: .normal)
            actionButton.addTarget(self, action: #selector(handleAction), for: .touchUpInside)
            row.addArrangedSubview(actionButton)
        }

        addSubview(row)
        row.pinEdges(to: self)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    @objc private func handleAction() { Haptics.tap(); onAction?() }
}

// MARK: - Empty state

final class EmptyStateView: UIView {

    var onAction: (() -> Void)?

    init(symbol: String,
         title: String,
         message: String,
         actionTitle: String? = nil,
         accent: UIColor = Palette.lime,
         compact: Bool = false) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        let tile = SurfaceCard(colors: [accent.withAlphaComponent(0.16), accent.withAlphaComponent(0.04)],
                               radius: compact ? 26 : 34,
                               border: accent.withAlphaComponent(0.28))
        let icon = UIImageView(image: UIImage(systemName: symbol,
                                              withConfiguration: UIImage.SymbolConfiguration(pointSize: compact ? 26 : 34, weight: .bold)))
        icon.tintColor = accent
        icon.contentMode = .center
        tile.addSubviews(icon)

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .dancte(compact ? 18 : 22, .bold)
        titleLabel.textColor = Palette.text
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 2

        let messageLabel = UILabel()
        messageLabel.text = message
        messageLabel.font = Typo.body
        messageLabel.textColor = Palette.textMuted
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 0

        let column = UIStackView(axis: .vertical, spacing: compact ? 14 : 18, alignment: .center)
        column.addArrangedSubview(tile)
        column.addArrangedSubview(titleLabel)
        column.addArrangedSubview(messageLabel)

        if let actionTitle {
            let button = PillButton(actionTitle, style: .primary, height: 50)
            button.onTap = { [weak self] in self?.onAction?() }
            column.addArrangedSubview(button)
            button.widthAnchor.constraint(equalToConstant: 220).isActive = true
            column.setCustomSpacing(22, after: messageLabel)
        }

        addSubview(column)
        NSLayoutConstraint.activate([
            tile.widthAnchor.constraint(equalToConstant: compact ? 64 : 84),
            tile.heightAnchor.constraint(equalToConstant: compact ? 64 : 84),
            icon.centerXAnchor.constraint(equalTo: tile.centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: tile.centerYAnchor),
            column.centerXAnchor.constraint(equalTo: centerXAnchor),
            column.centerYAnchor.constraint(equalTo: centerYAnchor),
            column.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 32),
            column.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -32)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// Convenience for dropping an empty state into a scroll view.
    static func install(in container: UIView, above anchor: NSLayoutYAxisAnchor? = nil, height: CGFloat = 380) {
        let placeholder = UIView()
        placeholder.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(placeholder)
        NSLayoutConstraint.activate([
            placeholder.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            placeholder.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            placeholder.heightAnchor.constraint(equalToConstant: height)
        ])
        if let anchor {
            placeholder.topAnchor.constraint(equalTo: anchor).isActive = true
        }
    }
}

// MARK: - Segmented pills

final class SegmentedPills: UIView {

    var onSelect: ((Int) -> Void)?

    private let scroll = UIScrollView()
    private let stack = UIStackView(axis: .horizontal, spacing: 8)
    private var chips: [ChipView] = []
    private let accent: UIColor

    var selectedIndex: Int = 0 {
        didSet { refresh() }
    }

    init(items: [String], accent: UIColor = Palette.lime, isOn: Bool = true) {
        self.accent = accent
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        scroll.showsHorizontalScrollIndicator = false
        scroll.contentInset = UIEdgeInsets(top: 0, left: Metric.gutter, bottom: 0, right: Metric.gutter)
        scroll.translatesAutoresizingMaskIntoConstraints = false
        addSubview(scroll)
        scroll.pinEdges(to: self)

        stack.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
            stack.heightAnchor.constraint(equalTo: scroll.frameLayoutGuide.heightAnchor)
        ])

        for (index, item) in items.enumerated() {
            let chip = ChipView(text: item, accent: accent)
            chip.isOn = index == 0
            chip.onTap = { [weak self] in
                guard let self else { return }
                self.selectedIndex = index
                self.onSelect?(index)
            }
            chips.append(chip)
            stack.addArrangedSubview(chip)
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func refresh() {
        for (index, chip) in chips.enumerated() { chip.isOn = index == selectedIndex }
        guard chips.indices.contains(selectedIndex) else { return }
        scroll.scrollRectToVisible(chips[selectedIndex].frame.insetBy(dx: -Metric.gutter, dy: 0), animated: true)
    }
}

// MARK: - Stat tile

final class StatTile: UIView {

    private let valueLabel = UILabel()
    private let captionLabel = UILabel()

    init(value: String, caption: String, accent: UIColor = Palette.lime, symbol: String? = nil, compact: Bool = false) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        let card = SurfaceCard(colors: [Palette.surfaceHi, Palette.surface],
                               radius: compact ? 20 : 24,
                               border: Palette.stroke.withAlphaComponent(0.7))
        addSubview(card)
        card.pinEdges(to: self)

        valueLabel.text = value
        valueLabel.font = .dancte(compact ? 22 : 28, .black)
        valueLabel.textColor = accent
        valueLabel.adjustsFontSizeToFitWidth = true
        valueLabel.minimumScaleFactor = 0.6

        captionLabel.text = caption.uppercased()
        captionLabel.attributedText = NSAttributedString(
            string: caption.uppercased(),
            attributes: [.kern: 1.1, .font: UIFont.dancte(compact ? 9 : 10, .bold), .foregroundColor: Palette.textFaint]
        )
        captionLabel.numberOfLines = 2

        let column = UIStackView(axis: .vertical, spacing: 4)
        if let symbol {
            let icon = UIImageView(image: UIImage(systemName: symbol,
                                                  withConfiguration: UIImage.SymbolConfiguration(pointSize: compact ? 14 : 16, weight: .bold)))
            icon.tintColor = accent
            icon.contentMode = .left
            column.addArrangedSubview(icon)
            column.setCustomSpacing(8, after: icon)
        }
        column.addArrangedSubview(valueLabel)
        column.addArrangedSubview(captionLabel)

        card.addSubviews(column)
        NSLayoutConstraint.activate([
            column.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: compact ? 14 : 18),
            column.trailingAnchor.constraint(lessThanOrEqualTo: card.trailingAnchor, constant: -12),
            column.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            column.topAnchor.constraint(greaterThanOrEqualTo: card.topAnchor, constant: 14),
            card.heightAnchor.constraint(greaterThanOrEqualToConstant: compact ? 78 : 96)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func update(value: String) {
        valueLabel.text = value
        valueLabel.pulse(1.08, duration: 0.12)
    }
}

// MARK: - Count badge

final class CountBadge: UIView {
    private let label = UILabel()

    init(count: Int, color: UIColor = Palette.blaze) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = color
        layer.cornerRadius = 9
        layer.cornerCurve = .continuous

        label.text = count > 99 ? "99+" : "\(count)"
        label.font = .dancte(11, .heavy)
        label.textColor = Palette.ink
        label.textAlignment = .center
        addSubview(label)
        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 18),
            widthAnchor.constraint(greaterThanOrEqualToConstant: 18),
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 5),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -5),
            label.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func setCount(_ count: Int) {
        label.text = count > 99 ? "99+" : "\(count)"
    }
}

// MARK: - Live pill

/// The small "REC"-style marker used to flag live or in-progress states.
final class LivePill: UIView {

    init(text: String = "Live", color: UIColor = Palette.blaze) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = color
        layer.cornerRadius = 9

        let dot = UIView()
        dot.backgroundColor = Palette.ink
        dot.layer.cornerRadius = 3
        dot.translatesAutoresizingMaskIntoConstraints = false

        let label = UILabel()
        label.text = text.uppercased()
        label.font = .dancte(10, .heavy)
        label.textColor = Palette.ink
        label.translatesAutoresizingMaskIntoConstraints = false

        addSubview(dot)
        addSubview(label)
        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 18),
            dot.widthAnchor.constraint(equalToConstant: 6),
            dot.heightAnchor.constraint(equalToConstant: 6),
            dot.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 7),
            dot.centerYAnchor.constraint(equalTo: centerYAnchor),
            label.leadingAnchor.constraint(equalTo: dot.trailingAnchor, constant: 5),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            label.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

// MARK: - Back button

extension UIViewController {
    func installBrandBackButton() {
        let button = UIBarButtonItem(image: UIImage(systemName: "arrow.left"),
                                     style: .plain, target: self, action: #selector(dancte_pop))
        button.tintColor = Palette.text
        navigationItem.leftBarButtonItem = button
    }

    @objc private func dancte_pop() {
        // Screens shown as a sheet (the terms/privacy/EULA reader off the auth
        // screen) sit at the root of their own navigation stack, so there is
        // nothing to pop and the arrow used to look dead. Fall back to dismissing
        // the sheet, which is what "back" means on a modal stack.
        guard let stack = navigationController else {
            (presentingViewController ?? self).dismiss(animated: true)
            return
        }
        if stack.viewControllers.count > 1 {
            stack.popViewController(animated: true)
        } else if let presenter = stack.presentingViewController ?? presentingViewController {
            presenter.dismiss(animated: true)
        }
    }

    /// Standard transparent navigation bar used by every pushed screen.
    func styleNavigationBar(title: String? = nil, subtitle: String? = nil) {
        guard let navigationBar = navigationController?.navigationBar else { return }
        navigationBar.tintColor = Palette.text
        navigationBar.shadowImage = UIImage()
        navigationBar.setBackgroundImage(UIImage(), for: .default)
        navigationBar.titleTextAttributes = [.foregroundColor: Palette.text, .font: UIFont.dancte(17, .bold)]
        navigationBar.isTranslucent = true
        navigationItem.title = title

        guard let subtitle else { return }
        let container = UIStackView(axis: .vertical, spacing: 0, alignment: .center)
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .dancte(17, .bold)
        titleLabel.textColor = Palette.text
        titleLabel.textAlignment = .center
        let subtitleLabel = UILabel()
        subtitleLabel.attributedText = NSAttributedString(
            string: subtitle.uppercased(),
            attributes: [.kern: 1.2, .font: UIFont.dancte(9.5, .bold), .foregroundColor: Palette.textFaint]
        )
        subtitleLabel.textAlignment = .center
        container.addArrangedSubview(titleLabel)
        container.addArrangedSubview(subtitleLabel)
        navigationItem.titleView = container
    }
}

// MARK: - Layout helpers

/// A vertical stack that behaves as a scroll view's content, with the standard
/// gutter already applied.
final class ContentColumn: UIScrollView {

    let column = UIStackView(axis: .vertical, spacing: Metric.sectionGap)
    private let innerContainer = UIView()

    init(spacing: CGFloat = Metric.sectionGap, gutter: CGFloat = Metric.gutter) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        showsVerticalScrollIndicator = false
        // A page that fits on screen must not bounce. With a bounce enabled, a
        // flick on a short page drags the pull-to-refresh control down with it,
        // which yanks the content and fires the refresh haptic on every screen —
        // for no reason, since nothing above the fold was hidden.
        alwaysBounceVertical = false
        keyboardDismissMode = .interactive
        contentInsetAdjustmentBehavior = .never

        column.spacing = spacing
        innerContainer.translatesAutoresizingMaskIntoConstraints = false
        column.translatesAutoresizingMaskIntoConstraints = false

        addSubview(innerContainer)
        innerContainer.addSubview(column)

        NSLayoutConstraint.activate([
            innerContainer.leadingAnchor.constraint(equalTo: contentLayoutGuide.leadingAnchor),
            innerContainer.trailingAnchor.constraint(equalTo: contentLayoutGuide.trailingAnchor),
            innerContainer.topAnchor.constraint(equalTo: contentLayoutGuide.topAnchor),
            innerContainer.bottomAnchor.constraint(equalTo: contentLayoutGuide.bottomAnchor),
            innerContainer.widthAnchor.constraint(equalTo: frameLayoutGuide.widthAnchor),

            column.leadingAnchor.constraint(equalTo: innerContainer.leadingAnchor, constant: gutter),
            column.trailingAnchor.constraint(equalTo: innerContainer.trailingAnchor, constant: -gutter),
            column.topAnchor.constraint(equalTo: innerContainer.topAnchor),
            column.bottomAnchor.constraint(equalTo: innerContainer.bottomAnchor)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func add(_ view: UIView) { column.addArrangedSubview(view) }

    /// Adjusts the gap that follows an already-added row.
    func setCustomSpacing(_ spacing: CGFloat, after view: UIView) {
        column.setCustomSpacing(spacing, after: view)
    }

    func setTopPadding(_ value: CGFloat) {
        column.isLayoutMarginsRelativeArrangement = true
        column.layoutMargins.top = value
    }

    func setBottomPadding(_ value: CGFloat) {
        column.isLayoutMarginsRelativeArrangement = true
        column.layoutMargins.bottom = value
    }

    // MARK: - Pull to refresh
    //
    // Attaching a refresh control makes a scroll view bounce even when its
    // content is shorter than the screen, so a plain drag on a short page drags
    // the control down, yanks the content with it and fires the refresh haptic —
    // to reveal nothing, because there is nothing out of sight. The control is
    // therefore only live while the column actually overflows the viewport.

    private var pullToRefresh: UIRefreshControl?

    /// Registers this screen's refresh control; it is attached only while the
    /// column is taller than the viewport.
    func installRefreshControl(_ control: UIRefreshControl) {
        pullToRefresh = control
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let overflows = contentSize.height > bounds.height + 1
        if overflows, refreshControl == nil, let control = pullToRefresh {
            refreshControl = control
        } else if !overflows, let control = refreshControl, !control.isRefreshing {
            refreshControl = nil
        }
    }
}

extension UIView {
    /// Wraps the receiver in a container with the standard gutter and returns it.
    func gutterPadded(_ inset: CGFloat = Metric.gutter) -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.addSubviews(self)
        NSLayoutConstraint.activate([
            leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: inset),
            trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -inset),
            topAnchor.constraint(equalTo: container.topAnchor),
            bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        return container
    }
}
