import UIKit

/// Third-level profile. Reachable from a post author's avatar and from the
/// header of a conversation, and the only place a connection is started.
final class UserProfileViewController: UIViewController, OwnsNavigationBar {

    var prefersOwnHeader: Bool { true }

    private let userID: String
    private let scroll = ContentColumn(spacing: 18, gutter: 0)
    private let postsStack = UIStackView(axis: .vertical, spacing: 14)
    private let backButton = IconButton(symbol: "arrow.left", size: 40, background: .glass, pointSize: 15)
    private let reportButton = IconButton(symbol: "flag", size: 40, background: .glass, tint: Palette.textMuted, pointSize: 15)
    private let navBar = UIView()

    private let avatar = RingedAvatarView(size: 96)
    private let nameLabel = UILabel()
    private let handleLabel = UILabel()
    private let bioLabel = UILabel()
    private let metaLabel = UILabel()
    private let styleFlow = TagFlowView(accent: Palette.lime)
    private let statsRow = UIStackView(axis: .horizontal, spacing: 10)
    private let actionRow = UIStackView(axis: .vertical, spacing: 10)
    private let postsHeader = SectionHeader(eyebrow: "Their work", title: "Posts")
    private let verifiedIcon = UIImageView(image: UIImage(systemName: "checkmark.seal.fill",
                                                          withConfiguration: UIImage.SymbolConfiguration(pointSize: 15, weight: .bold)))

    init(userID: String) {
        self.userID = userID
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Palette.ink

        let backdrop = StudioBackdropView()
        view.addSubviews(backdrop)
        backdrop.pinEdges(to: view)

        buildNav()

        scroll.setTopPadding(12)
        scroll.setBottomPadding(70)
        view.addSubviews(scroll)
        NSLayoutConstraint.activate([
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scroll.topAnchor.constraint(equalTo: navBar.bottomAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        scroll.add(makeHero().gutterPadded())
        scroll.add(actionRow.gutterPadded())
        scroll.add(postsHeader.gutterPadded())
        scroll.add(postsStack.gutterPadded())

        NotificationCenter.default.addObserver(self, selector: #selector(reload), name: .dancteRelations, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(reload), name: .dancteFeed, object: nil)
        reload()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

    private func buildNav() {
        navBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubviews(navBar)
        navBar.addSubviews(backButton, reportButton)
        NSLayoutConstraint.activate([
            navBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            navBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            navBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            navBar.heightAnchor.constraint(equalToConstant: 52),
            backButton.leadingAnchor.constraint(equalTo: navBar.leadingAnchor, constant: Metric.gutter),
            backButton.bottomAnchor.constraint(equalTo: navBar.bottomAnchor, constant: -4),
            reportButton.trailingAnchor.constraint(equalTo: navBar.trailingAnchor, constant: -Metric.gutter),
            reportButton.bottomAnchor.constraint(equalTo: backButton.bottomAnchor)
        ])
        backButton.onTap = { [weak self] in self?.navigationController?.popViewController(animated: true) }
        reportButton.onTap = { [weak self] in self?.presentReport() }
    }

    private func makeHero() -> UIView {
        let card = SurfaceCard(colors: [UIColor(hex: 0x1C2230), UIColor(hex: 0x101319)],
                               radius: 30, border: Palette.strokeHi.withAlphaComponent(0.5))

        nameLabel.font = .dancte(24, .black)
        nameLabel.textColor = Palette.text

        handleLabel.font = .dancte(13, .semibold)
        handleLabel.textColor = Palette.textFaint

        verifiedIcon.tintColor = Palette.cyan

        let nameRow = UIStackView(arrangedSubviews: [nameLabel, verifiedIcon, UIView()])
        nameRow.axis = .horizontal
        nameRow.spacing = 5
        nameRow.alignment = .center

        let text = UIStackView(arrangedSubviews: [nameRow, handleLabel])
        text.axis = .vertical
        text.spacing = 2

        let topRow = UIStackView(arrangedSubviews: [avatar, text])
        topRow.axis = .horizontal
        topRow.spacing = 16
        topRow.alignment = .center
        avatar.setContentHuggingPriority(.required, for: .horizontal)

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
        return card
    }

    // MARK: - Render

    @objc private func reload() {
        guard let user = store.user(userID) else {
            // The account was removed by a report.
            navigationController?.popToRootViewController(animated: true)
            return
        }

        avatar.configure(user: user)
        avatar.setRingColors(user.styles.first?.gradient ?? Grad.lime)
        nameLabel.text = user.displayName
        handleLabel.text = "@\(user.handle)"
        bioLabel.text = user.bio
        metaLabel.text = "\(user.city) · \(user.crew) · Joined \(user.joinedAt.monthLabel)"
        styleFlow.apply(tags: user.styles.map(\.title), selected: [])
        verifiedIcon.isHidden = !user.isVerified

        buildStats(for: user)
        buildActions(for: user)
        buildPosts(for: user)
    }

    private func buildStats(for user: User) {
        statsRow.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let posts = store.posts(by: user.id).count
        let stats: [(String, String, UIColor)] = [
            (Format.compact(posts), "Posts", Palette.lime),
            (Format.compact(user.followerCount), "Followers", Palette.cyan),
            (Format.compact(user.followingCount), "Following", Palette.violet)
        ]
        for (value, caption, accent) in stats {
            statsRow.addArrangedSubview(StatTile(value: value, caption: caption, accent: accent, compact: true))
        }
    }

    private func buildActions(for user: User) {
        actionRow.arrangedSubviews.forEach { $0.removeFromSuperview() }
        guard user.id != store.currentUserID else {
            let note = UILabel()
            note.text = "This is you."
            note.font = Typo.caption
            note.textColor = Palette.textFaint
            note.textAlignment = .center
            actionRow.addArrangedSubview(note)
            return
        }

        let isFollowing = store.isFollowing(user.id)
        let isFriend = store.isFriend(user.id)

        let follow = PillButton(isFollowing ? "Following" : "Follow",
                                symbol: isFollowing ? "checkmark" : "plus",
                                style: isFollowing ? .ghost : .primary, height: 50)
        follow.onTap = { [weak self, weak follow] in
            guard let self else { return }
            AuthGate.require(.like, from: self) {
                store.toggleFollow(user.id)
                let now = store.isFollowing(user.id)
                follow?.title = now ? "Following" : "Follow"
                follow?.setSymbol(now ? "checkmark" : "plus")
                follow?.setStyle(now ? .ghost : .primary)
                Toast.show(now ? "Following @\(user.handle)" : "Unfollowed @\(user.handle)")
                self.reload()
            }
        }
        actionRow.addArrangedSubview(follow)

        // The friend request button disappears the moment the two are friends.
        if !isFriend {
            let requested = store.hasOutgoingRequest(to: user.id)
            let incoming = store.hasIncomingRequest(from: user.id)
            let title = incoming ? "Accept Connection" : (requested ? "Request Sent" : "Send Friend Request")
            let request = PillButton(title, symbol: "person.badge.plus", style: .outline, height: 50)
            request.onTap = { [weak self] in
                guard let self else { return }
                AuthGate.require(.chat, from: self) {
                    if store.hasIncomingRequest(from: user.id) {
                        store.acceptFriendRequest(from: user.id)
                        Toast.success("You're connected", detail: "You can message each other now.")
                    } else if store.hasOutgoingRequest(to: user.id) {
                        store.cancelFriendRequest(to: user.id)
                        Toast.show("Request withdrawn")
                    } else {
                        store.sendFriendRequest(to: user.id)
                        store.toggleFollow(user.id)
                        Toast.success("Request sent", detail: "@\(user.handle) will see it in their messages.")
                    }
                    self.reload()
                }
            }
            actionRow.addArrangedSubview(request)
        } else {
            let message = PillButton("Message", symbol: "bubble.left.fill", style: .custom(colors: Grad.violet, foreground: .white), height: 50)
            message.onTap = { [weak self] in
                guard let self else { return }
                self.navigationController?.pushViewController(ChatDetailViewController(peerID: user.id), animated: true)
            }
            actionRow.addArrangedSubview(message)

            let connected = UILabel()
            connected.attributedText = NSAttributedString(string: "YOU'RE CONNECTED · MESSAGING OPEN", attributes: [
                .kern: 1.1, .font: UIFont.dancte(9.5, .bold), .foregroundColor: Palette.lime
            ])
            connected.textAlignment = .center
            actionRow.addArrangedSubview(connected)
        }
    }

    private func buildPosts(for user: User) {
        postsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let posts = store.posts(by: user.id)
        postsHeader.isHidden = posts.isEmpty
        guard !posts.isEmpty else { return }

        for post in posts {
            let card = PostCardView()
            card.configure(with: post)
            card.onOpenPost = { [weak self] in
                self?.navigationController?.pushViewController(PostDetailViewController(postID: post.id), animated: true)
            }
            card.onOpenAuthor = {}
            card.onLike = { [weak self] in
                guard let self else { return }
                AuthGate.require(.like, from: self) {
                    store.toggleLike(post.id)
                    Haptics.success()
                }
            }
            card.onComment = { [weak self] in
                self?.navigationController?.pushViewController(PostDetailViewController(postID: post.id, focusComments: true), animated: true)
            }
            card.onSave = { [weak self] in
                guard let self else { return }
                AuthGate.require(.like, from: self) {
                    store.toggleSave(post.id)
                    Toast.success(store.isSaved(post.id) ? "Saved" : "Removed from saved")
                }
            }
            card.onMore = { [weak self] in self?.presentReport() }
            card.onOpenMedia = { [weak self] index in
                self?.present(MediaViewerViewController(media: post.media, startIndex: index,
                                                        title: store.authorName(of: post.authorID)), animated: true)
            }
            card.onOpenTag = { _ in }
            postsStack.addArrangedSubview(card)
        }
    }

    // MARK: - Report

    private func presentReport() {
        guard userID != store.currentUserID else { return }
        let report = ReportViewController(target: .user(userID))
        report.onFinish = { [weak self] returnsToRoot in
            guard returnsToRoot else { return }
            // Reporting removes the account's content and returns to the
            // first-level screen the dancer came from.
            self?.navigationController?.popToRootViewController(animated: true)
        }
        presentSheet(report)
    }
}
