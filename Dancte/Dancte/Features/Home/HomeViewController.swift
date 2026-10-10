import UIKit

extension UIViewController {
    var dancteTabs: MainTabBarController? {
        var current: UIViewController? = self
        while let node = current {
            if let tabs = node as? MainTabBarController { return tabs }
            current = node.parent
        }
        return nil
    }
}

// MARK: - Today strip

/// A single-line summary of the training log that sits under the greeting. It
/// is the front door to the module the whole app is built around — tapping it
/// switches to the Studio tab rather than pushing a screen.
final class TodayTrainingStrip: RowControl {

    var onOpenStudio: (() -> Void)?
    var onStart: (() -> Void)?

    private let iconTile = UIView()
    private let icon = UIImageView()
    private let headline = UILabel()
    private let caption = UILabel()
    private let actionButton = PillButton("Start", symbol: "play.fill", style: .primary, height: 40)

    override init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false

        let shell = SurfaceCard(colors: [UIColor(hex: 0x1D2330), UIColor(hex: 0x111520)],
                                radius: 26,
                                border: Palette.lime.withAlphaComponent(0.26),
                                glow: Palette.lime)
        addSubviews(shell)
        shell.pinEdges(to: self)

        iconTile.backgroundColor = Palette.lime.withAlphaComponent(0.16)
        iconTile.layer.cornerRadius = 14
        iconTile.layer.cornerCurve = .continuous
        icon.image = UIImage(systemName: "flame.fill", withConfiguration:
                                UIImage.SymbolConfiguration(pointSize: 19, weight: .bold))
        icon.tintColor = Palette.lime
        icon.contentMode = .center
        iconTile.addSubviews(icon)
        NSLayoutConstraint.activate([
            icon.centerXAnchor.constraint(equalTo: iconTile.centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: iconTile.centerYAnchor)
        ])

        headline.font = .dancte(19, .black)
        headline.textColor = Palette.text
        caption.font = Typo.caption
        caption.textColor = Palette.textMuted
        caption.numberOfLines = 2
        caption.adjustsFontSizeToFitWidth = true
        caption.minimumScaleFactor = 0.75

        let text = UIStackView(arrangedSubviews: [headline, caption])
        text.axis = .vertical
        text.spacing = 1
        text.isUserInteractionEnabled = false

        actionButton.onTap = { [weak self] in self?.onStart?() }
        actionButton.setContentHuggingPriority(.required, for: .horizontal)

        shell.addSubviews(iconTile, text, actionButton)
        NSLayoutConstraint.activate([
            iconTile.leadingAnchor.constraint(equalTo: shell.leadingAnchor, constant: 16),
            iconTile.centerYAnchor.constraint(equalTo: shell.centerYAnchor),
            iconTile.widthAnchor.constraint(equalToConstant: 42),
            iconTile.heightAnchor.constraint(equalToConstant: 42),

            text.leadingAnchor.constraint(equalTo: iconTile.trailingAnchor, constant: 12),
            text.centerYAnchor.constraint(equalTo: shell.centerYAnchor),
            text.trailingAnchor.constraint(lessThanOrEqualTo: actionButton.leadingAnchor, constant: -10),

            actionButton.trailingAnchor.constraint(equalTo: shell.trailingAnchor, constant: -16),
            actionButton.centerYAnchor.constraint(equalTo: shell.centerYAnchor),
            actionButton.widthAnchor.constraint(equalToConstant: 104),

            shell.topAnchor.constraint(equalTo: topAnchor),
            shell.bottomAnchor.constraint(equalTo: bottomAnchor),
            shell.heightAnchor.constraint(greaterThanOrEqualToConstant: 74)
        ])

        addAction(UIAction { [weak self] _ in
            Haptics.tap()
            self?.onOpenStudio?()
        }, for: .touchUpInside)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func refresh() {
        let stats = store.stats
        if store.isSignedIn {
            headline.text = stats.currentStreak > 0 ? "Day \(stats.currentStreak)" : "No streak yet"
            if stats.loggedToday {
                caption.text = "Logged today · \(Format.minutes(stats.minutesToday)) · \(Format.minutes(stats.minutesThisWeek)) this week"
            } else if stats.totalSessions == 0 {
                caption.text = "Log your first session and the streak starts today."
            } else {
                caption.text = "Nothing logged today · \(Format.minutes(stats.minutesThisWeek)) this week"
            }
            actionButton.title = "Start"
            actionButton.setSymbol("play.fill")
        } else {
            headline.text = "Train on purpose"
            caption.text = "Sessions, plans and streaks."
            actionButton.title = "Open"
            actionButton.setSymbol("arrow.right")
        }
    }

    override var isHighlighted: Bool {
        didSet {
            UIView.animate(withDuration: 0.12) {
                self.transform = self.isHighlighted ? CGAffineTransform(scaleX: 0.985, y: 0.985) : .identity
            }
        }
    }
}

// MARK: - Quick tool tile

final class QuickToolTile: RowControl {

    var onTap: (() -> Void)?

    private let iconTile = UIView()
    private let icon = UIImageView()
    private let titleLabel = UILabel()
    private let detailLabel = UILabel()

    init(symbol: String, title: String, detail: String, colors: [UIColor]) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = Palette.surfaceHi.withAlphaComponent(0.55)
        layer.cornerRadius = 22
        layer.cornerCurve = .continuous
        layer.borderWidth = 1
        layer.borderColor = Palette.stroke.withAlphaComponent(0.8).cgColor

        iconTile.backgroundColor = colors.first?.withAlphaComponent(0.18)
        iconTile.layer.cornerRadius = 14
        iconTile.layer.cornerCurve = .continuous
        iconTile.translatesAutoresizingMaskIntoConstraints = false
        icon.image = UIImage(systemName: symbol, withConfiguration:
                                UIImage.SymbolConfiguration(pointSize: 17, weight: .bold))
        icon.tintColor = colors.first
        icon.contentMode = .center
        iconTile.addSubviews(icon)

        titleLabel.text = title
        titleLabel.font = .dancte(14, .bold)
        titleLabel.textColor = Palette.text
        detailLabel.text = detail
        detailLabel.font = .dancte(10.5, .medium)
        detailLabel.textColor = Palette.textFaint

        let text = UIStackView(arrangedSubviews: [titleLabel, detailLabel])
        text.axis = .vertical
        text.spacing = 1
        text.translatesAutoresizingMaskIntoConstraints = false

        addSubviews(iconTile, text)
        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 76),
            iconTile.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            iconTile.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconTile.widthAnchor.constraint(equalToConstant: 38),
            iconTile.heightAnchor.constraint(equalToConstant: 38),
            icon.centerXAnchor.constraint(equalTo: iconTile.centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: iconTile.centerYAnchor),
            text.leadingAnchor.constraint(equalTo: iconTile.trailingAnchor, constant: 10),
            text.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            text.centerYAnchor.constraint(equalTo: centerYAnchor)
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
                self.transform = self.isHighlighted ? CGAffineTransform(scaleX: 0.96, y: 0.96) : .identity
            }
        }
    }
}

// MARK: - Home

/// The wall the app opens on: the spotlight tutorials first, then a preview of
/// the community feed underneath them — the newest posts only — filtered by tag
/// or by the dancers you follow, with pull to refresh.
final class HomeViewController: UIViewController, OwnsNavigationBar {

    var prefersOwnHeader: Bool { true }

    private enum Filter: Equatable {
        case all
        case following
        case tag(String)
    }

    private let scroll = ContentColumn(spacing: 24, gutter: 0)
    private let refreshControl = UIRefreshControl()

    private let greetingLabel = UILabel()
    private let nameLabel = UILabel()
    private let statusChip = ChipView(text: "", symbol: "flame.fill", accent: Palette.blaze)
    private let signInButton = PillButton("Sign In", style: .primary, height: 38)

    private let todayStrip = TodayTrainingStrip()
    private let mosaic = UIView()
    private let tagScroller = UIScrollView()
    private let tagStack = UIStackView(axis: .horizontal, spacing: 8)
    private let searchField = SearchField(placeholder: "Search posts, tags or dancers")
    private let countLabel = UILabel()
    private let feedStack = UIStackView(axis: .vertical, spacing: 14)
    private let footerContainer = UIView()
    private let footerLabel = UILabel()
    private let spinner = UIActivityIndicatorView(style: .medium)
    private let communityEmpty = EmptyStateView(symbol: "square.grid.2x2",
                                                title: "Nothing here yet",
                                                message: "When dancers post about this tag, their work shows up right here.",
                                                compact: true)

    private var spotlightCards: [SpotlightCard] = []
    private var communityCards: [PostCardView] = []
    private var communityAnchor: UIView?

    private var filter: Filter = .all
    private var query: String = ""
    private var matchCount = 0

    /// The wall previews the newest posts only — the rest of the archive stays
    /// out of the home feed.
    private static let feedLimit = 6

    private static let bottomInset = MainTabBarController.contentBottomInset + 24

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Palette.ink

        let backdrop = StudioBackdropView()
        view.addSubviews(backdrop)
        backdrop.pinEdges(to: view)

        scroll.installRefreshControl(refreshControl)
        refreshControl.tintColor = Palette.lime
        refreshControl.addTarget(self, action: #selector(handleRefresh), for: .valueChanged)
        scroll.setTopPadding(8)
        scroll.setBottomPadding(Self.bottomInset)

        view.addSubviews(scroll)
        NSLayoutConstraint.activate([
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scroll.topAnchor.constraint(equalTo: view.topAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        buildHeader()
        buildToday()
        buildQuickTools()
        buildSpotlight()
        buildCommunity()

        NotificationCenter.default.addObserver(self, selector: #selector(reloadAll),
                                               name: .dancteAuth, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(reloadAll),
                                               name: .dancteFeed, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(reloadAll),
                                               name: .dancteRelations, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(reloadAll),
                                               name: .danctePractice, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleOpenTag(_:)),
                                               name: .dancteOpenTag, object: nil)
        reloadAll()
    }

    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

    // MARK: - Sections

    private func buildHeader() {
        let mark = BrandMarkView(size: 44)
        let wordmark = UILabel()
        wordmark.attributedText = NSAttributedString(string: "DANCTE", attributes: [
            .kern: 3.4, .font: UIFont.dancte(17, .black), .foregroundColor: Palette.text
        ])
        let tagline = UILabel()
        tagline.attributedText = NSAttributedString(string: "TRAIN · POST · CONNECT", attributes: [
            .kern: 1.4, .font: UIFont.dancte(8.5, .bold), .foregroundColor: Palette.textFaint
        ])
        let brandText = UIStackView(arrangedSubviews: [wordmark, tagline])
        brandText.axis = .vertical
        brandText.spacing = 1

        let brandRow = UIStackView(arrangedSubviews: [mark, brandText, UIView(), statusChip, signInButton])
        brandRow.axis = .horizontal
        brandRow.spacing = 10
        brandRow.alignment = .center

        statusChip.onTap = { [weak self] in self?.openStudio() }
        signInButton.onTap = { [weak self] in self?.promptSignIn() }

        greetingLabel.font = Typo.caption
        greetingLabel.textColor = Palette.textMuted

        nameLabel.font = .dancte(34, .black)
        nameLabel.textColor = Palette.text
        nameLabel.numberOfLines = 2

        let header = UIStackView(arrangedSubviews: [brandRow, greetingLabel, nameLabel])
        header.axis = .vertical
        header.spacing = 6
        header.setCustomSpacing(20, after: brandRow)
        scroll.add(header.gutterPadded())
    }

    private func buildToday() {
        todayStrip.onOpenStudio = { [weak self] in self?.openStudio() }
        todayStrip.onStart = { [weak self] in self?.startTraining() }
        scroll.add(todayStrip.gutterPadded())
    }

    private func buildQuickTools() {
        let header = SectionHeader(eyebrow: "Shortcuts", title: "Quick tools")
        scroll.add(header.gutterPadded())

        let container = UIView()

        let tiles: [(String, String, String, [UIColor], () -> Void)] = [
            ("plus.circle.fill", "Log Session", "Record today", Grad.blaze, { [weak self] in self?.presentLogEditor() }),
            ("flame.fill", "Studio", "Plans & streak", Grad.lime, { [weak self] in self?.openStudio() }),
            ("list.bullet.rectangle.fill", "Skill Tree", "Track moves", Grad.violet, { [weak self] in self?.openSkillTree() }),
            ("person.2.fill", "Your Crew", "Friends only", Grad.cyan, { [weak self] in self?.dancteTabs?.selectTab(2) })
        ]

        var previous: QuickToolTile?
        for (symbol, title, detail, colors, action) in tiles {
            let tile = QuickToolTile(symbol: symbol, title: title, detail: detail, colors: colors)
            tile.onTap = action
            container.addSubviews(tile)
            NSLayoutConstraint.activate([
                tile.topAnchor.constraint(equalTo: container.topAnchor),
                tile.bottomAnchor.constraint(equalTo: container.bottomAnchor),
                tile.widthAnchor.constraint(equalToConstant: 168)
            ])
            if let previous {
                tile.leadingAnchor.constraint(equalTo: previous.trailingAnchor, constant: 10).isActive = true
            } else {
                tile.leadingAnchor.constraint(equalTo: container.leadingAnchor).isActive = true
            }
            previous = tile
        }
        previous?.trailingAnchor.constraint(equalTo: container.trailingAnchor).isActive = true

        let scroller = UIScrollView()
        scroller.translatesAutoresizingMaskIntoConstraints = false
        scroller.showsHorizontalScrollIndicator = false
        scroller.contentInset = UIEdgeInsets(top: 0, left: Metric.gutter, bottom: 0, right: Metric.gutter)
        scroller.addSubviews(container)
        NSLayoutConstraint.activate([
            container.leadingAnchor.constraint(equalTo: scroller.contentLayoutGuide.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: scroller.contentLayoutGuide.trailingAnchor),
            container.topAnchor.constraint(equalTo: scroller.contentLayoutGuide.topAnchor),
            container.bottomAnchor.constraint(equalTo: scroller.contentLayoutGuide.bottomAnchor),
            container.heightAnchor.constraint(equalTo: scroller.frameLayoutGuide.heightAnchor),
            scroller.heightAnchor.constraint(equalToConstant: 76)
        ])
        // Full-bleed: the tile strip runs edge to edge behind the gutter.
        scroll.add(scroller)
    }

    private func buildSpotlight() {
        let header = SectionHeader(eyebrow: "Featured this week", title: "Spotlight",
                                   actionTitle: "\(store.spotlight.count) clips")
        header.onAction = { [weak self] in
            guard let self, let first = store.spotlight.first else { return }
            self.presentFullPlayer(first)
        }
        scroll.add(header.gutterPadded())

        scroll.add(mosaic.gutterPadded())
        rebuildSpotlight()
    }

    private func rebuildSpotlight() {
        mosaic.subviews.forEach { $0.removeFromSuperview() }
        spotlightCards.removeAll()

        let videos = store.spotlight
        guard videos.count >= 5 else { return }

        let treatments: [SpotlightCard.Treatment] = [.hero, .tall, .tall, .wide, .reel]
        var cards: [SpotlightCard] = []
        for (index, video) in videos.prefix(5).enumerated() {
            let card = SpotlightCard(video: video, treatment: treatments[index], index: index)
            card.onOpenFull = { [weak self] clip in self?.presentFullPlayer(clip) }
            mosaic.addSubviews(card)
            cards.append(card)
        }
        spotlightCards = cards

        let hero = cards[0], tallA = cards[1], tallB = cards[2], wide = cards[3], reel = cards[4]

        NSLayoutConstraint.activate([
            hero.leadingAnchor.constraint(equalTo: mosaic.leadingAnchor),
            hero.trailingAnchor.constraint(equalTo: mosaic.trailingAnchor),
            hero.topAnchor.constraint(equalTo: mosaic.topAnchor),

            tallA.leadingAnchor.constraint(equalTo: mosaic.leadingAnchor),
            tallA.topAnchor.constraint(equalTo: hero.bottomAnchor, constant: 14),
            tallA.widthAnchor.constraint(equalTo: mosaic.widthAnchor, multiplier: 0.5, constant: -7),

            tallB.leadingAnchor.constraint(equalTo: tallA.trailingAnchor, constant: 14),
            tallB.widthAnchor.constraint(equalTo: tallA.widthAnchor),
            tallB.topAnchor.constraint(equalTo: tallA.topAnchor, constant: 34),

            wide.leadingAnchor.constraint(equalTo: mosaic.leadingAnchor),
            wide.trailingAnchor.constraint(equalTo: mosaic.trailingAnchor),
            wide.topAnchor.constraint(equalTo: tallB.bottomAnchor, constant: 16),

            reel.leadingAnchor.constraint(equalTo: mosaic.leadingAnchor),
            reel.trailingAnchor.constraint(equalTo: mosaic.trailingAnchor),
            reel.topAnchor.constraint(equalTo: wide.bottomAnchor, constant: 14),
            reel.bottomAnchor.constraint(equalTo: mosaic.bottomAnchor)
        ])
    }

    // MARK: - Community

    private func buildCommunity() {
        let header = SectionHeader(eyebrow: "Fresh from the floor", title: "Community")
        scroll.add(header.gutterPadded())

        searchField.onChange = { [weak self] text in
            guard let self else { return }
            self.query = text.trimmed.lowercased()
            self.reload()
        }

        countLabel.font = Typo.caption
        countLabel.textColor = Palette.textMuted

        tagStack.translatesAutoresizingMaskIntoConstraints = false
        tagScroller.translatesAutoresizingMaskIntoConstraints = false
        tagScroller.showsHorizontalScrollIndicator = false
        tagScroller.contentInset = UIEdgeInsets(top: 0, left: Metric.gutter, bottom: 0, right: Metric.gutter)
        tagScroller.addSubviews(tagStack)

        NSLayoutConstraint.activate([
            tagStack.leadingAnchor.constraint(equalTo: tagScroller.contentLayoutGuide.leadingAnchor),
            tagStack.trailingAnchor.constraint(equalTo: tagScroller.contentLayoutGuide.trailingAnchor),
            tagStack.topAnchor.constraint(equalTo: tagScroller.contentLayoutGuide.topAnchor),
            tagStack.bottomAnchor.constraint(equalTo: tagScroller.contentLayoutGuide.bottomAnchor),
            tagStack.heightAnchor.constraint(equalTo: tagScroller.frameLayoutGuide.heightAnchor),
            tagScroller.heightAnchor.constraint(equalToConstant: 40)
        ])

        let filters = searchField.gutterPadded()
        communityAnchor = filters

        scroll.add(filters)
        scroll.add(tagScroller)
        scroll.add(countLabel.gutterPadded())
        scroll.add(feedStack.gutterPadded())
        buildFooter()

        rebuildFilters()
    }

    private func rebuildFilters() {
        tagStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        var options: [(Filter, String, UIColor)] = [(.all, "All Posts", Palette.lime)]
        if store.isSignedIn {
            options.append((.following, "Following", Palette.cyan))
        }
        let counts = Dictionary(grouping: store.posts.flatMap(\.tags), by: { $0 })
        for tag in counts.sorted(by: { $0.value.count > $1.value.count }).prefix(8).map(\.key) {
            options.append((.tag(tag), "#\(tag)", Palette.accent(abs(tag.hashValue) % 6)))
        }

        for (option, label, accent) in options {
            let chip = ChipView(text: label, accent: accent)
            chip.isOn = option == filter
            chip.onTap = { [weak self] in
                guard let self else { return }
                self.filter = option
                self.rebuildFilters()
                self.reload()
            }
            tagStack.addArrangedSubview(chip)
        }
    }

    private func buildFooter() {
        footerLabel.font = Typo.caption
        footerLabel.textColor = Palette.textFaint
        footerLabel.textAlignment = .center
        footerLabel.numberOfLines = 0

        spinner.color = Palette.lime
        spinner.hidesWhenStopped = true
        spinner.translatesAutoresizingMaskIntoConstraints = false

        let column = UIStackView(arrangedSubviews: [spinner, footerLabel])
        column.axis = .vertical
        column.spacing = 10
        column.alignment = .center
        footerContainer.addSubviews(column)
        NSLayoutConstraint.activate([
            column.leadingAnchor.constraint(equalTo: footerContainer.leadingAnchor, constant: Metric.gutter),
            column.trailingAnchor.constraint(equalTo: footerContainer.trailingAnchor, constant: -Metric.gutter),
            column.topAnchor.constraint(equalTo: footerContainer.topAnchor, constant: 10),
            column.bottomAnchor.constraint(equalTo: footerContainer.bottomAnchor, constant: -10)
        ])
        scroll.add(footerContainer)
    }

    private var filtered: [Post] {
        var posts = store.feedPosts
        switch filter {
        case .all:
            break
        case .following:
            let ids = store.following
            posts = posts.filter { ids.contains($0.authorID) || $0.authorID == store.currentUserID }
        case let .tag(value):
            posts = posts.filter { $0.tags.contains { $0.caseInsensitiveCompare(value) == .orderedSame } }
        }
        guard !query.isEmpty else { return posts }
        return posts.filter { post in
            post.text.lowercased().contains(query)
                || post.tags.contains { $0.lowercased().contains(query) }
                || store.authorName(of: post.authorID).lowercased().contains(query)
                || store.authorHandle(of: post.authorID).lowercased().contains(query)
        }
    }

    private func reload() {
        let posts = filtered
        matchCount = posts.count
        let visible = Array(posts.prefix(Self.feedLimit))

        communityCards.forEach { $0.removeFromSuperview() }
        communityCards.removeAll()
        feedStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        countLabel.text = posts.isEmpty
            ? "No posts match this filter yet"
            : posts.count > Self.feedLimit
                ? "Newest \(Self.feedLimit) of \(posts.count) posts from the floor"
                : "\(posts.count) post\(posts.count == 1 ? "" : "s") from the floor"

        if visible.isEmpty {
            feedStack.addArrangedSubview(communityEmpty)
            communityEmpty.heightAnchor.constraint(equalToConstant: 280).isActive = true
            footerLabel.text = nil
            spinner.stopAnimating()
            return
        }

        for post in visible {
            let card = PostCardView()
            card.configure(with: post)
            wire(card, postID: post.id)
            feedStack.addArrangedSubview(card)
            communityCards.append(card)
        }

        updateFooter()
    }

    private func updateFooter() {
        footerLabel.text = matchCount <= Self.feedLimit
            ? "You're all caught up."
            : "That's the newest \(Self.feedLimit) — \(matchCount) posts in total."
        spinner.stopAnimating()
    }

    private func wire(_ card: PostCardView, postID: String) {
        card.onOpenPost = { [weak self] in self?.openPost(postID) }
        card.onOpenAuthor = { [weak self] in self?.openAuthor(postID) }
        card.onLike = { [weak self] in self?.toggleLike(postID) }
        card.onComment = { [weak self] in self?.openPost(postID, focusComments: true) }
        card.onSave = { [weak self] in self?.toggleSave(postID) }
        card.onMore = { [weak self] in self?.presentReport(forPost: postID) }
        card.onOpenMedia = { [weak self] index in self?.openMedia(postID, index: index) }
        card.onOpenTag = { [weak self] tag in self?.focusTag(tag) }
    }

    // MARK: - Actions

    @objc private func handleRefresh() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            guard let self else { return }
            self.reloadAll()
            self.refreshControl.endRefreshing()
        }
    }

    @objc private func reloadAll() {
        let hour = Calendar.current.component(.hour, from: Date())
        greetingLabel.text = hour < 12 ? "Good morning" : (hour < 18 ? "Good afternoon" : "Good evening")
        nameLabel.text = store.isSignedIn
            ? "\(store.currentUser?.displayName ?? "Dancer")."
            : "Find your floor."

        let stats = store.stats
        statusChip.isHidden = !store.isSignedIn
        signInButton.isHidden = store.isSignedIn
        if store.isSignedIn {
            statusChip.setText(stats.currentStreak > 0 ? "\(stats.currentStreak) day streak" : "No streak yet")
        }

        todayStrip.refresh()
        rebuildSpotlight()
        rebuildFilters()
        reload()
    }

    /// Jumps the wall to its community section, optionally filtered on a tag.
    @objc private func handleOpenTag(_ note: Notification) {
        if let tag = note.object as? String {
            filter = .tag(tag)
        }
        rebuildFilters()
        reload()

        view.layoutIfNeeded()
        revealSelectedFilter()
        guard let anchor = communityAnchor else { return }
        let target = anchor.convert(CGPoint.zero, to: scroll).y + scroll.contentOffset.y
        scroll.setContentOffset(CGPoint(x: 0, y: max(0, target - 12)), animated: true)
    }

    /// The chip row is wider than the screen, so a tag filter applied from a
    /// post has to be scrolled into sight or it looks like nothing happened.
    private func revealSelectedFilter() {
        guard let chip = tagStack.arrangedSubviews.first(where: { ($0 as? ChipView)?.isOn == true }) else { return }
        let rect = chip.convert(chip.bounds, to: tagScroller).insetBy(dx: -Metric.gutter, dy: -8)
        tagScroller.scrollRectToVisible(rect, animated: true)
    }

    private func focusTag(_ tag: String) {
        let clean = tag.hasPrefix("#") ? String(tag.dropFirst()) : tag
        handleOpenTag(Notification(name: .dancteOpenTag, object: clean))
    }

    private func promptSignIn() {
        AuthGate.require(.general, from: self) { [weak self] in self?.reloadAll() }
    }

    /// Switches to the Studio tab, optionally landing on one of its screens.
    private func openStudio(pushing controller: UIViewController? = nil) {
        AuthGate.require(.studio, from: self) { [weak self] in
            guard let self else { return }
            self.dancteTabs?.selectTab(1)
            guard let controller else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                self.dancteTabs?.push(controller)
            }
        }
    }

    private func openSkillTree() {
        openStudio(pushing: SkillTreeViewController())
    }

    private func startTraining() {
        AuthGate.require(.studio, from: self) { [weak self] in
            self?.presentSheet(PracticeLiveViewController())
        }
    }

    private func presentLogEditor() {
        AuthGate.require(.studio, from: self) { [weak self] in
            self?.presentSheet(PracticeLogEditorViewController(session: nil))
        }
    }

    private func presentFullPlayer(_ video: DanceVideo) {
        spotlightCards.forEach { $0.stop() }
        let player = ClipPlayerViewController(video: video)
        // A clip can be reported from the full-screen player; there is no
        // account to block behind the platform's own footage.
        player.onReport = { [weak self] in
            guard let self else { return }
            self.presentSheet(ReportViewController(target: .video(video.id)))
        }
        present(player, animated: true)
    }

    private func openPost(_ postID: String, focusComments: Bool = false) {
        navigationController?.pushViewController(PostDetailViewController(postID: postID, focusComments: focusComments), animated: true)
    }

    private func openAuthor(_ postID: String) {
        guard let post = store.post(postID) else { return }
        navigationController?.pushViewController(UserProfileViewController(userID: post.authorID), animated: true)
    }

    private func toggleLike(_ postID: String) {
        AuthGate.require(.like, from: self) { [weak self] in
            store.toggleLike(postID)
            Haptics.success()
            _ = self
        }
    }

    private func toggleSave(_ postID: String) {
        AuthGate.require(.like, from: self) { [weak self] in
            store.toggleSave(postID)
            Toast.success(store.isSaved(postID) ? "Saved to your collection" : "Removed from saved")
            _ = self
        }
    }

    private func openMedia(_ postID: String, index: Int) {
        guard let post = store.post(postID) else { return }
        present(MediaViewerViewController(media: post.media, startIndex: index, title: store.authorName(of: post.authorID)),
                animated: true)
    }

    private func presentReport(forPost postID: String) {
        guard let post = store.post(postID) else { return }
        let isMine = store.isMine(post)
        if isMine {
            confirm(title: "Delete this post?",
                    message: "This removes the post and its comments from your profile. It cannot be undone.",
                    confirmTitle: "Delete Post") {
                store.deletePost(postID)
                Toast.success("Post deleted")
            }
        } else {
            let report = ReportViewController(target: .post(postID))
            presentSheet(report)
        }
    }
}
