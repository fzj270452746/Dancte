import UIKit

// MARK: - Message bubble

final class MessageBubbleView: UIView {

    var onOpenGift: ((Gift) -> Void)?

    private let bubble = UIView()
    private let bodyLabel = UILabel()
    private let timeLabel = UILabel()
    private let giftName = UILabel()
    private let giftPrice = UILabel()
    private let systemRow = UIStackView(axis: .horizontal, spacing: 8)

    init(message: ChatMessage, isMine: Bool) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        timeLabel.font = .dancteMono(10, .semibold)
        timeLabel.textColor = Palette.textFaint
        timeLabel.text = message.createdAt.clockLabel

        switch message.kind {
        case .call:
            buildSystem(message)
        case .gift:
            buildGift(message, isMine: isMine)
        case .text:
            buildText(message, isMine: isMine)
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: Builders

    private func buildText(_ message: ChatMessage, isMine: Bool) {
        bubble.translatesAutoresizingMaskIntoConstraints = false
        bubble.layer.cornerRadius = 20
        bubble.layer.cornerCurve = .continuous
        bubble.backgroundColor = isMine ? Palette.lime.withAlphaComponent(0.92) : Palette.surfaceHi.withAlphaComponent(0.9)
        if !isMine {
            bubble.layer.borderWidth = 1
            bubble.layer.borderColor = Palette.stroke.cgColor
        }

        bodyLabel.text = message.text
        bodyLabel.font = .dancte(15, .regular)
        bodyLabel.textColor = isMine ? Palette.ink : Palette.text
        bodyLabel.numberOfLines = 0
        bodyLabel.translatesAutoresizingMaskIntoConstraints = false

        bubble.addSubviews(bodyLabel)
        NSLayoutConstraint.activate([
            bodyLabel.leadingAnchor.constraint(equalTo: bubble.leadingAnchor, constant: 14),
            bodyLabel.trailingAnchor.constraint(equalTo: bubble.trailingAnchor, constant: -14),
            bodyLabel.topAnchor.constraint(equalTo: bubble.topAnchor, constant: 10),
            bodyLabel.bottomAnchor.constraint(equalTo: bubble.bottomAnchor, constant: -10)
        ])

        let column = UIStackView(arrangedSubviews: [bubble, timeLabel])
        column.axis = .vertical
        column.spacing = 4
        column.alignment = isMine ? .trailing : .leading
        addSubviews(column)
        column.pinEdges(to: self)

        bubble.widthAnchor.constraint(lessThanOrEqualToConstant: UIScreen.screenWidth * 0.72).isActive = true
    }

    private func buildGift(_ message: ChatMessage, isMine: Bool) {
        guard let gift = store.gift(message.giftID) else {
            buildText(message, isMine: isMine)
            return
        }

        bubble.translatesAutoresizingMaskIntoConstraints = false
        bubble.layer.cornerRadius = 22
        bubble.layer.cornerCurve = .continuous
        bubble.backgroundColor = gift.accent.withAlphaComponent(0.16)
        bubble.layer.borderWidth = 1.5
        bubble.layer.borderColor = gift.accent.withAlphaComponent(0.6).cgColor

        let giftArt = GiftArtView(gift: gift, tile: 54, glyphPointSize: 22)

        giftName.text = gift.name
        giftName.font = .dancte(15, .bold)
        giftName.textColor = Palette.text

        giftPrice.text = "\(isMine ? "You sent" : "Received") · \(StoreKitService.shared.displayPrice(for: gift))"
        giftPrice.font = .dancteMono(11, .semibold)
        giftPrice.textColor = gift.accent

        let text = UIStackView(arrangedSubviews: [giftName, giftPrice])
        text.axis = .vertical
        text.spacing = 2

        bubble.addSubviews(giftArt, text)
        NSLayoutConstraint.activate([
            giftArt.leadingAnchor.constraint(equalTo: bubble.leadingAnchor, constant: 12),
            giftArt.topAnchor.constraint(equalTo: bubble.topAnchor, constant: 12),
            giftArt.bottomAnchor.constraint(equalTo: bubble.bottomAnchor, constant: -12),
            text.leadingAnchor.constraint(equalTo: giftArt.trailingAnchor, constant: 12),
            text.trailingAnchor.constraint(equalTo: bubble.trailingAnchor, constant: -16),
            text.centerYAnchor.constraint(equalTo: bubble.centerYAnchor)
        ])

        let column = UIStackView(arrangedSubviews: [bubble, timeLabel])
        column.axis = .vertical
        column.spacing = 4
        column.alignment = isMine ? .trailing : .leading
        addSubviews(column)
        column.pinEdges(to: self)

        let tap = UITapGestureRecognizer(target: self, action: #selector(openGift))
        bubble.addGestureRecognizer(tap)
        bubble.isUserInteractionEnabled = true
        self.gift = gift
    }

    private var gift: Gift?

    @objc private func openGift() {
        guard let gift else { return }
        onOpenGift?(gift)
    }

    private func buildSystem(_ message: ChatMessage) {
        let icon = UIImageView(image: UIImage(systemName: "video.fill", withConfiguration: UIImage.SymbolConfiguration(pointSize: 12, weight: .bold)))
        icon.tintColor = Palette.textFaint

        let label = UILabel()
        label.text = message.text
        label.font = .dancte(11.5, .semibold)
        label.textColor = Palette.textFaint

        systemRow.addArrangedSubview(icon)
        systemRow.addArrangedSubview(label)
        systemRow.alignment = .center
        systemRow.translatesAutoresizingMaskIntoConstraints = false

        let pill = UIView()
        pill.translatesAutoresizingMaskIntoConstraints = false
        pill.backgroundColor = Palette.surfaceHi.withAlphaComponent(0.6)
        pill.layer.cornerRadius = 13
        pill.addSubviews(systemRow)

        addSubviews(pill)
        NSLayoutConstraint.activate([
            systemRow.leadingAnchor.constraint(equalTo: pill.leadingAnchor, constant: 12),
            systemRow.trailingAnchor.constraint(equalTo: pill.trailingAnchor, constant: -12),
            systemRow.topAnchor.constraint(equalTo: pill.topAnchor, constant: 7),
            systemRow.bottomAnchor.constraint(equalTo: pill.bottomAnchor, constant: -7),
            pill.topAnchor.constraint(equalTo: topAnchor),
            pill.bottomAnchor.constraint(equalTo: bottomAnchor),
            pill.leadingAnchor.constraint(equalTo: leadingAnchor),
            pill.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
    }
}

// MARK: - Chat detail

final class ChatDetailViewController: UIViewController, OwnsNavigationBar {

    var prefersOwnHeader: Bool { true }

    private let peerID: String
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let header = UIView()
    private let avatar = RingedAvatarView(size: 40, showsDot: true)
    private let nameLabel = UILabel()
    private let statusLabel = UILabel()
    private let backButton = IconButton(symbol: "arrow.left", size: 40, background: .glass, pointSize: 15)
    private let moreButton = IconButton(symbol: "ellipsis", size: 40, background: .glass, pointSize: 15)
    private let callButton = IconButton(symbol: "video.fill", size: 42, background: .gradient(Grad.lime), pointSize: 15)
    private let giftButton = IconButton(symbol: "gift.fill", size: 42, background: .gradient(Grad.violet), pointSize: 15)
    private let inputField = UITextField()
    private let sendButton = IconButton(symbol: "arrow.up", size: 40, background: .gradient(Grad.lime), pointSize: 15)
    private let inputBar = UIView()
    private var inputBottom: NSLayoutConstraint!
    private var messages: [ChatMessage] = []

    init(peerID: String) {
        self.peerID = peerID
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Palette.ink

        let backdrop = StudioBackdropView()
        view.addSubviews(backdrop)
        backdrop.pinEdges(to: view)

        buildHeader()
        buildTable()
        buildInputBar()

        NotificationCenter.default.addObserver(self, selector: #selector(reload), name: .dancteChat, object: nil)
        reload()
        store.markRead(peerID)
        observeKeyboard()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

    // MARK: - Chrome

    private func buildHeader() {
        header.translatesAutoresizingMaskIntoConstraints = false
        header.backgroundColor = UIColor(hex: 0x12141B).withAlphaComponent(0.92)
        header.layer.borderWidth = 1
        header.layer.borderColor = Palette.stroke.withAlphaComponent(0.6).cgColor
        view.addSubviews(header)

        let peer = store.user(peerID)
        avatar.configure(user: peer)
        statusLabel.text = "Connected"

        nameLabel.text = peer?.displayName ?? "Dancte Dancer"
        nameLabel.font = .dancte(15.5, .bold)
        nameLabel.textColor = Palette.text
        statusLabel.attributedText = NSAttributedString(string: "CONNECTED · FRIENDS ONLY", attributes: [
            .kern: 0.9, .font: UIFont.dancte(9, .bold), .foregroundColor: Palette.lime
        ])

        let text = UIStackView(arrangedSubviews: [nameLabel, statusLabel])
        text.axis = .vertical
        text.spacing = 1

        avatar.isUserInteractionEnabled = true
        avatar.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(openProfile)))
        text.isUserInteractionEnabled = true
        text.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(openProfile)))

        let row = UIStackView(arrangedSubviews: [backButton, avatar, text, UIView(), callButton, moreButton])
        row.axis = .horizontal
        row.spacing = 10
        row.alignment = .center
        row.translatesAutoresizingMaskIntoConstraints = false

        header.addSubviews(row)
        NSLayoutConstraint.activate([
            header.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            header.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            header.topAnchor.constraint(equalTo: view.topAnchor),
            header.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 56),

            row.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: Metric.gutter),
            row.trailingAnchor.constraint(equalTo: header.trailingAnchor, constant: -Metric.gutter),
            row.bottomAnchor.constraint(equalTo: header.bottomAnchor, constant: -8)
        ])

        backButton.onTap = { [weak self] in self?.navigationController?.popViewController(animated: true) }
        moreButton.onTap = { [weak self] in self?.presentMore() }
        callButton.onTap = { [weak self] in self?.startCall() }
    }

    private func buildTable() {
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(MessageCell.self, forCellReuseIdentifier: MessageCell.reuseID)
        tableView.keyboardDismissMode = .interactive
        tableView.contentInset = UIEdgeInsets(top: 16, left: 0, bottom: 16, right: 0)
        tableView.showsVerticalScrollIndicator = false
        view.addSubviews(tableView)
    }

    private func buildInputBar() {
        inputBar.translatesAutoresizingMaskIntoConstraints = false
        inputBar.backgroundColor = UIColor(hex: 0x12141B).withAlphaComponent(0.94)
        inputBar.layer.borderWidth = 1
        inputBar.layer.borderColor = Palette.stroke.withAlphaComponent(0.6).cgColor
        view.addSubviews(inputBar)

        inputBottom = inputBar.bottomAnchor.constraint(equalTo: view.bottomAnchor)

        inputField.font = .dancte(15, .medium)
        inputField.textColor = Palette.text
        inputField.tintColor = Palette.lime
        inputField.attributedPlaceholder = NSAttributedString(string: "Message…", attributes: [
            .foregroundColor: Palette.textFaint,
            .font: UIFont.dancte(15, .regular)
        ])
        inputField.translatesAutoresizingMaskIntoConstraints = false
        inputField.returnKeyType = .send
        inputField.delegate = self

        let shell = UIView()
        shell.backgroundColor = Palette.surfaceHi.withAlphaComponent(0.7)
        shell.layer.cornerRadius = 19
        shell.layer.cornerCurve = .continuous
        shell.layer.borderWidth = 1
        shell.layer.borderColor = Palette.stroke.cgColor
        shell.translatesAutoresizingMaskIntoConstraints = false
        shell.addSubviews(inputField)

        inputBar.addSubviews(giftButton, shell, sendButton)
        NSLayoutConstraint.activate([
            inputBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            inputBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            inputBottom,
            inputBar.topAnchor.constraint(equalTo: giftButton.topAnchor, constant: -12),

            giftButton.leadingAnchor.constraint(equalTo: inputBar.leadingAnchor, constant: Metric.gutter),
            giftButton.centerYAnchor.constraint(equalTo: inputBar.safeAreaLayoutGuide.bottomAnchor, constant: -32),

            shell.leadingAnchor.constraint(equalTo: giftButton.trailingAnchor, constant: 10),
            shell.trailingAnchor.constraint(equalTo: sendButton.leadingAnchor, constant: -10),
            shell.centerYAnchor.constraint(equalTo: giftButton.centerYAnchor),
            shell.heightAnchor.constraint(equalToConstant: 40),

            inputField.leadingAnchor.constraint(equalTo: shell.leadingAnchor, constant: 14),
            inputField.trailingAnchor.constraint(equalTo: shell.trailingAnchor, constant: -12),
            inputField.centerYAnchor.constraint(equalTo: shell.centerYAnchor),

            sendButton.trailingAnchor.constraint(equalTo: inputBar.trailingAnchor, constant: -Metric.gutter),
            sendButton.centerYAnchor.constraint(equalTo: giftButton.centerYAnchor)
        ])

        giftButton.onTap = { [weak self] in self?.presentGiftPanel() }
        sendButton.onTap = { [weak self] in self?.send() }

        tableView.bottomAnchor.constraint(equalTo: inputBar.topAnchor).isActive = true
        tableView.topAnchor.constraint(equalTo: header.bottomAnchor).isActive = true
        tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
        tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
    }

    // MARK: - Data

    @objc private func reload() {
        messages = store.conversation(with: peerID)?.messages ?? []
        tableView.reloadData()
        scrollToBottom(animated: false)
    }

    private func scrollToBottom(animated: Bool) {
        guard !messages.isEmpty else { return }
        let last = IndexPath(row: messages.count - 1, section: 0)
        tableView.scrollToRow(at: last, at: .bottom, animated: animated)
    }

    // MARK: - Actions

    private func send() {
        let text = inputField.text?.trimmed ?? ""
        guard !text.isEmpty else { return }
        inputField.text = ""
        store.sendMessage(to: peerID, kind: .text, text: text)
        Haptics.tap()
        reload()
        scrollToBottom(animated: true)
    }

    private func presentGiftPanel() {
        let panel = GiftPanelViewController(peerID: peerID)
        presentSheet(panel)
    }

    private func startCall() {
        let peer = store.user(peerID)
        let call = CallViewController(peer: peer)
        call.onFinish = { [weak self] outcome in
            guard let self else { return }
            store.sendMessage(to: self.peerID, kind: .call, text: "Video call · \(outcome)")
            self.reload()
            self.scrollToBottom(animated: true)
        }
        call.modalPresentationStyle = .fullScreen
        present(call, animated: true)
    }

    @objc private func openProfile() {
        navigationController?.pushViewController(UserProfileViewController(userID: peerID), animated: true)
    }

    private func presentMore() {
        let sheet = UIAlertController(title: "@\(store.authorHandle(of: peerID))", message: nil, preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: "View Profile", style: .default) { [weak self] _ in self?.openProfile() })
        sheet.addAction(UIAlertAction(title: "Report or Block", style: .destructive) { [weak self] _ in
            guard let self else { return }
            let report = ReportViewController(target: .user(self.peerID))
            report.onFinish = { returnsToRoot in
                if returnsToRoot { self.navigationController?.popToRootViewController(animated: true) }
            }
            self.presentSheet(report)
        })
        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        if let popover = sheet.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 1, height: 1)
            popover.permittedArrowDirections = []
        }
        present(sheet, animated: true)
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
        if overlap > 0 { scrollToBottom(animated: true) }
    }
}

// MARK: - Table

extension ChatDetailViewController: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        messages.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: MessageCell.reuseID, for: indexPath)
        let message = messages[indexPath.row]
        (cell as? MessageCell)?.configure(message: message,
                                          isMine: message.senderID == store.currentUserID,
                                          peer: store.user(peerID))
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)
    }
}

final class MessageCell: UITableViewCell {

    static let reuseID = "MessageCell"

    private var bubble: MessageBubbleView?
    private let avatar = AvatarView(size: 30)
    private let container = UIView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        selectionStyle = .none
        contentView.addSubviews(container)
        container.pinEdges(to: contentView)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(message: ChatMessage, isMine: Bool, peer: User?) {
        bubble?.removeFromSuperview()
        avatar.removeFromSuperview()

        let bubble = MessageBubbleView(message: message, isMine: isMine)
        container.addSubviews(bubble)
        self.bubble = bubble

        let showsAvatar = !isMine && message.kind != .call
        NSLayoutConstraint.activate([
            bubble.topAnchor.constraint(equalTo: container.topAnchor, constant: 5),
            bubble.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -5)
        ])

        if message.kind == .call {
            NSLayoutConstraint.activate([
                bubble.centerXAnchor.constraint(equalTo: container.centerXAnchor),
                bubble.leadingAnchor.constraint(greaterThanOrEqualTo: container.leadingAnchor, constant: 24),
                bubble.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -24)
            ])
            return
        }

        if isMine {
            NSLayoutConstraint.activate([
                bubble.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -Metric.gutter),
                bubble.leadingAnchor.constraint(greaterThanOrEqualTo: container.leadingAnchor,
                                                constant: Metric.gutter + 56)
            ])
        } else if showsAvatar {
            avatar.configure(user: peer)
            container.addSubviews(avatar)
            NSLayoutConstraint.activate([
                avatar.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: Metric.gutter),
                avatar.bottomAnchor.constraint(equalTo: bubble.bottomAnchor, constant: -18),
                bubble.leadingAnchor.constraint(equalTo: avatar.trailingAnchor, constant: 10),
                bubble.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor,
                                                 constant: -(Metric.gutter + 40))
            ])
        } else {
            NSLayoutConstraint.activate([
                bubble.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: Metric.gutter + 40),
                bubble.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor,
                                                 constant: -(Metric.gutter + 40))
            ])
        }
    }
}

extension ChatDetailViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        send()
        return true
    }
}
