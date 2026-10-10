import PhotosUI
import UIKit

// MARK: - Shared page scaffolding

/// Any pushed list page: a scrollable column with a pull-to-refresh control,
/// an empty state and a fixed bottom inset.
class ListPageViewController: UIViewController {

    let scroll = ContentColumn(spacing: 14, gutter: 0)
    let refreshControl = UIRefreshControl()
    let contentStack = UIStackView(axis: .vertical, spacing: 14)

    private let emptyState: EmptyStateView?

    init(title: String,
         subtitle: String? = nil,
         emptySymbol: String = "square.grid.2x2",
         emptyTitle: String = "Nothing here yet",
         emptyMessage: String = "",
         emptyActionTitle: String? = nil,
         emptyAction: (() -> Void)? = nil) {
        if emptyMessage.isEmpty {
            emptyState = nil
        } else {
            emptyState = EmptyStateView(symbol: emptySymbol, title: emptyTitle,
                                        message: emptyMessage, actionTitle: emptyActionTitle,
                                        compact: true)
            emptyState?.onAction = emptyAction
        }
        super.init(nibName: nil, bundle: nil)
        styleNavigationBar(title: title, subtitle: subtitle)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Palette.ink
        installBrandBackButton()

        let backdrop = StudioBackdropView()
        view.addSubviews(backdrop)
        backdrop.pinEdges(to: view)

        scroll.installRefreshControl(refreshControl)
        refreshControl.tintColor = Palette.lime
        refreshControl.addTarget(self, action: #selector(handleRefresh), for: .valueChanged)
        scroll.setTopPadding(8)
        scroll.setBottomPadding(60)
        view.addSubviews(scroll)
        NSLayoutConstraint.activate([
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        scroll.add(contentStack.gutterPadded())
        contentStack.isHidden = true
        reload()
    }

    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

    @objc func handleRefresh() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.reload()
            self?.refreshControl.endRefreshing()
        }
    }

    @objc func reload() {
        contentStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
    }

    func showEmptyState() {
        guard let emptyState else { return }
        contentStack.isHidden = false
        contentStack.addArrangedSubview(emptyState)
        emptyState.heightAnchor.constraint(equalToConstant: 340).isActive = true
    }
}

// MARK: - Posts list

class PostCollectionViewController: ListPageViewController {

    enum Kind {
        case works, likes, saved

        var empty: (symbol: String, title: String, message: String) {
            switch self {
            case .works:
                return ("square.grid.2x2", "No posts yet",
                        "Publish a clip, a photo set or a practice update and it will live here.")
            case .likes:
                return ("heart", "Nothing liked yet",
                        "Tap the heart on any post and it lands in this collection.")
            case .saved:
                return ("bookmark", "Nothing saved yet",
                        "Save posts you want to come back to — drills, choreography, inspiration.")
            }
        }
    }

    private let kind: Kind

    init(kind: Kind) {
        self.kind = kind
        let empty = kind.empty
        super.init(title: PostCollectionViewController.pageTitle(for: kind),
                   subtitle: PostCollectionViewController.pageSubtitle(for: kind),
                   emptySymbol: empty.symbol,
                   emptyTitle: empty.title,
                   emptyMessage: empty.message)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private static func pageTitle(for kind: Kind) -> String {
        switch kind {
        case .works: return "My Works"
        case .likes: return "My Likes"
        case .saved: return "Saved"
        }
    }

    private static func pageSubtitle(for kind: Kind) -> String {
        switch kind {
        case .works: return "Everything you've published"
        case .likes: return "Tap the heart again to remove a like"
        case .saved: return "Your collection"
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        NotificationCenter.default.addObserver(self, selector: #selector(reload), name: .dancteFeed, object: nil)
    }

    private var posts: [Post] {
        switch kind {
        case .works: return store.myPosts
        case .likes: return store.likedPosts
        case .saved: return store.savedPosts
        }
    }

    override func reload() {
        super.reload()
        let items = posts
        guard !items.isEmpty else {
            showEmptyState()
            return
        }
        contentStack.isHidden = false

        let count = UILabel()
        count.text = "\(items.count) post\(items.count == 1 ? "" : "s")"
        count.font = Typo.caption
        count.textColor = Palette.textMuted
        contentStack.addArrangedSubview(count)

        for post in items {
            let card = PostCardView()
            card.configure(with: post)
            card.onOpenPost = { [weak self] in self?.openPost(post.id) }
            card.onOpenAuthor = { [weak self] in self?.openAuthor(post.authorID) }
            card.onLike = { [weak self] in
                guard let self else { return }
                AuthGate.require(.like, from: self) {
                    store.toggleLike(post.id)
                    Haptics.success()
                    if self.kind == .likes { Toast.show("Like removed") }
                }
            }
            card.onComment = { [weak self] in self?.openPost(post.id, focusComments: true) }
            card.onSave = {
                store.toggleSave(post.id)
                Toast.success(store.isSaved(post.id) ? "Saved" : "Removed from saved")
            }
            card.onMore = { [weak self] in self?.presentMore(post) }
            card.onOpenMedia = { [weak self] index in
                self?.present(MediaViewerViewController(media: post.media, startIndex: index,
                                                        title: store.authorName(of: post.authorID)), animated: true)
            }
            card.onOpenTag = { [weak self] tag in
                let clean = tag.hasPrefix("#") ? String(tag.dropFirst()) : tag
                self?.dancteTabs?.focusCommunity(tag: clean)
            }
            contentStack.addArrangedSubview(card)
        }
    }

    private func openPost(_ postID: String, focusComments: Bool = false) {
        navigationController?.pushViewController(PostDetailViewController(postID: postID, focusComments: focusComments), animated: true)
    }

    private func openAuthor(_ userID: String) {
        navigationController?.pushViewController(UserProfileViewController(userID: userID), animated: true)
    }

    private func presentMore(_ post: Post) {
        if store.isMine(post) {
            confirm(title: "Delete this post?",
                    message: "This removes the post and its comments. It cannot be undone.",
                    confirmTitle: "Delete Post") {
                store.deletePost(post.id)
                Toast.success("Post deleted")
            }
        } else {
            presentSheet(ReportViewController(target: .post(post.id)))
        }
    }
}

// MARK: - People list

class PeopleListViewController: ListPageViewController {

    private let users: [User]
    private let showsFollowButton: Bool

    init(title: String,
         subtitle: String?,
         users: [User],
         emptyMessage: String,
         showsFollowButton: Bool = true) {
        self.users = users
        self.showsFollowButton = showsFollowButton
        super.init(title: title, subtitle: subtitle,
                   emptySymbol: "person.2.fill",
                   emptyTitle: "Nobody here yet",
                   emptyMessage: emptyMessage)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        NotificationCenter.default.addObserver(self, selector: #selector(reload), name: .dancteRelations, object: nil)
    }

    override func reload() {
        super.reload()
        guard !users.isEmpty else {
            showEmptyState()
            return
        }
        contentStack.isHidden = false
        for user in users {
            contentStack.addArrangedSubview(makeRow(user))
        }
    }

    private func makeRow(_ user: User) -> UIView {
        let card = SurfaceCard(colors: Grad.card, radius: 22, border: Palette.stroke.withAlphaComponent(0.8))

        let avatar = RingedAvatarView(size: 52)
        avatar.configure(user: user)
        avatar.setRingColors(user.styles.first?.gradient ?? Grad.lime)

        let name = UILabel()
        name.text = user.displayName
        name.font = .dancte(16, .bold)
        name.textColor = Palette.text

        let detail = UILabel()
        detail.text = "@\(user.handle) · \(user.styles.map(\.title).joined(separator: ", "))"
        detail.font = Typo.caption
        detail.textColor = Palette.textFaint
        detail.numberOfLines = 1

        let text = UIStackView(arrangedSubviews: [name, detail])
        text.axis = .vertical
        text.spacing = 2

        let following = store.isFollowing(user.id)
        let button = PillButton(following ? "Unfollow" : "Follow",
                                style: following ? .outline : .primary, height: 38)
        button.onTap = { [weak self, weak button] in
            guard let self else { return }
            AuthGate.require(.like, from: self) {
                store.toggleFollow(user.id)
                let now = store.isFollowing(user.id)
                button?.title = now ? "Unfollow" : "Follow"
                button?.setStyle(now ? .outline : .primary)
                Toast.show(now ? "Following @\(user.handle)" : "Unfollowed @\(user.handle)")
            }
        }
        button.isHidden = !showsFollowButton
        button.setContentHuggingPriority(.required, for: .horizontal)

        let row = UIStackView(arrangedSubviews: [avatar, text, button])
        row.axis = .horizontal
        row.spacing = 12
        row.alignment = .center
        avatar.setContentHuggingPriority(.required, for: .horizontal)

        card.addSubviews(row)
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            row.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),
            row.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            row.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -14)
        ])

        let wrapper = ClosureControl { [weak self] in
            self?.navigationController?.pushViewController(UserProfileViewController(userID: user.id), animated: true)
        }
        wrapper.addSubviews(card)
        card.pinEdges(to: wrapper)
        return wrapper
    }
}

// MARK: - Aliases used across the app

final class MyWorksViewController: PostCollectionViewController {
    init() { super.init(kind: .works) }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

final class MyLikesViewController: PostCollectionViewController {
    init() { super.init(kind: .likes) }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

final class SavedPostsViewController: PostCollectionViewController {
    init() { super.init(kind: .saved) }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

final class MyFollowingViewController: PeopleListViewController {
    init() {
        super.init(title: "My Following",
                   subtitle: "Dancers you follow",
                   users: store.followedUsers,
                   emptyMessage: "You aren't following anyone yet. Find dancers in the community and tap Follow.")
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

// MARK: - Edit profile

final class EditProfileViewController: UIViewController {

    private let scroll = ContentColumn(spacing: 18, gutter: 0)
    private let avatar = RingedAvatarView(size: 104)
    private let avatarHint = UILabel()
    private let nameField = FieldInput(label: "Display name", placeholder: "How other dancers see you", symbol: "person.fill")
    private let handleField = FieldInput(label: "Username", placeholder: "Your @handle", symbol: "at")
    private let cityField = FieldInput(label: "City", placeholder: "Where you train", symbol: "mappin.and.ellipse")
    private let crewField = FieldInput(label: "Crew", placeholder: "Your crew or 'Independent'", symbol: "person.3.fill")
    private let bioContainer = SurfaceCard(colors: [Palette.surfaceHi.withAlphaComponent(0.7), Palette.surface.withAlphaComponent(0.7)],
                                           radius: 22, border: Palette.stroke)
    private let bioView = UITextView()
    private let stylePicker = StylePickerView(selected: [], allowsMultiple: true)
    private let saveButton = PillButton("Save Changes", symbol: "checkmark", style: .primary)
    private var pickedAvatar: String?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Palette.ink
        installBrandBackButton()
        styleNavigationBar(title: "Edit Profile", subtitle: "Your public identity")

        let backdrop = StudioBackdropView()
        view.addSubviews(backdrop)
        backdrop.pinEdges(to: view)

        scroll.setTopPadding(8)
        scroll.setBottomPadding(60)
        scroll.keyboardDismissMode = .interactive
        view.addSubviews(scroll)
        NSLayoutConstraint.activate([
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        buildAvatar()
        buildBio()
        buildStyles()
        scroll.add(saveButton.gutterPadded())
        saveButton.onTap = { [weak self] in self?.save() }

        installKeyboardDismissOnTap()
        observeKeyboard()
        load()
    }

    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

    private func buildAvatar() {
        avatar.isUserInteractionEnabled = true
        avatar.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(pickAvatar)))

        avatarHint.text = "Tap to change your photo"
        avatarHint.font = Typo.caption
        avatarHint.textColor = Palette.textMuted

        let column = UIStackView(arrangedSubviews: [avatar, avatarHint])
        column.axis = .vertical
        column.spacing = 10
        column.alignment = .center
        scroll.add(column.gutterPadded())
    }

    private func buildBio() {
        let label = UILabel()
        label.attributedText = NSAttributedString(string: "BIO", attributes: [
            .kern: 1.3, .font: UIFont.dancte(10, .bold), .foregroundColor: Palette.textFaint
        ])

        bioView.backgroundColor = .clear
        bioView.font = .dancte(15.5, .regular)
        bioView.textColor = Palette.text
        bioView.tintColor = Palette.lime
        bioView.isScrollEnabled = false
        bioView.textContainerInset = UIEdgeInsets(top: 12, left: 10, bottom: 12, right: 10)
        bioView.translatesAutoresizingMaskIntoConstraints = false

        bioContainer.addSubviews(bioView)
        NSLayoutConstraint.activate([
            bioContainer.heightAnchor.constraint(greaterThanOrEqualToConstant: 130),
            bioView.leadingAnchor.constraint(equalTo: bioContainer.leadingAnchor, constant: 6),
            bioView.trailingAnchor.constraint(equalTo: bioContainer.trailingAnchor, constant: -6),
            bioView.topAnchor.constraint(equalTo: bioContainer.topAnchor, constant: 4),
            bioView.bottomAnchor.constraint(equalTo: bioContainer.bottomAnchor, constant: -4)
        ])

        let column = UIStackView(arrangedSubviews: [label, nameField, handleField, cityField, crewField, label2("ABOUT YOU"), bioContainer])
        column.axis = .vertical
        column.spacing = 14
        column.translatesAutoresizingMaskIntoConstraints = false
        scroll.add(column.gutterPadded())
    }

    private func label2(_ text: String) -> UILabel {
        let label = UILabel()
        label.attributedText = NSAttributedString(string: text, attributes: [
            .kern: 1.3, .font: UIFont.dancte(10, .bold), .foregroundColor: Palette.textFaint
        ])
        return label
    }

    private func buildStyles() {
        let label = label2("YOUR STYLES")
        let hint = UILabel()
        hint.text = "Pick everything you train. This shapes who we suggest you connect with."
        hint.font = Typo.caption
        hint.textColor = Palette.textFaint
        hint.numberOfLines = 0

        let column = UIStackView(arrangedSubviews: [label, hint, stylePicker])
        column.axis = .vertical
        column.spacing = 12
        scroll.add(column.gutterPadded())
    }

    private func load() {
        guard let user = store.currentUser else { return }
        avatar.configure(user: user)
        nameField.text = user.displayName
        handleField.text = user.handle
        cityField.text = user.city
        crewField.text = user.crew
        bioView.text = user.bio
        stylePicker.setSelection(Set(user.styles))
    }

    @objc private func pickAvatar() {
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.selectionLimit = 1
        configuration.filter = .images
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = self
        present(picker, animated: true)
    }

    private func save() {
        view.endEditing(true)
        let name = nameField.text.trimmed
        guard !name.isEmpty else {
            nameField.showError("Add a display name.")
            return
        }
        store.updateProfile(displayName: name,
                            handle: handleField.text,
                            bio: bioView.text,
                            city: cityField.text,
                            crew: crewField.text,
                            styles: Array(stylePicker.selected),
                            avatarName: pickedAvatar)
        Haptics.success()
        Toast.success("Profile updated")
        navigationController?.popViewController(animated: true)
    }

    private func observeKeyboard() {
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardChanged(_:)),
                                               name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
    }

    @objc private func keyboardChanged(_ note: Notification) {
        guard let frame = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
        let overlap = max(0, view.bounds.maxY - view.convert(frame, from: nil).minY)
        scroll.contentInset.bottom = overlap
        scroll.verticalScrollIndicatorInsets.bottom = overlap
    }
}

extension EditProfileViewController: PHPickerViewControllerDelegate {

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard let provider = results.first?.itemProvider, provider.canLoadObject(ofClass: UIImage.self) else { return }
        provider.loadObject(ofClass: UIImage.self) { [weak self] object, _ in
            guard let image = object as? UIImage else { return }
            let square = image.squareCropped(maxDimension: 800)
            let name = "avatar_\(UUID().uuidString.prefix(10))"
            let stored = MediaStore.save(image: square, name: name) ?? name
            Task { @MainActor in
                guard let self else { return }
                self.pickedAvatar = stored
                self.avatar.configure(displayName: "", assetName: stored, seed: stored)
                Haptics.success()
            }
        }
    }
}

extension UIImage {
    /// Centre-crops to a square and downscales — the shape every avatar needs.
    func squareCropped(maxDimension: CGFloat = 800) -> UIImage {
        let side = min(size.width, size.height)
        let origin = CGPoint(x: (size.width - side) / 2, y: (size.height - side) / 2)
        guard let cropped = cgImage?.cropping(to: CGRect(origin: origin, size: CGSize(width: side, height: side))) else {
            return self
        }
        let square = UIImage(cgImage: cropped, scale: scale, orientation: imageOrientation)
        return square.downscaled(maxDimension: maxDimension)
    }
}

// MARK: - About

final class AboutViewController: UIViewController {

    private let scroll = ContentColumn(spacing: 20, gutter: 0)

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Palette.ink
        installBrandBackButton()
        styleNavigationBar(title: "About", subtitle: "Dancte 1.0")

        let backdrop = StudioBackdropView()
        view.addSubviews(backdrop)
        backdrop.pinEdges(to: view)

        scroll.setTopPadding(10)
        scroll.setBottomPadding(60)
        view.addSubviews(scroll)
        NSLayoutConstraint.activate([
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        scroll.add(makeHero().gutterPadded())
        scroll.add(makeIntro().gutterPadded())
        scroll.add(makeFeatures().gutterPadded())
        scroll.add(makeCommunityRules().gutterPadded())
        scroll.add(makeLegal().gutterPadded())
        scroll.add(makeFooter().gutterPadded())
    }

    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

    private func makeHero() -> UIView {
        let mark = BrandMarkView(size: 84)
        let wordmark = UILabel()
        wordmark.attributedText = NSAttributedString(string: "DANCTE", attributes: [
            .kern: 5, .font: UIFont.dancte(30, .black), .foregroundColor: Palette.text
        ])
        let tagline = UILabel()
        tagline.attributedText = NSAttributedString(string: "TRAIN · POST · CONNECT", attributes: [
            .kern: 2.2, .font: UIFont.dancte(10, .bold), .foregroundColor: Palette.lime
        ])

        let column = UIStackView(arrangedSubviews: [mark, wordmark, tagline])
        column.axis = .vertical
        column.spacing = 8
        column.alignment = .center
        column.setCustomSpacing(16, after: mark)
        return column
    }

    private func makeIntro() -> UIView {
        let card = SurfaceCard(colors: Grad.card, radius: 26, border: Palette.stroke)
        let label = UILabel()
        label.text = """
        Dancte is a home for dancers. Watch and study the clips that make you better, publish your own work to the community, keep an honest record of every session you train, and talk to the dancers you actually train with.

        Everything here is built around one idea: the hours you put in are the story. The training log is the heart of the app — the rest exists to keep you coming back to it.
        """
        label.font = Typo.body
        label.textColor = Palette.textMuted
        label.numberOfLines = 0

        card.addSubviews(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            label.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),
            label.topAnchor.constraint(equalTo: card.topAnchor, constant: 20),
            label.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -20)
        ])
        return card
    }

    private func makeFeatures() -> UIView {
        let header = SectionHeader(eyebrow: "What's inside", title: "Features")
        let column = UIStackView(axis: .vertical, spacing: 12)
        column.addArrangedSubview(header)

        let features: [(String, String, String, UIColor)] = [
            ("play.rectangle.fill", "Spotlight", "Five featured clips each week, with full playback control — pause, scrub, skip back and forward.", Palette.lime),
            ("square.grid.2x2.fill", "Community", "Post photos, clips and text with tags, like and save what moves you, and comment on other dancers' work.", Palette.cyan),
            ("flame.fill", "Training Log", "Log every session: style, minutes, intensity, the drills you ran and how it felt. Streaks, weekly targets, plans and a skill tree all build from it.", Palette.blaze),
            ("bubble.left.and.bubble.right.fill", "Crew Messaging", "Conversations are limited to dancers who have both agreed to connect, with gift sending and video calls.", Palette.violet),
            ("gift.fill", "Gifts", "Seven collectible gifts, one per price tier, bought through your Apple Account and delivered straight into a conversation.", Palette.amber)
        ]

        for (symbol, title, body, accent) in features {
            column.addArrangedSubview(makeFeatureCard(symbol: symbol, title: title, body: body, accent: accent))
        }
        return column
    }

    private func makeFeatureCard(symbol: String, title: String, body: String, accent: UIColor) -> UIView {
        let card = SurfaceCard(colors: [accent.withAlphaComponent(0.12), Palette.surface],
                               radius: 22, border: accent.withAlphaComponent(0.28))
        let icon = UIImageView(image: UIImage(systemName: symbol, withConfiguration: UIImage.SymbolConfiguration(pointSize: 18, weight: .bold)))
        icon.tintColor = accent
        icon.contentMode = .center
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.widthAnchor.constraint(equalToConstant: 26).isActive = true

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .dancte(16, .bold)
        titleLabel.textColor = Palette.text

        let bodyLabel = UILabel()
        bodyLabel.text = body
        bodyLabel.font = Typo.caption
        bodyLabel.textColor = Palette.textMuted
        bodyLabel.numberOfLines = 0

        let text = UIStackView(arrangedSubviews: [titleLabel, bodyLabel])
        text.axis = .vertical
        text.spacing = 3

        let row = UIStackView(arrangedSubviews: [icon, text])
        row.axis = .horizontal
        row.spacing = 12
        row.alignment = .top

        card.addSubviews(row)
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            row.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            row.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            row.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16)
        ])
        return card
    }

    private func makeCommunityRules() -> UIView {
        let card = SurfaceCard(colors: [Palette.violet.withAlphaComponent(0.14), Palette.surface],
                               radius: 24, border: Palette.violet.withAlphaComponent(0.35))
        let title = UILabel()
        title.text = "How this community works"
        title.font = .dancte(17, .bold)
        title.textColor = Palette.text

        let body = UILabel()
        body.text = """
        Dancte has no random chat. Direct messages are available only between dancers who have both agreed to connect — mutual follows or an accepted friend request.

        Every post, comment and account can be reported. Reporting removes the content from your view immediately, and blocking removes that dancer and everything they posted from your feeds.
        """
        body.font = Typo.caption
        body.textColor = Palette.textMuted
        body.numberOfLines = 0

        let column = UIStackView(arrangedSubviews: [title, body])
        column.axis = .vertical
        column.spacing = 8

        card.addSubviews(column)
        NSLayoutConstraint.activate([
            column.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 18),
            column.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -18),
            column.topAnchor.constraint(equalTo: card.topAnchor, constant: 18),
            column.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -18)
        ])
        return card
    }

    private func makeLegal() -> UIView {
        let card = SurfaceCard(colors: Grad.card, radius: 24, border: Palette.stroke.withAlphaComponent(0.8))
        let column = UIStackView(axis: .vertical, spacing: 0)
        card.addSubviews(column)
        NSLayoutConstraint.activate([
            column.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 6),
            column.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -6),
            column.topAnchor.constraint(equalTo: card.topAnchor, constant: 8),
            column.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -8)
        ])

        let documents: [LegalDocument] = [.terms, .privacy, .eula]
        for (index, document) in documents.enumerated() {
            let row = MenuRowView(symbol: document.symbol, title: document.title,
                                  detail: document.eyebrow, accent: document.accent)
            row.onTap = { [weak self] in
                self?.navigationController?.pushViewController(LegalDocumentViewController(document: document), animated: true)
            }
            column.addArrangedSubview(row)
            if index < documents.count - 1 {
                column.addArrangedSubview(SeamView(color: Palette.stroke.withAlphaComponent(0.5)).gutterPadded(30))
            }
        }
        return card
    }

    private func makeFooter() -> UIView {
        let label = UILabel()
        label.text = "Dancte · Version 1.0 · Built for dancers"
        label.font = Typo.caption
        label.textColor = Palette.textFaint
        label.textAlignment = .center
        return label
    }
}
