import UIKit

// MARK: - Menu row

final class MenuRowView: RowControl {

    var onTap: (() -> Void)?

    private let iconTile = UIView()
    private let icon = UIImageView()
    private let titleLabel = UILabel()
    private let detailLabel = UILabel()
    private let chevron = UIImageView()
    private let badge = CountBadge(count: 0)

    init(symbol: String, title: String, detail: String? = nil, accent: UIColor = Palette.lime, badgeCount: Int = 0) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        accessibilityLabel = title
        accessibilityTraits = .button

        iconTile.backgroundColor = accent.withAlphaComponent(0.15)
        iconTile.layer.cornerRadius = 13
        iconTile.layer.cornerCurve = .continuous
        iconTile.translatesAutoresizingMaskIntoConstraints = false
        icon.image = UIImage(systemName: symbol, withConfiguration: UIImage.SymbolConfiguration(pointSize: 16, weight: .bold))
        icon.tintColor = accent
        icon.contentMode = .center
        iconTile.addSubviews(icon)

        titleLabel.text = title
        titleLabel.font = .dancte(15.5, .bold)
        titleLabel.textColor = Palette.text

        detailLabel.text = detail
        detailLabel.font = .dancte(11.5, .medium)
        detailLabel.textColor = Palette.textFaint
        detailLabel.numberOfLines = 1

        chevron.image = UIImage(systemName: "chevron.right", withConfiguration: UIImage.SymbolConfiguration(pointSize: 12, weight: .bold))
        chevron.tintColor = Palette.textFaint
        chevron.setContentHuggingPriority(.required, for: .horizontal)

        badge.isHidden = badgeCount == 0
        badge.setCount(badgeCount)
        badge.setContentHuggingPriority(.required, for: .horizontal)

        let text = UIStackView(arrangedSubviews: [titleLabel, detailLabel])
        text.axis = .vertical
        text.spacing = 1
        text.isUserInteractionEnabled = false

        addSubviews(iconTile, text, badge, chevron)
        NSLayoutConstraint.activate([
            heightAnchor.constraint(greaterThanOrEqualToConstant: 60),
            iconTile.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            iconTile.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconTile.widthAnchor.constraint(equalToConstant: 34),
            iconTile.heightAnchor.constraint(equalToConstant: 34),
            icon.centerXAnchor.constraint(equalTo: iconTile.centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: iconTile.centerYAnchor),
            text.leadingAnchor.constraint(equalTo: iconTile.trailingAnchor, constant: 12),
            text.topAnchor.constraint(equalTo: topAnchor, constant: 14),
            text.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -14),
            chevron.leadingAnchor.constraint(greaterThanOrEqualTo: text.trailingAnchor, constant: 8),
            chevron.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            chevron.centerYAnchor.constraint(equalTo: centerYAnchor),
            badge.trailingAnchor.constraint(equalTo: chevron.leadingAnchor, constant: -10),
            badge.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])

        addAction(UIAction { [weak self] _ in
            Haptics.tap()
            self?.onTap?()
        }, for: .touchUpInside)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var isHighlighted: Bool {
        didSet {
            UIView.animate(withDuration: 0.12) {
                self.backgroundColor = self.isHighlighted
                    ? Palette.surfaceHi.withAlphaComponent(0.6)
                    : .clear
            }
        }
    }
}

// MARK: - Profile

final class ProfileViewController: UIViewController, OwnsNavigationBar {

    var prefersOwnHeader: Bool { true }

    private let scroll = ContentColumn(spacing: 20, gutter: 0)
    private let signedInStack = UIStackView(axis: .vertical, spacing: 20)
    private let signedOutState = UIView()
    private let identityCard = UIView()
    private let menuCard = SurfaceCard(colors: Grad.card, radius: 26, border: Palette.stroke.withAlphaComponent(0.8))
    private let menuStack = UIStackView(axis: .vertical, spacing: 0)
    private let dangerCard = SurfaceCard(colors: [Palette.magenta.withAlphaComponent(0.12), Palette.surface],
                                         radius: 24, border: Palette.magenta.withAlphaComponent(0.35))

    private let avatar = RingedAvatarView(size: 92)
    private let nameLabel = UILabel()
    private let handleLabel = UILabel()
    private let verifiedIcon = UIImageView()
    private let bioLabel = UILabel()
    private let metaLabel = UILabel()
    private let styleFlow = TagFlowView(accent: Palette.lime)
    private let statsRow = UIStackView(axis: .horizontal, spacing: 10)

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Palette.ink

        let backdrop = StudioBackdropView()
        view.addSubviews(backdrop)
        backdrop.pinEdges(to: view)

        scroll.setTopPadding(6)
        scroll.setBottomPadding(MainTabBarController.contentBottomInset + 24)
        view.addSubviews(scroll)
        scroll.pinEdges(to: view)

        buildSignedOut()
        buildSignedIn()
        scroll.add(signedOutState)
        scroll.add(signedInStack)

        NotificationCenter.default.addObserver(self, selector: #selector(reload), name: .dancteAuth, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(reload), name: .dancteFeed, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(reload), name: .dancteRelations, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(reload), name: .danctePractice, object: nil)
        reload()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reload()
    }

    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

    // MARK: - Signed out

    private func buildSignedOut() {
        signedOutState.translatesAutoresizingMaskIntoConstraints = false

        let mark = BrandMarkView(size: 68)
        let title = UILabel()
        title.text = "Your studio"
        title.font = .dancte(28, .black)
        title.textColor = Palette.text
        title.textAlignment = .center

        let message = UILabel()
        message.text = "Sign in to manage your profile, keep your training log and publish your work."
        message.font = Typo.body
        message.textColor = Palette.textMuted
        message.textAlignment = .center
        message.numberOfLines = 0

        let signIn = PillButton("Sign In", symbol: "arrow.right", style: .primary)
        signIn.onTap = { [weak self] in
            guard let self else { return }
            AuthGate.require(.profile, from: self) { self.reload() }
        }

        let about = PillButton("About Dancte", symbol: "info.circle", style: .outline, height: 50)
        about.onTap = { [weak self] in
            self?.navigationController?.pushViewController(AboutViewController(), animated: true)
        }

        let column = UIStackView(arrangedSubviews: [mark, title, message, signIn, about])
        column.axis = .vertical
        column.spacing = 14
        column.alignment = .center
        column.setCustomSpacing(22, after: mark)
        column.setCustomSpacing(26, after: message)
        column.translatesAutoresizingMaskIntoConstraints = false

        signedOutState.addSubviews(column)
        NSLayoutConstraint.activate([
            column.leadingAnchor.constraint(equalTo: signedOutState.leadingAnchor, constant: Metric.gutter),
            column.trailingAnchor.constraint(equalTo: signedOutState.trailingAnchor, constant: -Metric.gutter),
            column.topAnchor.constraint(equalTo: signedOutState.topAnchor, constant: 40),
            column.bottomAnchor.constraint(equalTo: signedOutState.bottomAnchor, constant: -20),
            signIn.widthAnchor.constraint(equalToConstant: 220),
            about.widthAnchor.constraint(equalToConstant: 220)
        ])
    }

    // MARK: - Signed in

    private func buildSignedIn() {
        signedInStack.translatesAutoresizingMaskIntoConstraints = false

        let title = UILabel()
        title.text = "Me"
        title.font = .dancte(34, .black)
        title.textColor = Palette.text

        let header = UIStackView(arrangedSubviews: [title])
        header.axis = .vertical
        signedInStack.addArrangedSubview(header.gutterPadded())

        buildIdentityCard()
        signedInStack.addArrangedSubview(identityCard.gutterPadded())

        menuStack.axis = .vertical
        menuStack.spacing = 0
        menuCard.addSubviews(menuStack)
        NSLayoutConstraint.activate([
            menuStack.leadingAnchor.constraint(equalTo: menuCard.leadingAnchor, constant: 6),
            menuStack.trailingAnchor.constraint(equalTo: menuCard.trailingAnchor, constant: -6),
            menuStack.topAnchor.constraint(equalTo: menuCard.topAnchor, constant: 8),
            menuStack.bottomAnchor.constraint(equalTo: menuCard.bottomAnchor, constant: -8)
        ])
        signedInStack.addArrangedSubview(menuCard.gutterPadded())
        buildMenu()

        buildDangerCard()
        signedInStack.addArrangedSubview(dangerCard.gutterPadded())

        let version = UILabel()
        version.text = "Dancte · Version 1.0"
        version.font = Typo.caption
        version.textColor = Palette.textFaint
        version.textAlignment = .center
        signedInStack.addArrangedSubview(version.gutterPadded())
    }

    private func buildIdentityCard() {
        identityCard.translatesAutoresizingMaskIntoConstraints = false
        let card = SurfaceCard(colors: [UIColor(hex: 0x1C2230), UIColor(hex: 0x111520)],
                               radius: 30, border: Palette.strokeHi.withAlphaComponent(0.5))
        identityCard.addSubviews(card)
        card.pinEdges(to: identityCard)

        avatar.isUserInteractionEnabled = true
        avatar.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(openEditProfile)))

        nameLabel.font = .dancte(24, .black)
        nameLabel.textColor = Palette.text
        nameLabel.numberOfLines = 1

        verifiedIcon.image = UIImage(systemName: "checkmark.seal.fill", withConfiguration: UIImage.SymbolConfiguration(pointSize: 15, weight: .bold))
        verifiedIcon.tintColor = Palette.cyan

        handleLabel.font = .dancte(13, .semibold)
        handleLabel.textColor = Palette.textFaint

        let nameRow = UIStackView(arrangedSubviews: [nameLabel, verifiedIcon, UIView()])
        nameRow.axis = .horizontal
        nameRow.spacing = 5
        nameRow.alignment = .center

        let text = UIStackView(arrangedSubviews: [nameRow, handleLabel])
        text.axis = .vertical
        text.spacing = 2

        let editButton = IconButton(symbol: "pencil", size: 40, background: .glass, pointSize: 15)
        editButton.onTap = { [weak self] in self?.openEditProfile() }

        let topRow = UIStackView(arrangedSubviews: [avatar, text, editButton])
        topRow.axis = .horizontal
        topRow.spacing = 14
        topRow.alignment = .center
        avatar.setContentHuggingPriority(.required, for: .horizontal)
        editButton.setContentHuggingPriority(.required, for: .horizontal)

        bioLabel.font = Typo.body
        bioLabel.textColor = Palette.textMuted
        bioLabel.numberOfLines = 0

        metaLabel.font = Typo.caption
        metaLabel.textColor = Palette.textFaint

        styleFlow.onToggle = { _ in }

        statsRow.axis = .horizontal
        statsRow.spacing = 10
        statsRow.distribution = .fillEqually

        let column = UIStackView(arrangedSubviews: [topRow, bioLabel, metaLabel, styleFlow, statsRow])
        column.axis = .vertical
        column.spacing = 12
        column.setCustomSpacing(16, after: topRow)
        column.setCustomSpacing(18, after: styleFlow)

        card.addSubviews(column)
        NSLayoutConstraint.activate([
            column.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 18),
            column.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -18),
            column.topAnchor.constraint(equalTo: card.topAnchor, constant: 20),
            column.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -20)
        ])
    }

    private func buildStats() {
        statsRow.arrangedSubviews.forEach { $0.removeFromSuperview() }
        guard let user = store.currentUser else { return }
        let postCount = store.myPosts.count

        let stats: [(String, String, UIColor, () -> Void)] = [
            (Format.compact(postCount), "Posts", Palette.lime, { [weak self] in self?.open(MyWorksViewController()) }),
            (Format.compact(user.followerCount), "Followers", Palette.cyan, { [weak self] in
                self?.open(PeopleListViewController(title: "Followers", subtitle: "Dancers following you",
                                                    users: store.followerList, emptyMessage: "You don't have followers yet. Publish something and they'll find you."))
            }),
            (Format.compact(store.following.count), "Following", Palette.violet, { [weak self] in self?.open(MyFollowingViewController()) })
        ]

        for (value, caption, accent, action) in stats {
            let tile = StatTile(value: value, caption: caption, accent: accent, compact: true)
            let wrapper = ClosureControl(onTap: action)
            wrapper.addSubviews(tile)
            tile.pinEdges(to: wrapper)
            statsRow.addArrangedSubview(wrapper)
        }
    }

    private func buildMenu() {
        menuStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        guard store.isSignedIn else { return }

        let studioDetail = "\(store.stats.totalSessions) sessions · \(store.plans.count) plan\(store.plans.count == 1 ? "" : "s")"
        let rows: [MenuRowView] = [
            makeRow(symbol: "person.crop.circle.fill", title: "Edit Profile",
                    detail: "Photo, name, bio and styles", accent: Palette.lime) { [weak self] in
                self?.openEditProfile()
            },
            makeRow(symbol: "flame.fill", title: "Studio", detail: studioDetail, accent: Palette.blaze) { [weak self] in
                self?.openStudio()
            },
            makeRow(symbol: "square.grid.2x2.fill", title: "My Works",
                    detail: "\(store.myPosts.count) published", accent: Palette.cyan) { [weak self] in
                self?.open(MyWorksViewController())
            },
            makeRow(symbol: "heart.fill", title: "My Likes",
                    detail: "\(store.likedPosts.count) liked", accent: Palette.magenta) { [weak self] in
                self?.open(MyLikesViewController())
            },
            makeRow(symbol: "bookmark.fill", title: "Saved",
                    detail: "\(store.savedPosts.count) saved", accent: Palette.amber) { [weak self] in
                self?.open(SavedPostsViewController())
            },
            makeRow(symbol: "person.2.fill", title: "My Following",
                    detail: "\(store.following.count) dancers", accent: Palette.violet) { [weak self] in
                self?.open(MyFollowingViewController())
            },
            makeRow(symbol: "bubble.left.and.bubble.right.fill", title: "Connections",
                    detail: "\(store.friends.count) friends can message you", accent: Palette.cyan) { [weak self] in
                self?.open(PeopleListViewController(title: "Connections", subtitle: "Friends who can message you",
                                                    users: store.friendList,
                                                    emptyMessage: "No connections yet. Send a request from another dancer's profile."))
            },
            // Terms, privacy and the EULA all live inside About Dancte, so there
            // is no separate Legal row here.
            makeRow(symbol: "info.circle.fill", title: "About Dancte",
                    detail: "Terms, privacy and what the app does", accent: Palette.textMuted) { [weak self] in
                self?.open(AboutViewController())
            }
        ]

        for (index, row) in rows.enumerated() {
            menuStack.addArrangedSubview(row)
            if index < rows.count - 1 {
                let seam = SeamView(color: Palette.stroke.withAlphaComponent(0.5))
                menuStack.addArrangedSubview(seam.gutterPadded(30))
            }
        }
    }

    private func makeRow(symbol: String, title: String, detail: String, accent: UIColor,
                         action: @escaping () -> Void) -> MenuRowView {
        let row = MenuRowView(symbol: symbol, title: title, detail: detail, accent: accent)
        row.onTap = action
        return row
    }

    private func buildDangerCard() {
        dangerCard.subviews.forEach { $0.removeFromSuperview() }

        let logOut = PillButton("Log Out", symbol: "rectangle.portrait.and.arrow.right", style: .ghost, height: 50)
        logOut.onTap = { [weak self] in self?.confirmLogOut() }

        let delete = PillButton("Delete Account", symbol: "trash.fill", style: .danger, height: 50)
        delete.onTap = { [weak self] in self?.confirmDelete() }

        let note = UILabel()
        note.text = "Deleting your account removes your profile, posts, comments, conversations and training log. This cannot be undone."
        note.font = .dancte(11.5, .medium)
        note.textColor = Palette.textFaint
        note.numberOfLines = 0

        let column = UIStackView(arrangedSubviews: [logOut, delete, note])
        column.axis = .vertical
        column.spacing = 10
        column.setCustomSpacing(16, after: delete)

        dangerCard.addSubviews(column)
        NSLayoutConstraint.activate([
            column.leadingAnchor.constraint(equalTo: dangerCard.leadingAnchor, constant: 16),
            column.trailingAnchor.constraint(equalTo: dangerCard.trailingAnchor, constant: -16),
            column.topAnchor.constraint(equalTo: dangerCard.topAnchor, constant: 16),
            column.bottomAnchor.constraint(equalTo: dangerCard.bottomAnchor, constant: -18)
        ])
    }

    // MARK: - State

    @objc private func reload() {
        let signedIn = store.isSignedIn
        signedOutState.isHidden = signedIn
        signedInStack.isHidden = !signedIn
        guard signedIn, let user = store.currentUser else { return }

        avatar.configure(user: user)
        nameLabel.text = user.displayName
        verifiedIcon.isHidden = !user.isVerified
        handleLabel.text = "@\(user.handle) · \(user.city)"
        bioLabel.text = user.bio
        metaLabel.text = "\(user.crew) · Joined \(user.joinedAt.monthLabel)"
        styleFlow.apply(tags: user.styles.map(\.title), selected: [])
        buildStats()
        buildMenu()
    }

    private func open(_ controller: UIViewController) {
        navigationController?.pushViewController(controller, animated: true)
    }

    @objc private func openEditProfile() {
        open(EditProfileViewController())
    }

    /// The training log is a first-level tab, so this hands over to it rather
    /// than pushing a second copy on top of the profile stack.
    private func openStudio() {
        dancteTabs?.selectTab(1)
    }

    // MARK: - Destructive actions

    private func confirmLogOut() {
        confirm(title: "Log out of Dancte?",
                message: "Your log and library stay on this device — you can sign back in any time.",
                confirmTitle: "Log Out",
                destructive: false) { [weak self] in
            guard let self else { return }
            self.runLoadingBeat("Signing out") {
                store.signOut()
                Haptics.success()
                Toast.show("Signed out")
                self.reload()
            }
        }
    }

    private func confirmDelete() {
        confirm(title: "Delete your account?",
                message: "This permanently removes your profile, your posts, your comments, your conversations and your entire training log. This cannot be undone.",
                confirmTitle: "Delete Account") { [weak self] in
            guard let self else { return }
            self.runLoadingBeat("Deleting account") {
                store.deleteAccount()
                Haptics.warning()
                Toast.show("Account deleted", kind: .warning, detail: "Everything you posted has been removed.")
                self.reload()
            }
        }
    }
}
