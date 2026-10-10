import UIKit

// MARK: - Conversation row

final class ConversationRow: RowControl {

    var onTap: (() -> Void)?

    private let avatar = RingedAvatarView(size: 56)
    private let nameLabel = UILabel()
    private let previewLabel = UILabel()
    private let timeLabel = UILabel()
    private let badge = CountBadge(count: 0, color: Palette.lime)
    private let badgeContainer = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = Palette.surfaceHi.withAlphaComponent(0.5)
        layer.cornerRadius = 22
        layer.cornerCurve = .continuous
        layer.borderWidth = 1
        layer.borderColor = Palette.stroke.withAlphaComponent(0.7).cgColor

        nameLabel.font = .dancte(16, .bold)
        nameLabel.textColor = Palette.text

        previewLabel.font = Typo.caption
        previewLabel.textColor = Palette.textMuted
        previewLabel.numberOfLines = 1

        timeLabel.font = .dancteMono(11, .semibold)
        timeLabel.textColor = Palette.textFaint
        timeLabel.textAlignment = .right
        timeLabel.setContentHuggingPriority(.required, for: .horizontal)

        badgeContainer.translatesAutoresizingMaskIntoConstraints = false
        badge.translatesAutoresizingMaskIntoConstraints = false
        badgeContainer.addSubviews(badge)

        let nameRow = UIStackView(arrangedSubviews: [nameLabel, UIView(), timeLabel])
        nameRow.axis = .horizontal
        nameRow.spacing = 8

        let text = UIStackView(arrangedSubviews: [nameRow, previewLabel])
        text.axis = .vertical
        text.spacing = 3

        addSubviews(avatar, text, badgeContainer)
        NSLayoutConstraint.activate([
            avatar.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            avatar.centerYAnchor.constraint(equalTo: centerYAnchor),

            text.leadingAnchor.constraint(equalTo: avatar.trailingAnchor, constant: 12),
            text.trailingAnchor.constraint(equalTo: badgeContainer.leadingAnchor, constant: -10),
            text.topAnchor.constraint(equalTo: topAnchor, constant: 14),
            text.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -14),

            badgeContainer.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            badgeContainer.centerYAnchor.constraint(equalTo: centerYAnchor),
            badgeContainer.widthAnchor.constraint(greaterThanOrEqualToConstant: 0),
            badge.leadingAnchor.constraint(equalTo: badgeContainer.leadingAnchor),
            badge.trailingAnchor.constraint(equalTo: badgeContainer.trailingAnchor),
            badge.topAnchor.constraint(equalTo: badgeContainer.topAnchor),
            badge.bottomAnchor.constraint(equalTo: badgeContainer.bottomAnchor)
        ])

        addAction(UIAction { [weak self] _ in
            Haptics.tap()
            self?.onTap?()
        }, for: .touchUpInside)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(conversation: Conversation) {
        let peer = store.user(conversation.peerID)
        avatar.configure(user: peer)
        nameLabel.text = peer?.displayName ?? "Dancte Dancer"

        if let last = conversation.lastMessage {
            switch last.kind {
            case .text:
                previewLabel.text = last.senderID == store.currentUserID ? "You: \(last.text)" : last.text
            case .gift:
                let giftName = store.gift(last.giftID)?.name ?? "Gift"
                previewLabel.text = last.senderID == store.currentUserID ? "You sent \(giftName)" : "Sent you \(giftName)"
            case .call:
                previewLabel.text = last.text
            }
            timeLabel.text = last.createdAt.shortRelative
        } else {
            previewLabel.text = "Say hello — you're connected."
            timeLabel.text = ""
        }

        let unread = conversation.unreadCount
        badgeContainer.isHidden = unread == 0
        badge.setCount(unread)
    }

    override var isHighlighted: Bool {
        didSet {
            UIView.animate(withDuration: 0.12) {
                self.transform = self.isHighlighted ? CGAffineTransform(scaleX: 0.985, y: 0.985) : .identity
            }
        }
    }
}

// MARK: - Suggested dancer card

final class SuggestedDancerCard: RowControl {

    var onPrimary: (() -> Void)?

    private let avatar = RingedAvatarView(size: 64)
    private let nameLabel = UILabel()
    private let handleLabel = UILabel()
    private let stylesLabel = UILabel()
    private let actionButton = PillButton("Follow", style: .ghost, height: 36)

    init(user: User) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = Palette.surfaceHi.withAlphaComponent(0.5)
        layer.cornerRadius = 24
        layer.cornerCurve = .continuous
        layer.borderWidth = 1
        layer.borderColor = Palette.stroke.withAlphaComponent(0.7).cgColor

        avatar.configure(user: user)
        avatar.setRingColors(user.styles.first?.gradient ?? Grad.lime)

        nameLabel.text = user.displayName
        nameLabel.font = .dancte(15, .bold)
        nameLabel.textColor = Palette.text
        nameLabel.numberOfLines = 1

        handleLabel.text = "@\(user.handle)"
        handleLabel.font = .dancte(11.5, .medium)
        handleLabel.textColor = Palette.textFaint

        stylesLabel.text = user.styles.map(\.title).joined(separator: " · ")
        stylesLabel.font = .dancte(11, .semibold)
        stylesLabel.textColor = user.styles.first?.accent ?? Palette.lime
        stylesLabel.numberOfLines = 1

        actionButton.title = store.isFollowing(user.id) ? "Following" : "Follow"
        actionButton.setStyle(store.isFollowing(user.id) ? .outline : .primary)
        actionButton.onTap = { [weak self] in self?.onPrimary?() }

        let column = UIStackView(arrangedSubviews: [avatar, nameLabel, handleLabel, stylesLabel, actionButton])
        column.axis = .vertical
        column.spacing = 4
        column.alignment = .center
        column.setCustomSpacing(10, after: avatar)
        column.setCustomSpacing(10, after: stylesLabel)
        column.translatesAutoresizingMaskIntoConstraints = false

        addSubviews(column)
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: 158),
            column.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            column.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            column.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            column.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16),
            actionButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            actionButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var isHighlighted: Bool {
        didSet {
            UIView.animate(withDuration: 0.12) {
                self.transform = self.isHighlighted ? CGAffineTransform(scaleX: 0.97, y: 0.97) : .identity
            }
        }
    }
}

// MARK: - Requests row

final class FriendRequestRow: UIView {

    var onAccept: (() -> Void)?
    var onDecline: (() -> Void)?

    private let avatar = RingedAvatarView(size: 48)
    private let nameLabel = UILabel()
    private let detailLabel = UILabel()

    init(user: User) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        avatar.configure(user: user)
        avatar.setRingColors(Grad.violet)

        nameLabel.text = user.displayName
        nameLabel.font = .dancte(15, .bold)
        nameLabel.textColor = Palette.text

        detailLabel.text = "@\(user.handle) wants to connect"
        detailLabel.font = Typo.caption
        detailLabel.textColor = Palette.textMuted

        let accept = IconButton(symbol: "checkmark", size: 38, background: .gradient(Grad.lime), pointSize: 14)
        let decline = IconButton(symbol: "xmark", size: 38, background: .glass, tint: Palette.textMuted, pointSize: 14)
        accept.onTap = { [weak self] in self?.onAccept?() }
        decline.onTap = { [weak self] in self?.onDecline?() }

        let text = UIStackView(arrangedSubviews: [nameLabel, detailLabel])
        text.axis = .vertical
        text.spacing = 2

        let row = UIStackView(arrangedSubviews: [avatar, text, UIView(), accept, decline])
        row.axis = .horizontal
        row.spacing = 10
        row.alignment = .center
        avatar.setContentHuggingPriority(.required, for: .horizontal)
        accept.setContentHuggingPriority(.required, for: .horizontal)
        decline.setContentHuggingPriority(.required, for: .horizontal)

        addSubviews(row)
        row.pinEdges(to: self)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

// MARK: - Chat list

final class ChatListViewController: UIViewController, OwnsNavigationBar {

    var prefersOwnHeader: Bool { true }

    private let scroll = ContentColumn(spacing: 20, gutter: 0)
    private let refreshControl = UIRefreshControl()
    private let conversationsStack = UIStackView(axis: .vertical, spacing: 10)
    private let requestsStack = UIStackView(axis: .vertical, spacing: 12)
    private let suggestedStrip = UIStackView(axis: .horizontal, spacing: 12)
    private let requestsSection = UIStackView(axis: .vertical, spacing: 12)
    private let conversationsSection = UIStackView(axis: .vertical, spacing: 12)
    private let suggestedScroller = UIScrollView()
    private var suggestedHeaderRow: UIView?
    private var signedOutWrapper: UIView?
    private let signedOutState = EmptyStateView(symbol: "bubble.left.and.bubble.right.fill",
                                                title: "Your messages live here",
                                                message: "Sign in to see the dancers you train with. Dancte only allows conversations between dancers who have both agreed to connect — never strangers.",
                                                actionTitle: "Sign In")
    private let signedInEmpty = EmptyStateView(symbol: "person.2.wave.2.fill",
                                               title: "No conversations yet",
                                               message: "Connect with a dancer below. Once they accept, your conversation opens right here.",
                                               compact: true)

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Palette.ink

        let backdrop = StudioBackdropView()
        view.addSubviews(backdrop)
        backdrop.pinEdges(to: view)

        scroll.installRefreshControl(refreshControl)
        refreshControl.tintColor = Palette.lime
        refreshControl.addTarget(self, action: #selector(handleRefresh), for: .valueChanged)
        scroll.setTopPadding(6)
        scroll.setBottomPadding(MainTabBarController.contentBottomInset + 24)
        view.addSubviews(scroll)
        scroll.pinEdges(to: view)

        buildHeader()

        signedOutState.onAction = { [weak self] in
            guard let self else { return }
            AuthGate.require(.chat, from: self) { self.reload() }
        }
        // The wrapper is what the stack lays out, so that is what gets hidden.
        let wrapper = signedOutState.gutterPadded()
        signedOutWrapper = wrapper
        scroll.add(wrapper)
        signedOutState.heightAnchor.constraint(equalToConstant: 400).isActive = true

        scroll.add(requestsSection.gutterPadded())
        scroll.add(conversationsSection.gutterPadded())
        signedInEmpty.heightAnchor.constraint(equalToConstant: 220).isActive = true

        signedInEmpty.onAction = { [weak self] in
            guard let self else { return }
            self.scroll.setContentOffset(CGPoint(x: 0, y: max(0, self.scroll.contentSize.height - self.scroll.bounds.height)), animated: true)
        }

        NotificationCenter.default.addObserver(self, selector: #selector(reload), name: .dancteChat, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(reload), name: .dancteAuth, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(reload), name: .dancteRelations, object: nil)
        reload()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reload()
    }

    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

    private func buildHeader() {
        let title = UILabel()
        title.text = "Messages"
        title.font = .dancte(34, .black)
        title.textColor = Palette.text

        let detail = UILabel()
        detail.text = "Conversations are limited to dancers who have both agreed to connect."
        detail.font = Typo.caption
        detail.textColor = Palette.textMuted
        detail.numberOfLines = 2

        let header = UIStackView(arrangedSubviews: [title, detail])
        header.axis = .vertical
        header.spacing = 6
        scroll.add(header.gutterPadded())
    }

    // MARK: - Render

    @objc private func reload() {
        let signedIn = store.isSignedIn
        signedOutWrapper?.isHidden = signedIn
        requestsSection.isHidden = !signedIn
        conversationsSection.isHidden = !signedIn
        guard signedIn else { return }

        rebuildRequests()
        rebuildConversations()
        rebuildSuggested()
    }

    private func rebuildRequests() {
        requestsSection.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let incoming = Array(store.incomingRequests).compactMap { store.user($0) }
        guard !incoming.isEmpty else {
            requestsSection.isHidden = true
            return
        }
        requestsSection.isHidden = false

        let header = SectionHeader(eyebrow: "Waiting on you", title: "Connection requests",
                                   actionTitle: "\(incoming.count)")
        requestsSection.addArrangedSubview(header)

        let card = SurfaceCard(colors: [Palette.violet.withAlphaComponent(0.14), Palette.surface],
                               radius: 24, border: Palette.violet.withAlphaComponent(0.35))
        let column = UIStackView(axis: .vertical, spacing: 16)
        card.addSubviews(column)
        NSLayoutConstraint.activate([
            column.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            column.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            column.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            column.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16)
        ])

        for user in incoming {
            let row = FriendRequestRow(user: user)
            row.onAccept = { [weak self] in
                store.acceptFriendRequest(from: user.id)
                Haptics.success()
                Toast.success("You're connected", detail: "@\(user.handle) can message you now.")
                self?.reload()
            }
            row.onDecline = { [weak self] in
                store.declineFriendRequest(from: user.id)
                Toast.show("Request declined")
                self?.reload()
            }
            column.addArrangedSubview(row)
        }
        requestsSection.addArrangedSubview(card)
    }

    private func rebuildConversations() {
        conversationsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        conversationsSection.arrangedSubviews.forEach { $0.removeFromSuperview() }

        let conversations = store.sortedConversations
        conversationsSection.addArrangedSubview(
            SectionHeader(eyebrow: "Your crew", title: "Conversations",
                          actionTitle: conversations.isEmpty ? nil : "\(conversations.count)"))

        if conversations.isEmpty {
            conversationsStack.addArrangedSubview(signedInEmpty)
        } else {
            for conversation in conversations {
                let row = ConversationRow()
                row.configure(conversation: conversation)
                row.onTap = { [weak self] in self?.openConversation(with: conversation.peerID) }
                conversationsStack.addArrangedSubview(row)
            }
        }
        conversationsSection.addArrangedSubview(conversationsStack)
    }

    private func rebuildSuggested() {
        suggestedHeaderRow?.removeFromSuperview()
        suggestedScroller.removeFromSuperview()
        suggestedStrip.arrangedSubviews.forEach { $0.removeFromSuperview() }
        suggestedHeaderRow = nil

        let dancers = Array(store.suggestedDancers.prefix(10))
        guard !dancers.isEmpty else { return }

        let header = SectionHeader(eyebrow: "Same styles, same city", title: "Dancers near your lane")
        let row = header.gutterPadded()
        suggestedHeaderRow = row
        scroll.add(row)

        suggestedStrip.translatesAutoresizingMaskIntoConstraints = false
        suggestedScroller.translatesAutoresizingMaskIntoConstraints = false
        suggestedScroller.showsHorizontalScrollIndicator = false
        suggestedScroller.contentInset = UIEdgeInsets(top: 0, left: Metric.gutter, bottom: 0, right: Metric.gutter)
        suggestedScroller.addSubviews(suggestedStrip)
        NSLayoutConstraint.activate([
            suggestedStrip.leadingAnchor.constraint(equalTo: suggestedScroller.contentLayoutGuide.leadingAnchor),
            suggestedStrip.trailingAnchor.constraint(equalTo: suggestedScroller.contentLayoutGuide.trailingAnchor),
            suggestedStrip.topAnchor.constraint(equalTo: suggestedScroller.contentLayoutGuide.topAnchor),
            suggestedStrip.bottomAnchor.constraint(equalTo: suggestedScroller.contentLayoutGuide.bottomAnchor),
            suggestedStrip.heightAnchor.constraint(equalTo: suggestedScroller.frameLayoutGuide.heightAnchor),
            suggestedScroller.heightAnchor.constraint(equalToConstant: 208)
        ])

        for dancer in dancers {
            let card = SuggestedDancerCard(user: dancer)
            card.onPrimary = { [weak self] in self?.toggleFollow(dancer) }
            let open = UITapGestureRecognizer(target: self, action: #selector(openProfile(_:)))
            // The card carries its own Follow button, so the card-wide tap has to
            // stand down whenever the touch belongs to that button.
            open.delegate = ControlExemptTapDelegate.exclusive
            card.addGestureRecognizer(open)
            card.tag = dancers.firstIndex(where: { $0.id == dancer.id }) ?? 0
            suggestedStrip.addArrangedSubview(card)
        }

        scroll.add(suggestedScroller)
        suggestedDancers = dancers
    }

    private var suggestedDancers: [User] = []

    @objc private func openProfile(_ recognizer: UITapGestureRecognizer) {
        guard let index = recognizer.view?.tag, let user = suggestedDancers[safe: index] else { return }
        navigationController?.pushViewController(UserProfileViewController(userID: user.id), animated: true)
    }

    private func toggleFollow(_ user: User) {
        AuthGate.require(.chat, from: self) { [weak self] in
            store.toggleFollow(user.id)
            if store.isFollowing(user.id) {
                store.sendFriendRequest(to: user.id)
                Toast.success("Request sent to @\(user.handle)")
            }
            self?.reload()
        }
    }

    private func openConversation(with peerID: String) {
        guard store.canChat(with: peerID) else {
            Toast.warning("You need to be connected first",
                          detail: "Send a request from their profile — conversations open once they accept.")
            return
        }
        navigationController?.pushViewController(ChatDetailViewController(peerID: peerID), animated: true)
    }

    @objc private func handleRefresh() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.reload()
            self?.refreshControl.endRefreshing()
        }
    }
}
