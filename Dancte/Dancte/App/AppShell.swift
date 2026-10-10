import UIKit

// MARK: - Navigation controller

/// Every tab is wrapped in this controller. It hides the system bar on root
/// screens (which draw their own headline) and restores it for pushed screens,
/// while reporting depth so the custom tab bar can slide away.
final class DancteNavigationController: UINavigationController, UINavigationControllerDelegate {

    var onDepthChange: ((Int) -> Void)?

    private var hasAppeared = false

    override func viewDidLoad() {
        super.viewDidLoad()
        delegate = self
        view.backgroundColor = Palette.ink
        interactivePopGestureRecognizer?.delegate = nil
        navigationBar.tintColor = Palette.text
        navigationBar.shadowImage = UIImage()
        navigationBar.setBackgroundImage(UIImage(), for: .default)
        navigationBar.titleTextAttributes = [.foregroundColor: Palette.text, .font: UIFont.dancte(17, .bold)]
        setNavigationBarHidden(true, animated: false)
    }

    override var childForStatusBarStyle: UIViewController? { topViewController }

    func navigationController(_ navigationController: UINavigationController,
                              willShow viewController: UIViewController,
                              animated: Bool) {
        let isRoot = navigationController.viewControllers.first === viewController
        let wantsOwn = (viewController as? OwnsNavigationBar)?.prefersOwnHeader ?? false
        setNavigationBarHidden(isRoot || wantsOwn, animated: animated && hasAppeared)
        hasAppeared = true
    }

    func navigationController(_ navigationController: UINavigationController,
                              didShow viewController: UIViewController,
                              animated: Bool) {
        // Every screen gets tap-to-dismiss, so no input can trap the keyboard.
        viewController.installKeyboardDismissOnTap()
        onDepthChange?(navigationController.viewControllers.count)
    }
}

/// Adopt on a pushed screen that draws its own header instead of using the bar.
protocol OwnsNavigationBar {
    var prefersOwnHeader: Bool { get }
}

// MARK: - Tab bar

final class StudioTabBar: UIView {

    var onSelect: ((Int) -> Void)?
    var onCompose: (() -> Void)?

    private struct Slot {
        let control: UIControl
        let icon: UIImageView
        let dot: UIView
        var badge: CountBadge?
    }

    private static let symbols = [
        "play.rectangle.fill",
        "flame.fill",
        "plus",
        "bubble.left.and.bubble.right.fill",
        "person.fill"
    ]

    private var slots: [Slot] = []
    private let pill = UIView()
    private let blur = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
    private(set) var selectedIndex = 0

    override init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = .clear

        pill.translatesAutoresizingMaskIntoConstraints = false
        pill.backgroundColor = UIColor(hex: 0x14161D).withAlphaComponent(0.72)
        pill.layer.cornerRadius = 30
        pill.layer.cornerCurve = .continuous
        pill.layer.borderWidth = 1
        pill.layer.borderColor = Palette.strokeHi.withAlphaComponent(0.45).cgColor
        pill.clipsToBounds = true
        addSubview(pill)

        blur.translatesAutoresizingMaskIntoConstraints = false
        pill.addSubview(blur)

        let row = UIStackView(axis: .horizontal, spacing: 0, distribution: .fillEqually)
        row.translatesAutoresizingMaskIntoConstraints = false
        pill.addSubview(row)

        for (index, symbol) in Self.symbols.enumerated() {
            let isCompose = index == 2
            let control = UIControl()
            control.translatesAutoresizingMaskIntoConstraints = false
            control.accessibilityLabel = Self.label(for: index)
            control.accessibilityTraits = .button

            let icon = UIImageView(image: UIImage(systemName: symbol, withConfiguration:
                                                    UIImage.SymbolConfiguration(pointSize: isCompose ? 20 : 18, weight: .bold)))
            icon.contentMode = .center
            icon.translatesAutoresizingMaskIntoConstraints = false
            icon.tintColor = Palette.textFaint
            icon.isUserInteractionEnabled = false

            control.addSubviews(icon)

            let dot = UIView()
            dot.translatesAutoresizingMaskIntoConstraints = false
            dot.backgroundColor = Palette.lime
            dot.layer.cornerRadius = 2
            dot.alpha = 0
            dot.isUserInteractionEnabled = false
            control.addSubview(dot)

            if isCompose {
                let halo = UIView()
                halo.translatesAutoresizingMaskIntoConstraints = false
                halo.backgroundColor = Palette.lime
                halo.layer.cornerRadius = 25
                halo.layer.cornerCurve = .continuous
                halo.layer.shadowColor = Palette.lime.cgColor
                halo.layer.shadowOpacity = 0.45
                halo.layer.shadowRadius = 14
                halo.layer.shadowOffset = CGSize(width: 0, height: 6)
                halo.isUserInteractionEnabled = false
                control.insertSubview(halo, belowSubview: icon)
                NSLayoutConstraint.activate([
                    halo.centerXAnchor.constraint(equalTo: control.centerXAnchor),
                    halo.centerYAnchor.constraint(equalTo: control.centerYAnchor),
                    halo.widthAnchor.constraint(equalToConstant: 50),
                    halo.heightAnchor.constraint(equalToConstant: 50)
                ])
                icon.tintColor = Palette.ink
            }

            NSLayoutConstraint.activate([
                icon.centerXAnchor.constraint(equalTo: control.centerXAnchor),
                icon.centerYAnchor.constraint(equalTo: control.centerYAnchor),
                dot.widthAnchor.constraint(equalToConstant: 4),
                dot.heightAnchor.constraint(equalToConstant: 4),
                dot.centerXAnchor.constraint(equalTo: control.centerXAnchor),
                dot.bottomAnchor.constraint(equalTo: control.bottomAnchor, constant: -9)
            ])

            control.addAction(UIAction { [weak self] _ in
                Haptics.tap()
                if isCompose { self?.onCompose?() } else { self?.onSelect?(index) }
            }, for: .touchUpInside)

            slots.append(Slot(control: control, icon: icon, dot: dot, badge: nil))
            row.addArrangedSubview(control)
        }

        addSubviews(row)
        NSLayoutConstraint.activate([
            pill.leadingAnchor.constraint(equalTo: leadingAnchor),
            pill.trailingAnchor.constraint(equalTo: trailingAnchor),
            pill.topAnchor.constraint(equalTo: topAnchor),
            pill.bottomAnchor.constraint(equalTo: bottomAnchor),

            blur.leadingAnchor.constraint(equalTo: pill.leadingAnchor),
            blur.trailingAnchor.constraint(equalTo: pill.trailingAnchor),
            blur.topAnchor.constraint(equalTo: pill.topAnchor),
            blur.bottomAnchor.constraint(equalTo: pill.bottomAnchor),

            row.leadingAnchor.constraint(equalTo: pill.leadingAnchor, constant: 6),
            row.trailingAnchor.constraint(equalTo: pill.trailingAnchor, constant: -6),
            row.topAnchor.constraint(equalTo: pill.topAnchor),
            row.bottomAnchor.constraint(equalTo: pill.bottomAnchor)
        ])

        refresh(animated: false)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private static func label(for index: Int) -> String {
        ["Spotlight", "Studio", "Create", "Messages", "Me"][index]
    }

    func setSelected(_ index: Int, animated: Bool = true) {
        selectedIndex = index
        refresh(animated: animated)
    }

    func setBadge(_ count: Int, at index: Int) {
        guard let slot = slots[safe: index] else { return }
        slot.badge?.removeFromSuperview()
        slots[index].badge = nil
        guard count > 0 else { return }
        let badge = CountBadge(count: count)
        slot.control.addSubview(badge)
        NSLayoutConstraint.activate([
            badge.centerXAnchor.constraint(equalTo: slot.icon.centerXAnchor, constant: 13),
            badge.centerYAnchor.constraint(equalTo: slot.icon.centerYAnchor, constant: -10)
        ])
        slots[index].badge = badge
        badge.transform = CGAffineTransform(scaleX: 0.3, y: 0.3)
        UIView.animate(withDuration: 0.35, delay: 0, usingSpringWithDamping: 0.6, initialSpringVelocity: 0.6) {
            badge.transform = .identity
        }
    }

    private func refresh(animated: Bool) {
        let changes = {
            for (index, slot) in self.slots.enumerated() {
                guard index != 2 else { continue }
                let isOn = index == self.selectedIndex
                slot.icon.tintColor = isOn ? Palette.lime : Palette.textFaint
                slot.dot.alpha = isOn ? 1 : 0
                slot.icon.transform = isOn ? CGAffineTransform(scaleX: 1.06, y: 1.06) : .identity
            }
        }
        if animated {
            UIView.animate(withDuration: 0.22, animations: changes)
        } else {
            changes()
        }
    }
}

// MARK: - Root tab controller

final class MainTabBarController: UIViewController {

    private let contentView = UIView()
    private let tabBar = StudioTabBar()
    private var navigationControllers: [DancteNavigationController] = []
    private var currentIndex = 0

    /// Slot 2 of the bar is the compose button, so the four real tabs sit at
    /// slots 0, 1, 3 and 4. These two maps keep bar positions and controller
    /// indices in step.
    private static let controllerForSlot: [Int: Int] = [0: 0, 1: 1, 3: 2, 4: 3]
    private static let slotForController: [Int: Int] = [0: 0, 1: 1, 2: 3, 3: 4]

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Palette.ink

        contentView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubviews(contentView, tabBar)

        NSLayoutConstraint.activate([
            contentView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            contentView.topAnchor.constraint(equalTo: view.topAnchor),
            contentView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            tabBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            tabBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            tabBar.heightAnchor.constraint(equalToConstant: 60),
            tabBar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -6)
        ])

        buildTabs()
        tabBar.onSelect = { [weak self] slot in self?.handleSlot(slot) }
        tabBar.onCompose = { [weak self] in self?.presentComposer() }
        selectController(0)

        NotificationCenter.default.addObserver(self, selector: #selector(refreshBadges),
                                               name: .dancteChat, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(refreshBadges),
                                               name: .dancteAuth, object: nil)
        refreshBadges()
    }

    override var childForStatusBarStyle: UIViewController? {
        navigationControllers[safe: currentIndex]
    }

    private func buildTabs() {
        let roots: [UIViewController] = [
            HomeViewController(),
            StudioViewController(),
            ChatListViewController(),
            ProfileViewController()
        ]

        for root in roots {
            let nav = DancteNavigationController(rootViewController: root)
            nav.onDepthChange = { [weak self] depth in
                self?.setTabBar(hidden: depth > 1)
            }
            addChild(nav)
            contentView.addSubviews(nav.view)
            nav.view.pinEdges(to: contentView)
            nav.didMove(toParent: self)
            navigationControllers.append(nav)
            nav.view.isHidden = true
            root.installKeyboardDismissOnTap()
        }
    }

    private func handleSlot(_ slot: Int) {
        guard let index = Self.controllerForSlot[slot] else { return }
        selectController(index)
    }

    private func selectController(_ index: Int) {
        guard let nav = navigationControllers[safe: index] else { return }
        if index != currentIndex {
            navigationControllers[safe: currentIndex]?.view.isHidden = true
        }
        currentIndex = index
        nav.view.isHidden = false
        tabBar.setSelected(Self.slotForController[index] ?? 0)
        setTabBar(hidden: nav.viewControllers.count > 1)
        setNeedsStatusBarAppearanceUpdate()
    }

    /// Lets a child push a screen inside the currently selected tab.
    func push(_ controller: UIViewController) {
        navigationControllers[safe: currentIndex]?.pushViewController(controller, animated: true)
    }

    /// Selects a tab by controller index (Home 0, Studio 1, Messages 2, Me 3).
    func selectTab(_ index: Int) {
        selectController(index)
    }

    /// Brings the home wall forward and, when a tag is given, asks it to jump
    /// straight to the community section filtered on that tag.
    func focusCommunity(tag: String? = nil) {
        selectController(0)
        navigationControllers[safe: 0]?.popToRootViewController(animated: false)
        guard let tag else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            NotificationCenter.default.post(name: .dancteOpenTag, object: tag)
        }
    }

    private var isTabBarHidden = false

    private func setTabBar(hidden: Bool) {
        guard hidden != isTabBarHidden else { return }
        isTabBarHidden = hidden
        UIView.animate(withDuration: 0.28, delay: 0, options: [.curveEaseInOut]) {
            self.tabBar.alpha = hidden ? 0 : 1
            self.tabBar.transform = hidden
                ? CGAffineTransform(translationX: 0, y: 96)
                : .identity
        }
    }

    private func presentComposer() {
        let composer = PublishViewController()
        let nav = DancteNavigationController(rootViewController: composer)
        nav.modalPresentationStyle = .pageSheet
        nav.setNavigationBarHidden(true, animated: false)
        present(nav, animated: true)
    }

    @objc private func refreshBadges() {
        tabBar.setBadge(store.isSignedIn ? store.totalUnread : 0, at: 3)
    }

    /// Bottom inset every tab root should apply to its scroll content so the
    /// floating bar never covers the last row.
    static var contentBottomInset: CGFloat { 60 + 6 + 20 }
}
