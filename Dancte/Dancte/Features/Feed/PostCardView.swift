import UIKit

// MARK: - Media tile

/// One image or clip inside a post, with the play affordance clips need.
final class MediaTileView: RowControl {

    var onOpen: (() -> Void)?

    private let artwork = ArtworkView(cornerRadius: 18)
    private let durationBadge: DurationBadge?
    private let playGlyph = UIImageView()
    private let counterLabel = UILabel()
    private let item: MediaItem

    init(item: MediaItem, showsCounter: Int? = nil) {
        self.item = item
        self.durationBadge = item.kind == .video
            ? DurationBadge(duration: VideoDuration.known(item.assetName) ?? item.duration)
            : nil
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        clipsToBounds = false

        artwork.setMediaArtwork(item)
        artwork.showsScrim = item.kind == .video
        artwork.roundCorners(18)
        addSubviews(artwork)
        artwork.pinEdges(to: self)
        artwork.isUserInteractionEnabled = false

        if let durationBadge {
            addSubviews(durationBadge)
            NSLayoutConstraint.activate([
                durationBadge.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
                durationBadge.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8)
            ])
            // The badge wears the clip's real running time, not the estimate.
            VideoDuration.resolve(item.assetName) { [weak durationBadge] seconds in
                durationBadge?.setDuration(seconds)
            }
        }

        if let showsCounter {
            counterLabel.text = "+\(showsCounter)"
            counterLabel.font = .dancte(20, .black)
            counterLabel.textColor = .white
            counterLabel.textAlignment = .center
            let veil = UIView()
            veil.backgroundColor = UIColor.black.withAlphaComponent(0.55)
            veil.translatesAutoresizingMaskIntoConstraints = false
            veil.isUserInteractionEnabled = false
            addSubviews(veil, counterLabel)
            veil.pinEdges(to: self)
            NSLayoutConstraint.activate([
                counterLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
                counterLabel.centerYAnchor.constraint(equalTo: centerYAnchor)
            ])
        }

        if item.kind == .video {
            playGlyph.image = UIImage(systemName: "play.fill", withConfiguration:
                                        UIImage.SymbolConfiguration(pointSize: 22, weight: .bold))
            playGlyph.tintColor = Palette.ink
            playGlyph.contentMode = .center
            playGlyph.backgroundColor = Palette.lime.withAlphaComponent(0.94)
            playGlyph.layer.cornerRadius = 26
            playGlyph.clipsToBounds = true
            playGlyph.translatesAutoresizingMaskIntoConstraints = false
            playGlyph.isUserInteractionEnabled = false
            addSubviews(playGlyph)
            NSLayoutConstraint.activate([
                playGlyph.centerXAnchor.constraint(equalTo: centerXAnchor),
                playGlyph.centerYAnchor.constraint(equalTo: centerYAnchor),
                playGlyph.widthAnchor.constraint(equalToConstant: 52),
                playGlyph.heightAnchor.constraint(equalToConstant: 52)
            ])
        }

        addAction(UIAction { [weak self] _ in
            Haptics.tap()
            self?.onOpen?()
        }, for: .touchUpInside)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

// MARK: - Media grid

/// Lays out a post's media the way a dancer would pin it on a wall: a single
/// clip or photo runs full bleed, pairs sit side by side, and larger sets fall
/// into a tight grid.
final class MediaGridView: UIView {

    var onOpen: ((Int) -> Void)?

    private var tiles: [MediaTileView] = []

    init(media: [MediaItem], maxVisible: Int = 6) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        guard !media.isEmpty else { return }

        let visible = Array(media.prefix(maxVisible))
        let overflow = media.count - visible.count

        switch visible.count {
        case 1:
            let tile = makeTile(visible[0], index: 0)
            addSubviews(tile)
            let aspect = min(max(visible[0].aspect, 0.66), 1.5)
            NSLayoutConstraint.activate([
                tile.leadingAnchor.constraint(equalTo: leadingAnchor),
                tile.trailingAnchor.constraint(equalTo: trailingAnchor),
                tile.topAnchor.constraint(equalTo: topAnchor),
                tile.bottomAnchor.constraint(equalTo: bottomAnchor),
                tile.heightAnchor.constraint(equalTo: tile.widthAnchor, multiplier: 1 / aspect)
            ])
        case 2:
            let row = UIStackView(axis: .horizontal, spacing: 8, distribution: .fillEqually)
            addSubviews(row)
            row.pinEdges(to: self)
            for (index, item) in visible.enumerated() {
                let tile = makeTile(item, index: index)
                row.addArrangedSubview(tile)
                tile.heightAnchor.constraint(equalTo: tile.widthAnchor, multiplier: 1.24).isActive = true
            }
        case 3:
            let left = makeTile(visible[0], index: 0)
            let rightColumn = UIStackView(axis: .vertical, spacing: 8, distribution: .fillEqually)
            let topRight = makeTile(visible[1], index: 1)
            let bottomRight = makeTile(visible[2], index: 2)
            rightColumn.addArrangedSubview(topRight)
            rightColumn.addArrangedSubview(bottomRight)

            let row = UIStackView(axis: .horizontal, spacing: 8, distribution: .fillEqually)
            row.addArrangedSubview(left)
            row.addArrangedSubview(rightColumn)
            addSubviews(row)
            row.pinEdges(to: self)
            left.heightAnchor.constraint(equalTo: left.widthAnchor, multiplier: 1.42).isActive = true
        default:
            let columns = 3
            let rows = Int(ceil(Double(visible.count) / Double(columns)))
            let grid = UIStackView(axis: .vertical, spacing: 8, distribution: .fillEqually)
            addSubviews(grid)
            grid.pinEdges(to: self)
            var cursor = 0
            for _ in 0..<rows {
                let row = UIStackView(axis: .horizontal, spacing: 8, distribution: .fillEqually)
                for _ in 0..<columns {
                    if cursor < visible.count {
                        let isLast = cursor == visible.count - 1
                        let tile = makeTile(visible[cursor], index: cursor,
                                            counter: isLast && overflow > 0 ? overflow : nil)
                        row.addArrangedSubview(tile)
                    } else {
                        row.addArrangedSubview(UIView())
                    }
                    cursor += 1
                }
                grid.addArrangedSubview(row)
            }
            if let first = tiles.first {
                first.heightAnchor.constraint(equalTo: first.widthAnchor, multiplier: 1).isActive = true
            }
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func makeTile(_ item: MediaItem, index: Int, counter: Int? = nil) -> MediaTileView {
        let tile = MediaTileView(item: item, showsCounter: counter)
        tile.onOpen = { [weak self] in self?.onOpen?(index) }
        tiles.append(tile)
        return tile
    }
}

// MARK: - Action button

/// The like / comment / save control used on cards and detail screens.
final class PostActionButton: UIControl {

    var onTap: (() -> Void)?

    private let icon = UIImageView()
    private let label = UILabel()
    private let stack = UIStackView(axis: .horizontal, spacing: 6, alignment: .center)
    private var baseSymbol: String
    private var accent: UIColor

    init(symbol: String, count: Int? = nil, accent: UIColor = Palette.textMuted, pointSize: CGFloat = 17) {
        self.baseSymbol = symbol
        self.accent = accent
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        icon.contentMode = .center
        icon.setContentHuggingPriority(.required, for: .horizontal)
        label.font = .dancteMono(13, .semibold)
        label.textColor = Palette.textMuted
        label.isHidden = count == nil
        if let count { label.text = Format.compact(count) }

        stack.addArrangedSubview(icon)
        stack.addArrangedSubview(label)
        stack.isUserInteractionEnabled = false
        addSubviews(stack)
        stack.pinEdges(to: self, insets: UIEdgeInsets(top: 6, left: 0, bottom: 6, right: 0))

        setSymbol(symbol, pointSize: pointSize)
        addAction(UIAction { [weak self] _ in
            Haptics.tap()
            self?.onTap?()
        }, for: .touchUpInside)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func setSymbol(_ symbol: String, pointSize: CGFloat = 17) {
        baseSymbol = symbol
        icon.image = UIImage(systemName: symbol, withConfiguration:
                                UIImage.SymbolConfiguration(pointSize: pointSize, weight: .semibold))
        icon.tintColor = Palette.textMuted
    }

    func setCount(_ count: Int?) {
        label.isHidden = count == nil
        label.text = count.map { Format.compact($0) }
    }

    func setActive(_ active: Bool, symbol: String? = nil, accent: UIColor? = nil) {
        let color = active ? (accent ?? self.accent) : Palette.textMuted
        let name = active ? (symbol ?? baseSymbol) : baseSymbol
        icon.image = UIImage(systemName: name, withConfiguration:
                                UIImage.SymbolConfiguration(pointSize: 17, weight: .semibold))
        icon.tintColor = color
        label.textColor = color
    }

    override var isHighlighted: Bool {
        didSet {
            UIView.animate(withDuration: 0.12) {
                self.transform = self.isHighlighted ? CGAffineTransform(scaleX: 0.92, y: 0.92) : .identity
            }
        }
    }
}

// MARK: - Post card

final class PostCardView: UIView {

    var onOpenPost: (() -> Void)?
    var onOpenAuthor: (() -> Void)?
    var onLike: (() -> Void)?
    var onComment: (() -> Void)?
    var onSave: (() -> Void)?
    var onMore: (() -> Void)?
    var onOpenMedia: ((Int) -> Void)?
    var onOpenTag: ((String) -> Void)?

    private let card = SurfaceCard(colors: Grad.card, radius: Metric.cardRadius, border: Palette.stroke.withAlphaComponent(0.8))
    private let avatar = RingedAvatarView(size: 46)
    private let nameLabel = UILabel()
    private let metaLabel = UILabel()
    private let verifiedIcon = UIImageView()
    private let styleChip = ChipView(text: "", accent: Palette.lime, horizontalPadding: 11, fontSize: 11)
    private let moreButton = IconButton(symbol: "ellipsis", size: 34, background: .clear, tint: Palette.textMuted, pointSize: 15)
    private let bodyLabel = UILabel()
    private let tagFlow = TagFlowView()
    private let likeButton = PostActionButton(symbol: "heart", count: 0, accent: Palette.magenta)
    private let commentButton = PostActionButton(symbol: "bubble.left", count: 0, accent: Palette.cyan)
    private let saveButton = PostActionButton(symbol: "bookmark", count: nil, accent: Palette.lime)
    private var mediaGrid: MediaGridView?
    private var mediaContainer = UIView()

    private var post: Post?
    private var isExpanded = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
        addSubviews(card)
        card.pinEdges(to: self)

        let content = UIStackView(axis: .vertical, spacing: 14)
        card.addSubviews(content)
        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            content.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            content.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            content.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -12)
        ])

        content.addArrangedSubview(makeHeader())
        content.addArrangedSubview(bodyLabel)
        content.addArrangedSubview(mediaContainer)
        content.addArrangedSubview(tagFlow)
        content.addArrangedSubview(makeFooter())
        content.setCustomSpacing(8, after: bodyLabel)
        content.setCustomSpacing(8, after: mediaContainer)

        bodyLabel.font = Typo.body
        bodyLabel.textColor = Palette.text
        bodyLabel.numberOfLines = 4
        bodyLabel.isUserInteractionEnabled = true
        bodyLabel.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(toggleExpanded)))

        tagFlow.onToggle = { [weak self] tag in self?.onOpenTag?(tag) }

        let cardTap = UITapGestureRecognizer(target: self, action: #selector(openPost))
        // Only the card's own chrome opens the detail screen; the like, comment,
        // save and more buttons inside it handle their own taps.
        cardTap.delegate = ControlExemptTapDelegate.exclusive
        card.addGestureRecognizer(cardTap)

        likeButton.onTap = { [weak self] in self?.onLike?() }
        commentButton.onTap = { [weak self] in self?.onComment?() }
        saveButton.onTap = { [weak self] in self?.onSave?() }
        moreButton.onTap = { [weak self] in self?.onMore?() }

        NotificationCenter.default.addObserver(self, selector: #selector(refreshFromStore),
                                               name: .dancteFeed, object: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    deinit { NotificationCenter.default.removeObserver(self) }

    // MARK: - Build

    private func makeHeader() -> UIView {
        nameLabel.font = .dancte(15.5, .bold)
        nameLabel.textColor = Palette.text
        verifiedIcon.image = UIImage(systemName: "checkmark.seal.fill", withConfiguration:
                                        UIImage.SymbolConfiguration(pointSize: 12, weight: .bold))
        verifiedIcon.tintColor = Palette.cyan
        verifiedIcon.setContentHuggingPriority(.required, for: .horizontal)

        let nameRow = UIStackView(arrangedSubviews: [nameLabel, verifiedIcon])
        nameRow.axis = .horizontal
        nameRow.spacing = 4
        nameRow.alignment = .center

        metaLabel.font = Typo.caption
        metaLabel.textColor = Palette.textFaint

        let text = UIStackView(arrangedSubviews: [nameRow, metaLabel])
        text.axis = .vertical
        text.spacing = 1

        let column = UIStackView(arrangedSubviews: [avatar, text])
        column.axis = .vertical
        column.spacing = 0

        avatar.setContentHuggingPriority(.required, for: .horizontal)
        avatar.isUserInteractionEnabled = true
        avatar.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(openAuthor)))

        let row = UIStackView(arrangedSubviews: [avatar, text, styleChip, moreButton])
        row.axis = .horizontal
        row.spacing = 10
        row.alignment = .center
        styleChip.setContentHuggingPriority(.required, for: .horizontal)
        moreButton.setContentHuggingPriority(.required, for: .horizontal)
        _ = column
        return row
    }

    private func makeFooter() -> UIView {
        // Reporting lives on the header's ellipsis, so the footer carries the
        // three actions a post actually has: like, comment and save.
        let row = UIStackView(arrangedSubviews: [likeButton, commentButton, saveButton, UIView()])
        row.axis = .horizontal
        row.spacing = 18
        row.alignment = .center
        row.translatesAutoresizingMaskIntoConstraints = false
        return row
    }

    // MARK: - Configure

    func configure(with post: Post) {
        self.post = post
        let author = store.user(post.authorID)
        avatar.configure(user: author)
        nameLabel.text = author?.displayName ?? "Dancte Dancer"
        verifiedIcon.isHidden = !(author?.isVerified ?? false)
        metaLabel.text = "@\(store.authorHandle(of: post.authorID)) · \(post.createdAt.shortRelative)"
        styleChip.isHidden = post.style == nil
        if let style = post.style {
            styleChip.setText(style.title)
        }
        bodyLabel.text = post.text
        bodyLabel.numberOfLines = isExpanded ? 0 : 4
        tagFlow.isHidden = post.tags.isEmpty
        tagFlow.apply(tags: post.tags.map { "#\($0)" }, selected: [])
        rebuildMedia(with: post)
        refreshFromStore()
    }

    private func rebuildMedia(with post: Post) {
        mediaGrid?.removeFromSuperview()
        mediaContainer.subviews.forEach { $0.removeFromSuperview() }
        mediaContainer.isHidden = post.media.isEmpty
        guard !post.media.isEmpty else {
            mediaContainer.heightAnchor.constraint(equalToConstant: 0).isActive = true
            return
        }
        let grid = MediaGridView(media: post.media)
        grid.onOpen = { [weak self] index in self?.onOpenMedia?(index) }
        mediaContainer.addSubviews(grid)
        grid.pinEdges(to: mediaContainer)
        mediaGrid = grid
    }

    @objc private func refreshFromStore() {
        guard let post, let fresh = store.post(post.id) else { return }
        self.post = fresh
        likeButton.setCount(fresh.likeCount)
        likeButton.setActive(store.isLiked(fresh.id), symbol: "heart.fill", accent: Palette.magenta)
        commentButton.setCount(store.commentCount(for: fresh.id))
        saveButton.setActive(store.isSaved(fresh.id), symbol: "bookmark.fill", accent: Palette.lime)
    }

    // MARK: - Actions

    @objc private func toggleExpanded() {
        isExpanded.toggle()
        bodyLabel.numberOfLines = isExpanded ? 0 : 4
        UIView.animate(withDuration: 0.2) { self.layoutIfNeeded() }
    }

    @objc private func openPost() { onOpenPost?() }
    @objc private func openAuthor() { onOpenAuthor?() }
}
