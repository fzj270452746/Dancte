import UIKit

// MARK: - Comment row

final class CommentRowView: UIView {

    var onMore: (() -> Void)?
    var onAuthor: (() -> Void)?

    private let avatar = RingedAvatarView(size: 38)
    private let nameLabel = UILabel()
    private let metaLabel = UILabel()
    private let bodyLabel = UILabel()
    private let moreButton = IconButton(symbol: "ellipsis", size: 30, background: .clear, tint: Palette.textFaint, pointSize: 13)
    private let authorBadge = ChipView(text: "Author", accent: Palette.lime, horizontalPadding: 8, fontSize: 9.5)

    override init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false

        nameLabel.font = .dancte(14.5, .bold)
        nameLabel.textColor = Palette.text
        metaLabel.font = .dancte(11.5, .medium)
        metaLabel.textColor = Palette.textFaint
        bodyLabel.font = Typo.body
        bodyLabel.textColor = Palette.textMuted
        bodyLabel.numberOfLines = 0

        authorBadge.isHidden = true
        authorBadge.setContentHuggingPriority(.required, for: .horizontal)

        let nameRow = UIStackView(arrangedSubviews: [nameLabel, authorBadge, UIView()])
        nameRow.axis = .horizontal
        nameRow.spacing = 6
        nameRow.alignment = .center

        let text = UIStackView(arrangedSubviews: [nameRow, metaLabel, bodyLabel])
        text.axis = .vertical
        text.spacing = 2
        text.setCustomSpacing(6, after: metaLabel)

        addSubviews(avatar, text, moreButton)
        avatar.setContentHuggingPriority(.required, for: .horizontal)
        moreButton.setContentHuggingPriority(.required, for: .horizontal)

        NSLayoutConstraint.activate([
            avatar.leadingAnchor.constraint(equalTo: leadingAnchor),
            avatar.topAnchor.constraint(equalTo: topAnchor, constant: 2),

            text.leadingAnchor.constraint(equalTo: avatar.trailingAnchor, constant: 11),
            text.trailingAnchor.constraint(equalTo: moreButton.leadingAnchor, constant: -6),
            text.topAnchor.constraint(equalTo: topAnchor),
            text.bottomAnchor.constraint(equalTo: bottomAnchor),

            moreButton.trailingAnchor.constraint(equalTo: trailingAnchor),
            moreButton.topAnchor.constraint(equalTo: topAnchor, constant: 2)
        ])

        moreButton.onTap = { [weak self] in self?.onMore?() }
        avatar.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapAuthor)))
        avatar.isUserInteractionEnabled = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(comment: Comment, isPostAuthor: Bool) {
        let user = store.user(comment.authorID)
        avatar.configure(user: user)
        nameLabel.text = user?.displayName ?? "Dancte Dancer"
        metaLabel.text = "@\(store.authorHandle(of: comment.authorID)) · \(comment.createdAt.shortRelative)"
        bodyLabel.text = comment.text
        authorBadge.isHidden = !isPostAuthor
    }

    @objc private func tapAuthor() { onAuthor?() }
}

// MARK: - Post detail

final class PostDetailViewController: UIViewController, OwnsNavigationBar {

    var prefersOwnHeader: Bool { true }

    private let postID: String
    private let focusComments: Bool

    private let scroll = ContentColumn(spacing: 18, gutter: 0)
    private let commentsStack = UIStackView(axis: .vertical, spacing: 18)
    private let inputBar = UIView()
    private let inputField = UITextField()
    private let sendButton = IconButton(symbol: "arrow.up", size: 40, background: .gradient(Grad.lime), pointSize: 15)
    private let inputAvatar = AvatarView(size: 34)
    private let backButton = IconButton(symbol: "arrow.left", size: 40, background: .glass, pointSize: 15)
    private let moreButton = IconButton(symbol: "ellipsis", size: 40, background: .glass, pointSize: 15)
    private let commentsHeader = UILabel()
    private let emptyComments = EmptyStateView(symbol: "bubble.left",
                                               title: "No comments yet",
                                               message: "Be the first to say something about this post.",
                                               compact: true)

    private var inputBottom: NSLayoutConstraint!
    private var renderToken = 0

    init(postID: String, focusComments: Bool = false) {
        self.postID = postID
        self.focusComments = focusComments
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
        buildInputBar()

        scroll.setTopPadding(10)
        scroll.setBottomPadding(30)
        scroll.keyboardDismissMode = .interactive
        view.addSubviews(scroll)
        NSLayoutConstraint.activate([
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scroll.topAnchor.constraint(equalTo: navBar.bottomAnchor),
            scroll.bottomAnchor.constraint(equalTo: inputBar.topAnchor)
        ])

        NotificationCenter.default.addObserver(self, selector: #selector(handleStoreChange),
                                               name: .dancteFeed, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleStoreChange),
                                               name: .dancteRelations, object: nil)

        render()
        observeKeyboard()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

    // MARK: - Chrome

    private let navBar = UIView()

    private func buildNav() {
        navBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubviews(navBar)
        NSLayoutConstraint.activate([
            navBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            navBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            navBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            navBar.heightAnchor.constraint(equalToConstant: 52)
        ])

        let label = UILabel()
        label.text = "Post"
        label.font = .dancte(17, .bold)
        label.textColor = Palette.text
        label.translatesAutoresizingMaskIntoConstraints = false

        navBar.addSubviews(backButton, moreButton, label)
        NSLayoutConstraint.activate([
            backButton.leadingAnchor.constraint(equalTo: navBar.leadingAnchor, constant: Metric.gutter),
            backButton.bottomAnchor.constraint(equalTo: navBar.bottomAnchor, constant: -4),
            moreButton.trailingAnchor.constraint(equalTo: navBar.trailingAnchor, constant: -Metric.gutter),
            moreButton.bottomAnchor.constraint(equalTo: backButton.bottomAnchor),
            label.centerXAnchor.constraint(equalTo: navBar.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: backButton.centerYAnchor)
        ])

        backButton.onTap = { [weak self] in self?.navigationController?.popViewController(animated: true) }
        moreButton.onTap = { [weak self] in self?.presentMore() }
    }

    private func buildInputBar() {
        inputBar.translatesAutoresizingMaskIntoConstraints = false
        inputBar.backgroundColor = UIColor(hex: 0x12141B).withAlphaComponent(0.94)
        inputBar.layer.borderWidth = 1
        inputBar.layer.borderColor = Palette.stroke.withAlphaComponent(0.7).cgColor
        view.addSubviews(inputBar)

        inputBottom = inputBar.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        NSLayoutConstraint.activate([
            inputBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            inputBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            inputBottom
        ])

        inputField.font = .dancte(15, .medium)
        inputField.textColor = Palette.text
        inputField.tintColor = Palette.lime
        inputField.attributedPlaceholder = NSAttributedString(string: "Add a comment…", attributes: [
            .foregroundColor: Palette.textFaint,
            .font: UIFont.dancte(15, .regular)
        ])
        inputField.translatesAutoresizingMaskIntoConstraints = false
        inputField.returnKeyType = .send
        inputField.delegate = self
        inputField.addTarget(self, action: #selector(inputChanged), for: .editingChanged)

        let fieldShell = UIView()
        fieldShell.backgroundColor = Palette.surfaceHi.withAlphaComponent(0.7)
        fieldShell.layer.cornerRadius = 19
        fieldShell.layer.cornerCurve = .continuous
        fieldShell.layer.borderWidth = 1
        fieldShell.layer.borderColor = Palette.stroke.cgColor
        fieldShell.translatesAutoresizingMaskIntoConstraints = false
        fieldShell.addSubviews(inputField)

        inputBar.addSubviews(inputAvatar, fieldShell, sendButton)
        NSLayoutConstraint.activate([
            inputAvatar.leadingAnchor.constraint(equalTo: inputBar.leadingAnchor, constant: Metric.gutter),
            inputAvatar.centerYAnchor.constraint(equalTo: inputBar.safeAreaLayoutGuide.bottomAnchor, constant: -33),
            inputBar.topAnchor.constraint(equalTo: inputAvatar.topAnchor, constant: -14),

            fieldShell.leadingAnchor.constraint(equalTo: inputAvatar.trailingAnchor, constant: 10),
            fieldShell.trailingAnchor.constraint(equalTo: sendButton.leadingAnchor, constant: -10),
            fieldShell.centerYAnchor.constraint(equalTo: inputAvatar.centerYAnchor),
            fieldShell.heightAnchor.constraint(equalToConstant: 40),

            inputField.leadingAnchor.constraint(equalTo: fieldShell.leadingAnchor, constant: 14),
            inputField.trailingAnchor.constraint(equalTo: fieldShell.trailingAnchor, constant: -12),
            inputField.centerYAnchor.constraint(equalTo: fieldShell.centerYAnchor),

            sendButton.trailingAnchor.constraint(equalTo: inputBar.trailingAnchor, constant: -Metric.gutter),
            sendButton.centerYAnchor.constraint(equalTo: inputAvatar.centerYAnchor)
        ])

        sendButton.onTap = { [weak self] in self?.submitComment() }
        sendButton.alpha = 0.45
        inputAvatar.isUserInteractionEnabled = true
        inputAvatar.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapSelf)))
    }

    // MARK: - Render

    private func render() {
        renderToken += 1
        let token = renderToken
        scroll.column.arrangedSubviews.forEach { $0.removeFromSuperview() }
        commentsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        guard let post = store.post(postID) else {
            // The post was reported and removed — nothing left to show.
            let gone = EmptyStateView(symbol: "eye.slash",
                                      title: "Post removed",
                                      message: "This post is no longer available.",
                                      actionTitle: "Go Back")
            gone.onAction = { [weak self] in
                self?.navigationController?.popViewController(animated: true)
            }
            scroll.add(gone.gutterPadded())
            gone.heightAnchor.constraint(equalToConstant: 380).isActive = true
            inputBar.isHidden = true
            return
        }
        inputBar.isHidden = false

        scroll.add(makeAuthorCard(post).gutterPadded())

        if !post.text.isBlank {
            let body = UILabel()
            body.text = post.text
            body.font = .dancte(16, .regular)
            body.textColor = Palette.text
            body.numberOfLines = 0
            scroll.add(body.gutterPadded())
        }

        if !post.media.isEmpty {
            let grid = MediaGridView(media: post.media)
            grid.onOpen = { [weak self] index in
                guard let self else { return }
                self.present(MediaViewerViewController(media: post.media, startIndex: index,
                                                       title: store.authorName(of: post.authorID)), animated: true)
            }
            scroll.add(grid.gutterPadded())
        }

        if !post.tags.isEmpty {
            let flow = TagFlowView(tags: post.tags.map { "#\($0)" }, selected: [], accent: post.style?.accent ?? Palette.lime)
            flow.onToggle = { [weak self] tag in
                let clean = tag.hasPrefix("#") ? String(tag.dropFirst()) : tag
                self?.dancteTabs?.focusCommunity(tag: clean)
            }
            scroll.add(flow.gutterPadded())
        }

        scroll.add(makeActionsRow(post).gutterPadded())

        let comments = store.comments(for: post.id)
        commentsHeader.attributedText = NSAttributedString(
            string: "COMMENTS",
            attributes: [.kern: 1.8, .font: UIFont.dancte(11, .black), .foregroundColor: Palette.textFaint]
        )
        let countLabel = UILabel()
        countLabel.text = "\(comments.count)"
        countLabel.font = .dancte(11, .black)
        countLabel.textColor = post.style?.accent ?? Palette.lime

        let header = UIStackView(arrangedSubviews: [commentsHeader, countLabel, UIView()])
        header.axis = .horizontal
        header.spacing = 8
        scroll.add(header.gutterPadded())

        if comments.isEmpty {
            commentsStack.addArrangedSubview(emptyComments)
            emptyComments.heightAnchor.constraint(equalToConstant: 200).isActive = true
        } else {
            for comment in comments {
                let row = CommentRowView()
                row.configure(comment: comment, isPostAuthor: comment.authorID == post.authorID)
                row.onMore = { [weak self] in self?.presentCommentActions(comment) }
                row.onAuthor = { [weak self] in
                    self?.navigationController?.pushViewController(
                        UserProfileViewController(userID: comment.authorID), animated: true)
                }
                commentsStack.addArrangedSubview(row)
            }
        }
        scroll.add(commentsStack.gutterPadded())

        inputAvatar.configure(user: store.currentUser)
        _ = token

        if focusComments, !comments.isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                self.scroll.setContentOffset(CGPoint(x: 0, y: max(0, self.scroll.contentSize.height - self.scroll.bounds.height)), animated: true)
            }
        }
    }

    private func makeAuthorCard(_ post: Post) -> UIView {
        let card = SurfaceCard(colors: Grad.card, radius: 24, border: Palette.stroke.withAlphaComponent(0.8))

        let avatar = RingedAvatarView(size: 52)
        avatar.configure(user: store.user(post.authorID))

        let name = UILabel()
        name.text = store.authorName(of: post.authorID)
        name.font = .dancte(17, .bold)
        name.textColor = Palette.text

        let meta = UILabel()
        meta.text = "@\(store.authorHandle(of: post.authorID)) · \(post.createdAt.shortRelative)"
        meta.font = Typo.caption
        meta.textColor = Palette.textFaint

        let verified = UIImageView(image: UIImage(systemName: "checkmark.seal.fill", withConfiguration:
                                                    UIImage.SymbolConfiguration(pointSize: 12, weight: .bold)))
        verified.tintColor = Palette.cyan
        verified.isHidden = !(store.user(post.authorID)?.isVerified ?? false)

        let nameRow = UIStackView(arrangedSubviews: [name, verified, UIView()])
        nameRow.axis = .horizontal
        nameRow.spacing = 4
        nameRow.alignment = .center

        let text = UIStackView(arrangedSubviews: [nameRow, meta])
        text.axis = .vertical
        text.spacing = 2

        let followButton = PillButton(store.isFollowing(post.authorID) ? "Following" : "Follow",
                                      style: store.isFollowing(post.authorID) ? .ghost : .primary, height: 38)
        followButton.onTap = { [weak self, weak followButton] in
            guard let self else { return }
            AuthGate.require(.like, from: self) {
                store.toggleFollow(post.authorID)
                let now = store.isFollowing(post.authorID)
                followButton?.title = now ? "Following" : "Follow"
                followButton?.setStyle(now ? .ghost : .primary)
            }
        }

        let row = UIStackView(arrangedSubviews: [avatar, text, followButton])
        row.axis = .horizontal
        row.spacing = 12
        row.alignment = .center
        avatar.setContentHuggingPriority(.required, for: .horizontal)
        followButton.setContentHuggingPriority(.required, for: .horizontal)

        card.addSubviews(row)
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            row.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            row.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            row.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16)
        ])

        row.isUserInteractionEnabled = true
        row.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(openPostAuthorTap)))
        return card
    }

    private func makeActionsRow(_ post: Post) -> UIView {
        let like = PostActionButton(symbol: "heart", count: post.likeCount, accent: Palette.magenta, pointSize: 19)
        like.setActive(store.isLiked(post.id), symbol: "heart.fill", accent: Palette.magenta)
        like.onTap = { [weak self] in
            guard let self else { return }
            AuthGate.require(.like, from: self) {
                store.toggleLike(post.id)
                Haptics.success()
            }
        }

        let comment = PostActionButton(symbol: "bubble.left", count: store.commentCount(for: post.id),
                                       accent: Palette.cyan, pointSize: 19)
        comment.onTap = { [weak self] in self?.inputField.becomeFirstResponder() }

        let save = PostActionButton(symbol: "bookmark", count: nil, accent: Palette.lime, pointSize: 19)
        save.setActive(store.isSaved(post.id), symbol: "bookmark.fill", accent: Palette.lime)
        save.onTap = { [weak self] in
            guard let self else { return }
            AuthGate.require(.like, from: self) {
                store.toggleSave(post.id)
                Toast.success(store.isSaved(post.id) ? "Saved to your collection" : "Removed from saved")
            }
        }

        let share = PostActionButton(symbol: "square.and.arrow.up", count: nil, accent: Palette.textMuted, pointSize: 19)
        share.onTap = { [weak self] in self?.share(post) }

        let row = UIStackView(arrangedSubviews: [like, comment, save, UIView(), share])
        row.axis = .horizontal
        row.spacing = 22
        row.alignment = .center

        let card = SurfaceCard(colors: [Palette.surfaceHi.withAlphaComponent(0.7), Palette.surface.withAlphaComponent(0.7)],
                               radius: 22, border: Palette.stroke.withAlphaComponent(0.7))
        card.addSubviews(row)
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 18),
            row.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -18),
            row.topAnchor.constraint(equalTo: card.topAnchor, constant: 12),
            row.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -12)
        ])
        return card
    }

    // MARK: - Actions

    @objc private func openPostAuthorTap() {
        guard let post = store.post(postID) else { return }
        navigationController?.pushViewController(UserProfileViewController(userID: post.authorID), animated: true)
    }

    @objc private func tapSelf() {
        AuthGate.require(.profile, from: self) {
            self.dancteTabs?.selectTab(3)
            self.navigationController?.popToRootViewController(animated: false)
        }
    }

    @objc private func handleStoreChange() {
        guard isViewLoaded, view.window != nil else { return }
        render()
    }

    @objc private func inputChanged() {
        let ready = !inputField.text!.trimmed.isEmpty
        UIView.animate(withDuration: 0.18) {
            self.sendButton.alpha = ready ? 1 : 0.45
        }
    }

    private func submitComment() {
        let text = inputField.text!.trimmed
        guard !text.isEmpty else { return }
        AuthGate.require(.comment, from: self) { [weak self] in
            guard let self else { return }
            store.addComment(to: self.postID, text: text)
            self.inputField.text = ""
            self.inputChanged()
            Haptics.success()
            self.render()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                let bottom = max(0, self.scroll.contentSize.height - self.scroll.bounds.height)
                self.scroll.setContentOffset(CGPoint(x: 0, y: bottom), animated: true)
            }
        }
    }

    private func presentMore() {
        guard let post = store.post(postID) else { return }
        if store.isMine(post) {
            confirm(title: "Delete this post?",
                    message: "This removes the post and its comments from your profile. It cannot be undone.",
                    confirmTitle: "Delete Post") { [weak self] in
                store.deletePost(post.id)
                Toast.success("Post deleted")
                self?.navigationController?.popViewController(animated: true)
            }
        } else {
            presentReport()
        }
    }

    private func presentReport() {
        let report = ReportViewController(target: .post(postID))
        report.onFinish = { [weak self] returnsToRoot in
            guard returnsToRoot else { return }
            self?.navigationController?.popToRootViewController(animated: true)
        }
        presentSheet(report)
    }

    private func presentCommentActions(_ comment: Comment) {
        guard let post = store.post(postID) else { return }
        let isMine = comment.authorID == store.currentUserID

        let sheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        if isMine {
            sheet.addAction(UIAlertAction(title: "Delete Comment", style: .destructive) { [weak self] _ in
                store.deleteComment(comment.id)
                Toast.success("Comment deleted")
                self?.render()
            })
        } else {
            let name = store.authorName(of: comment.authorID)
            sheet.addAction(UIAlertAction(title: "Report Comment", style: .destructive) { [weak self] _ in
                guard let self else { return }
                let report = ReportViewController(target: .comment(comment.id))
                report.onFinish = { _ in self.render() }
                self.presentSheet(report)
            })
            sheet.addAction(UIAlertAction(title: "Report @\(store.authorHandle(of: comment.authorID))", style: .destructive) { [weak self] _ in
                guard let self else { return }
                let report = ReportViewController(target: .user(comment.authorID))
                report.onFinish = { returnsToRoot in
                    if returnsToRoot { self.navigationController?.popToRootViewController(animated: true) }
                }
                self.presentSheet(report)
            })
            _ = name
        }
        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        if let popover = sheet.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 1, height: 1)
            popover.permittedArrowDirections = []
        }
        present(sheet, animated: true)
        _ = post
    }

    private func share(_ post: Post) {
        let text = "\(store.authorName(of: post.authorID)) on Dancte: \(post.text.truncated(120))"
        let activity = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        if let popover = activity.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 1, height: 1)
        }
        present(activity, animated: true)
    }

    // MARK: - Keyboard

    private func observeKeyboard() {
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardChanged(_:)),
                                               name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
    }

    @objc private func keyboardChanged(_ note: Notification) {
        guard let frame = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
        let overlap = max(0, view.bounds.maxY - view.convert(frame, from: nil).minY)
        let duration = note.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double ?? 0.25
        UIView.animate(withDuration: duration) {
            self.inputBottom.constant = -overlap
            self.view.layoutIfNeeded()
        }
        scroll.contentInset.bottom = overlap > 0 ? 16 : 0
    }
}

extension PostDetailViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        submitComment()
        return true
    }
}
