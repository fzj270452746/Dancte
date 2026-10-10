import UIKit

// MARK: - Color

extension UIColor {

    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255.0,
            green: CGFloat((hex >> 8) & 0xFF) / 255.0,
            blue: CGFloat(hex & 0xFF) / 255.0,
            alpha: alpha
        )
    }

    var hexString: String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }

    func mix(with other: UIColor, amount: CGFloat) -> UIColor {
        let t = max(0, min(1, amount))
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        other.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        return UIColor(
            red: r1 + (r2 - r1) * t,
            green: g1 + (g2 - g1) * t,
            blue: b1 + (b2 - b1) * t,
            alpha: a1 + (a2 - a1) * t
        )
    }

    func lighter(_ amount: CGFloat = 0.2) -> UIColor { mix(with: .white, amount: amount) }
    func darker(_ amount: CGFloat = 0.2) -> UIColor { mix(with: .black, amount: amount) }
}

// MARK: - Font

extension UIFont {

    /// The app's signature typeface: SF Pro Rounded, used across every surface
    /// so headlines feel soft, geometric and street-poster like.
    static func dancte(_ size: CGFloat, _ weight: UIFont.Weight = .regular) -> UIFont {
        let base = UIFont.systemFont(ofSize: size, weight: weight)
        guard let descriptor = base.fontDescriptor.withDesign(.rounded) else { return base }
        return UIFont(descriptor: descriptor, size: size)
    }

    static func dancteItalic(_ size: CGFloat, _ weight: UIFont.Weight = .semibold) -> UIFont {
        let base = UIFont.dancte(size, weight)
        guard let descriptor = base.fontDescriptor.withSymbolicTraits(.traitItalic) else { return base }
        return UIFont(descriptor: descriptor, size: size)
    }

    /// Monospaced digits — used for timers, counters and durations.
    static func dancteMono(_ size: CGFloat, _ weight: UIFont.Weight = .semibold) -> UIFont {
        UIFont.monospacedDigitSystemFont(ofSize: size, weight: weight)
    }
}

// MARK: - Layout

extension UIView {

    func addSubviews(_ views: UIView...) {
        views.forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            addSubview($0)
        }
    }

    func addSubviews(_ views: [UIView]) {
        views.forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            addSubview($0)
        }
    }

    @discardableResult
    func pinEdges(to other: UIView, insets: UIEdgeInsets = .zero) -> [NSLayoutConstraint] {
        let constraints = [
            leadingAnchor.constraint(equalTo: other.leadingAnchor, constant: insets.left),
            trailingAnchor.constraint(equalTo: other.trailingAnchor, constant: -insets.right),
            topAnchor.constraint(equalTo: other.topAnchor, constant: insets.top),
            bottomAnchor.constraint(equalTo: other.bottomAnchor, constant: -insets.bottom)
        ]
        NSLayoutConstraint.activate(constraints)
        return constraints
    }

    func roundCorners(_ radius: CGFloat, corners: CACornerMask = [.layerMinXMinYCorner, .layerMaxXMinYCorner, .layerMinXMaxYCorner, .layerMaxXMaxYCorner]) {
        layer.cornerRadius = radius
        layer.cornerCurve = .continuous
        layer.maskedCorners = corners
    }

    func applyShadow(color: UIColor = .black, opacity: Float = 0.45, radius: CGFloat = 18, y: CGFloat = 10) {
        layer.shadowColor = color.cgColor
        layer.shadowOpacity = opacity
        layer.shadowRadius = radius
        layer.shadowOffset = CGSize(width: 0, height: y)
    }

    func applyGlow(_ color: UIColor, opacity: Float = 0.55, radius: CGFloat = 22) {
        layer.shadowColor = color.cgColor
        layer.shadowOpacity = opacity
        layer.shadowRadius = radius
        layer.shadowOffset = .zero
    }

    func fadeIn(_ duration: TimeInterval = 0.25, delay: TimeInterval = 0, to alpha: CGFloat = 1) {
        self.alpha = 0
        UIView.animate(withDuration: duration, delay: delay, options: [.curveEaseOut]) { self.alpha = alpha }
    }

    func pulse(_ scale: CGFloat = 1.06, duration: TimeInterval = 0.14) {
        UIView.animate(withDuration: duration, animations: {
            self.transform = CGAffineTransform(scaleX: scale, y: scale)
        }, completion: { _ in
            UIView.animate(withDuration: duration) { self.transform = .identity }
        })
    }

    func shake() {
        let animation = CAKeyframeAnimation(keyPath: "transform.translation.x")
        animation.values = [-9, 9, -7, 7, -4, 4, 0]
        animation.duration = 0.42
        layer.add(animation, forKey: "shake")
    }
}

extension UIStackView {
    convenience init(axis: NSLayoutConstraint.Axis, spacing: CGFloat, alignment: UIStackView.Alignment = .fill, distribution: UIStackView.Distribution = .fill) {
        self.init()
        self.axis = axis
        self.spacing = spacing
        self.alignment = alignment
        self.distribution = distribution
        self.translatesAutoresizingMaskIntoConstraints = false
    }
}

// MARK: - Geometry

extension CGFloat {
    /// Scales a design value authored against a 390pt-wide canvas.
    var scaled: CGFloat { UIScreen.scaleFactor * self }
}

extension UIScreen {
    static var scaleFactor: CGFloat {
        let width = UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.coordinateSpace.bounds.width }
            .first ?? 390
        return min(max(width / 390.0, 0.86), 1.35)
    }

    static var screenWidth: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.coordinateSpace.bounds.width }
            .first ?? 390
    }

    static var screenHeight: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.coordinateSpace.bounds.height }
            .first ?? 844
    }

    static var hasNotch: Bool {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let top = scenes.first?.windows.first?.safeAreaInsets.top ?? 0
        return top > 24
    }
}

// MARK: - Date

extension Date {

    var startOfDay: Date { Calendar.current.startOfDay(for: self) }

    func adding(days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: days, to: self) ?? self
    }

    var isToday: Bool { Calendar.current.isDateInToday(self) }
    var isYesterday: Bool { Calendar.current.isDateInYesterday(self) }

    var dayKey: String { Date.dayKeyFormatter.string(from: self) }

    private static let dayKeyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    /// "just now", "12m", "3h", "5d", "Mar 4"
    var shortRelative: String {
        let seconds = Date().timeIntervalSince(self)
        if seconds < 60 { return "just now" }
        if seconds < 3_600 { return "\(Int(seconds / 60))m" }
        if seconds < 86_400 { return "\(Int(seconds / 3_600))h" }
        if seconds < 604_800 { return "\(Int(seconds / 86_400))d" }
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f.string(from: self)
    }

    /// "Today", "Yesterday", "Mon, Mar 4"
    var dayLabel: String {
        if isToday { return "Today" }
        if isYesterday { return "Yesterday" }
        let f = DateFormatter()
        f.dateFormat = Calendar.current.isDate(self, equalTo: Date(), toGranularity: .year) ? "EEE, MMM d" : "MMM d, yyyy"
        return f.string(from: self)
    }

    /// "09:41"
    var clockLabel: String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: self)
    }

    /// "March 2026"
    var monthLabel: String {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f.string(from: self)
    }
}

// MARK: - Number / Duration

enum Format {

    static func duration(_ seconds: Double) -> String {
        let total = max(0, Int(seconds.rounded()))
        let m = total / 60
        let s = total % 60
        return String(format: "%d:%02d", m, s)
    }

    static func longDuration(_ seconds: Double) -> String {
        let total = max(0, Int(seconds.rounded()))
        let h = total / 3600
        let m = (total % 3600) / 60
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m)m"
    }

    static func minutes(_ value: Int) -> String {
        if value < 60 { return "\(value) min" }
        let h = value / 60
        let m = value % 60
        return m == 0 ? "\(h) hr" : "\(h)h \(m)m"
    }

    static func compact(_ value: Int) -> String {
        switch value {
        case 1_000_000...: return String(format: "%.1fM", Double(value) / 1_000_000)
        case 1_000...: return String(format: "%.1fK", Double(value) / 1_000)
        default: return "\(value)"
        }
    }

    /// US-dollar pricing. The storefront's own currency is deliberately left
    /// out of it: the app quotes one currency everywhere rather than following
    /// the device's region.
    static func price(_ value: Decimal, currencyCode: String = "USD") -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        formatter.locale = Locale(identifier: "en_US")
        return formatter.string(from: value as NSDecimalNumber) ?? "$\(value)"
    }
}

// MARK: - String

extension String {

    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
    var isBlank: Bool { trimmed.isEmpty }

    func truncated(_ limit: Int) -> String {
        count <= limit ? self : String(prefix(limit)) + "…"
    }

    var handleized: String {
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789._")
        let lowered = trimmed.lowercased().replacingOccurrences(of: " ", with: ".")
        return String(lowered.unicodeScalars.filter { allowed.contains($0) }.prefix(24))
    }
}

// MARK: - Alerts & Global Text Prompt

extension UIViewController {

    var topMost: UIViewController {
        var controller: UIViewController = self
        while let presented = controller.presentedViewController, !presented.isBeingDismissed {
            controller = presented
        }
        if let nav = controller as? UINavigationController, let visible = nav.visibleViewController {
            return visible.topMost
        }
        if let tab = controller as? UITabBarController, let selected = tab.selectedViewController {
            return selected.topMost
        }
        return controller
    }

    func showAlert(title: String, message: String? = nil, confirmTitle: String = "OK") {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: confirmTitle, style: .default))
        alert.view.tintColor = Palette.lime
        present(alert, animated: true)
    }

    /// Destructive double-confirmation used by log out / delete account / delete post.
    func confirm(title: String,
                 message: String?,
                 confirmTitle: String,
                 destructive: Bool = true,
                 onConfirm: @escaping () -> Void) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: confirmTitle, style: destructive ? .destructive : .default) { _ in onConfirm() })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        if let popover = alert.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 1, height: 1)
            popover.permittedArrowDirections = []
        }
        present(alert, animated: true)
    }
}

// MARK: - Sheets

extension UIViewController {

    /// Presents a screen in the standard Dancte sheet: a navigation container
    /// with the system bar hidden, so the screen draws its own header.
    @discardableResult
    func presentSheet(_ controller: UIViewController) -> UINavigationController {
        let nav = DancteNavigationController(rootViewController: controller)
        nav.modalPresentationStyle = .pageSheet
        nav.setNavigationBarHidden(true, animated: false)
        if let sheet = nav.sheetPresentationController {
            sheet.prefersGrabberVisible = false
            sheet.preferredCornerRadius = 32
        }
        present(nav, animated: true)
        return nav
    }
}

// MARK: - Keyboard

extension UIViewController {

    /// Global tap-to-dismiss behaviour required across every screen with input.
    /// Safe to call repeatedly — the recogniser is only installed once per view.
    func installKeyboardDismissOnTap() {
        guard view.gestureRecognizers?.contains(where: { $0.name == Self.dismissGestureName }) != true else { return }
        let tap = UITapGestureRecognizer(target: self, action: #selector(UIViewController.dancte_dismissKeyboard))
        tap.name = Self.dismissGestureName
        tap.cancelsTouchesInView = false
        tap.delaysTouchesEnded = false
        tap.delegate = ControlExemptTapDelegate.passive
        view.addGestureRecognizer(tap)
    }

    private static let dismissGestureName = "dancte.dismissKeyboard"

    @objc private func dancte_dismissKeyboard() {
        view.endEditing(true)
    }
}

extension UIView {

    /// The closest ancestor (or self) that handles its own taps: a button, a
    /// switch, a text view. A tap recogniser sitting above one of these has to
    /// stand down, because a touch the recogniser takes is a touch the control
    /// never gets — the reason a button can seem to need a second tap.
    var nearestTapHandlingAncestor: UIView? {
        var node: UIView? = self
        while let view = node {
            if view is UIControl || view is UITextView || view is UITextField { return view }
            node = view.superview
        }
        return nil
    }
}

/// Shared rules for tap recognisers that sit on a view which also carries
/// controls — a card that opens a screen while holding its own Follow button, a
/// media stage that toggles playback above a transport bar.
final class ControlExemptTapDelegate: NSObject, UIGestureRecognizerDelegate {

    /// Passive taps (dismiss-keyboard) never fight another recogniser.
    static let passive = ControlExemptTapDelegate(simultaneous: true)
    /// Card taps own the gesture, so they never share it.
    static let exclusive = ControlExemptTapDelegate(simultaneous: false)

    private let simultaneous: Bool

    private init(simultaneous: Bool) {
        self.simultaneous = simultaneous
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        guard let control = touch.view?.nearestTapHandlingAncestor else { return true }
        // A control that *is* the recogniser's own view still belongs to the
        // recogniser — a tappable card is itself a control. Only a nested one,
        // such as a button inside the card, takes the touch for itself.
        return control === gestureRecognizer.view
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
        simultaneous
    }
}

// MARK: - Haptics

enum Haptics {

    static func tap() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func thump() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func warning() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }

    static func error() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }

    static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }
}

// MARK: - Async helpers

extension DispatchQueue {
    static func after(_ seconds: TimeInterval, _ block: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: block)
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
