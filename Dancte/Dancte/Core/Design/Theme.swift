import UIKit

// MARK: - Palette
//
// Dancte's identity is built on an "after-hours studio" palette: near-black
// asphalt surfaces, acid lime as the hero accent, and a hot blaze orange that
// only ever appears on things you can act on. Cyan and violet are reserved for
// data (practice stats) and community content respectively, so the two halves
// of the app stay visually distinguishable at a glance.

enum Palette {

    // Grounds
    static let ink       = UIColor(hex: 0x08090D)
    static let inkSoft   = UIColor(hex: 0x101218)
    static let surface   = UIColor(hex: 0x171A23)
    static let surfaceHi = UIColor(hex: 0x20242F)
    static let surfaceLo = UIColor(hex: 0x0D0F14)
    static let stroke    = UIColor(hex: 0x2B3040)
    static let strokeHi  = UIColor(hex: 0x3C4356)

    // Accents
    static let lime      = UIColor(hex: 0xD9FF3C)
    static let limeDeep  = UIColor(hex: 0xA5E010)
    static let blaze     = UIColor(hex: 0xFF5B1F)
    static let blazeDeep = UIColor(hex: 0xE2350F)
    static let cyan      = UIColor(hex: 0x2FE3D4)
    static let cyanDeep  = UIColor(hex: 0x12A9BE)
    static let violet    = UIColor(hex: 0x8B5CF6)
    static let violetDeep = UIColor(hex: 0x6335E0)
    static let magenta   = UIColor(hex: 0xFF3D7F)
    static let amber     = UIColor(hex: 0xFFC53D)

    // Text
    static let text      = UIColor(hex: 0xF4F6FA)
    static let textMuted = UIColor(hex: 0x9BA3B4)
    static let textFaint = UIColor(hex: 0x626A7B)

    /// Four-strong accent rotation used for style tagging, gift art and
    /// practice charts so every generated surface stays on-brand.
    static let rotation: [UIColor] = [lime, blaze, cyan, violet, magenta, amber]

    static func accent(_ index: Int) -> UIColor {
        rotation[((index % rotation.count) + rotation.count) % rotation.count]
    }
}

// MARK: - Gradients

enum Grad {

    static let lime    = [UIColor(hex: 0xE4FF63), Palette.limeDeep]
    static let blaze   = [UIColor(hex: 0xFF9A43), Palette.blazeDeep]
    static let cyan    = [UIColor(hex: 0x63F2E6), Palette.cyanDeep]
    static let violet  = [UIColor(hex: 0xA98BFF), Palette.violetDeep]
    static let magenta = [UIColor(hex: 0xFF7FB2), UIColor(hex: 0xE01967)]
    static let amber   = [UIColor(hex: 0xFFD870), UIColor(hex: 0xE08A00)]

    static let ground  = [UIColor(hex: 0x14161F), Palette.ink]
    static let card    = [UIColor(hex: 0x1E222E), UIColor(hex: 0x14171F)]
    static let night   = [UIColor(hex: 0x0B0D14), UIColor(hex: 0x05060A)]

    static func forAccent(_ index: Int) -> [UIColor] {
        [lime, blaze, cyan, violet, magenta, amber][((index % 6) + 6) % 6]
    }

    static func forColor(_ color: UIColor) -> [UIColor] {
        [color.lighter(0.22), color.darker(0.16)]
    }
}

// MARK: - Typography

enum Typo {

    static var hero: UIFont { .dancte(38, .black) }
    static var display: UIFont { .dancte(31, .black) }
    static var title: UIFont { .dancte(24, .bold) }
    static var headline: UIFont { .dancte(19, .bold) }
    static var subhead: UIFont { .dancte(17, .semibold) }
    static var body: UIFont { .dancte(15.5, .regular) }
    static var bodyStrong: UIFont { .dancte(15.5, .semibold) }
    static var callout: UIFont { .dancte(14, .medium) }
    static var caption: UIFont { .dancte(12.5, .medium) }
    static var micro: UIFont { .dancte(11, .bold) }
    static var nano: UIFont { .dancte(9.5, .bold) }
}

extension UILabel {

    /// Small all-caps label used for section eyebrows.
    static func eyebrow(_ text: String, color: UIColor = Palette.textFaint) -> UILabel {
        let label = UILabel()
        label.attributedText = NSAttributedString(
            string: text.uppercased(),
            attributes: [.kern: 1.6, .font: Typo.micro, .foregroundColor: color]
        )
        return label
    }
}

// MARK: - Metrics

enum Metric {

    static let gutter: CGFloat = 20
    static let tightGutter: CGFloat = 14
    static let cardRadius: CGFloat = 28
    static let innerRadius: CGFloat = 20
    static let smallRadius: CGFloat = 14
    static let pillRadius: CGFloat = 999
    static let tabBarHeight: CGFloat = 68
    static let headerHeight: CGFloat = 56
    static let sectionGap: CGFloat = 26
}

// MARK: - Shared background

/// The app-wide animated studio backdrop: a near-black ground with two slow
/// moving accent blooms. Every screen sits on top of one so the whole product
/// feels like a single continuous space.
final class StudioBackdropView: UIView {

    private let topBloom = CAGradientLayer()
    private let bottomBloom = CAGradientLayer()
    private let grain = CAGradientLayer()
    private var animated = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        backgroundColor = Palette.ink

        topBloom.type = .radial
        topBloom.colors = [Palette.lime.withAlphaComponent(0.17).cgColor,
                           Palette.lime.withAlphaComponent(0.0).cgColor]
        topBloom.startPoint = CGPoint(x: 0.5, y: 0.5)
        topBloom.endPoint = CGPoint(x: 1, y: 1)
        layer.addSublayer(topBloom)

        bottomBloom.type = .radial
        bottomBloom.colors = [Palette.violet.withAlphaComponent(0.22).cgColor,
                              Palette.violet.withAlphaComponent(0.0).cgColor]
        bottomBloom.startPoint = CGPoint(x: 0.5, y: 0.5)
        bottomBloom.endPoint = CGPoint(x: 1, y: 1)
        layer.addSublayer(bottomBloom)

        grain.colors = [UIColor(hex: 0x101218).cgColor, Palette.ink.cgColor]
        grain.startPoint = CGPoint(x: 0.1, y: 0)
        grain.endPoint = CGPoint(x: 0.9, y: 1)
        layer.insertSublayer(grain, at: 0)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        grain.frame = bounds
        let w = bounds.width
        let h = bounds.height
        topBloom.frame = CGRect(x: -w * 0.45, y: -h * 0.16, width: w * 1.5, height: w * 1.5)
        bottomBloom.frame = CGRect(x: w * 0.05, y: h * 0.48, width: w * 1.4, height: w * 1.4)
        topBloom.cornerRadius = topBloom.frame.width / 2
        bottomBloom.cornerRadius = bottomBloom.frame.width / 2
    }

    func startAnimating() {
        guard !animated, window != nil else { return }
        animated = true
        animate(bloom: topBloom, to: CGPoint(x: -bounds.width * 0.15, y: -bounds.height * 0.05), duration: 11)
        animate(bloom: bottomBloom, to: CGPoint(x: -bounds.width * 0.3, y: bounds.height * 0.2), duration: 14)
    }

    private func animate(bloom: CAGradientLayer, to point: CGPoint, duration: TimeInterval) {
        let animation = CABasicAnimation(keyPath: "position")
        animation.toValue = NSValue(cgPoint: point)
        animation.duration = duration
        animation.autoreverses = true
        animation.repeatCount = .infinity
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        bloom.add(animation, forKey: "drift")
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil { startAnimating() }
    }
}

// MARK: - Small helpers

extension UIView {
    static func gradientLayer(_ colors: [UIColor], frame: CGRect) -> CAGradientLayer {
        let layer = CAGradientLayer()
        layer.colors = colors.map(\.cgColor)
        layer.startPoint = CGPoint(x: 0, y: 0)
        layer.endPoint = CGPoint(x: 1, y: 1)
        layer.frame = frame
        return layer
    }
}

/// Deterministic pseudo-random generator so generated art is stable per seed.
struct SeededRandom: RandomNumberGenerator {
    private var state: UInt64

    init(seed: String) {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in seed.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        state = hash == 0 ? 0x9E3779B97F4A7C15 : hash
    }

    mutating func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }

    mutating func int(_ range: ClosedRange<Int>) -> Int {
        let span = UInt64(range.upperBound - range.lowerBound + 1)
        return range.lowerBound + Int(next() % span)
    }

    mutating func double(_ range: ClosedRange<Double>) -> Double {
        let unit = Double(next() % 10_000) / 10_000.0
        return range.lowerBound + unit * (range.upperBound - range.lowerBound)
    }

    mutating func pick<T>(_ items: [T]) -> T {
        items[int(0...(items.count - 1))]
    }
}
