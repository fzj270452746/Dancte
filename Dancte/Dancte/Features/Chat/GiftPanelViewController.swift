import UIKit

/// Gift picker for a conversation. Seven gifts, one per price tier, each a
/// consumable in-app purchase billed through the Apple Account.
final class GiftPanelViewController: UIViewController, OwnsNavigationBar {

    var prefersOwnHeader: Bool { true }

    private let peerID: String
    private let scroll = ContentColumn(spacing: 18, gutter: 0)
    private let grid = UIStackView(axis: .vertical, spacing: 10)
    private let closeButton = IconButton(symbol: "xmark", size: 40, background: .glass, pointSize: 15)
    private let collectionLabel = UILabel()
    private var cards: [GiftCard] = []
    private var isPurchasing = false

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

        scroll.setTopPadding(14)
        scroll.setBottomPadding(50)
        view.addSubviews(scroll)
        scroll.pinEdges(to: view)

        scroll.add(makeHeader())
        scroll.add(makeCollectionCard())
        buildGrid()
        scroll.add(grid.gutterPadded())
        scroll.add(makeFootnote().gutterPadded())

        Task { await StoreKitService.shared.loadProducts(); refreshPrices() }
        NotificationCenter.default.addObserver(self, selector: #selector(refreshPrices), name: .dancteWallet, object: nil)
    }

    // MARK: - Sections

    private func makeHeader() -> UIView {
        let title = UILabel()
        title.text = "Send a Gift"
        title.font = .dancte(30, .black)
        title.textColor = Palette.text

        let peer = store.user(peerID)
        let subtitle = UILabel()
        subtitle.text = "Choose something for @\(store.authorHandle(of: peerID)). Gifts are delivered instantly in the conversation."
        subtitle.font = Typo.body
        subtitle.textColor = Palette.textMuted
        subtitle.numberOfLines = 0

        let text = UIStackView(arrangedSubviews: [title, subtitle])
        text.axis = .vertical
        text.spacing = 8

        let row = UIStackView(arrangedSubviews: [text, closeButton])
        row.axis = .horizontal
        row.spacing = 12
        row.alignment = .top
        closeButton.setContentHuggingPriority(.required, for: .horizontal)

        closeButton.onTap = { [weak self] in self?.dismiss(animated: true) }
        _ = peer
        return row
    }

    private func makeCollectionCard() -> UIView {
        let card = SurfaceCard(colors: [Palette.violet.withAlphaComponent(0.18), Palette.surface],
                               radius: 22, border: Palette.violet.withAlphaComponent(0.4))
        let icon = UIImageView(image: UIImage(systemName: "shippingbox.fill", withConfiguration:
                                                UIImage.SymbolConfiguration(pointSize: 18, weight: .bold)))
        icon.tintColor = Palette.violet
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.widthAnchor.constraint(equalToConstant: 26).isActive = true

        collectionLabel.font = .dancte(14.5, .semibold)
        collectionLabel.textColor = Palette.text
        collectionLabel.numberOfLines = 2

        let row = UIStackView(arrangedSubviews: [icon, collectionLabel])
        row.axis = .horizontal
        row.spacing = 12
        row.alignment = .center

        card.addSubviews(row)
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 18),
            row.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -18),
            row.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            row.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16)
        ])
        refreshCollection()
        return card
    }

    private func buildGrid() {
        let gifts = store.gifts.sorted { $0.tier < $1.tier }
        var pending: [UIView] = []
        for (index, gift) in gifts.enumerated() {
            let card = GiftCard(gift: gift)
            card.onSelect = { [weak self] in self?.purchase(gift) }
            cards.append(card)
            pending.append(card)
            if pending.count == 2 || index == gifts.count - 1 {
                let row = UIStackView(axis: .horizontal, spacing: 10, distribution: .fillEqually)
                pending.forEach { row.addArrangedSubview($0) }
                if pending.count < 2 { row.addArrangedSubview(UIView()) }
                grid.addArrangedSubview(row)
                pending = []
            }
        }
    }

    private func makeFootnote() -> UIView {
        let icon = UIImageView(image: UIImage(systemName: "info.circle.fill", withConfiguration:
                                                UIImage.SymbolConfiguration(pointSize: 13, weight: .bold)))
        icon.tintColor = Palette.textFaint
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.setContentHuggingPriority(.required, for: .horizontal)

        let label = UILabel()
        label.text = "Gifts are consumable items purchased through your Apple Account. Prices are shown in US dollars, and payment is confirmed by Apple before anything is sent."
        label.font = .dancte(11.5, .medium)
        label.textColor = Palette.textFaint
        label.numberOfLines = 0

        let row = UIStackView(arrangedSubviews: [icon, label])
        row.axis = .horizontal
        row.spacing = 9
        row.alignment = .top
        return row
    }

    // MARK: - State

    @objc private func refreshPrices() {
        for card in cards { card.refreshPrice() }
        refreshCollection()
    }

    private func refreshCollection() {
        let owned = store.ownedGiftTotal
        collectionLabel.text = owned == 0
            ? "Your gift collection is empty. Anything you buy is kept here for later."
            : "You've collected \(owned) gift\(owned == 1 ? "" : "s") so far."
    }

    // MARK: - Purchase

    private func purchase(_ gift: Gift) {
        guard !isPurchasing else { return }
        isPurchasing = true
        let overlay = LoadingOverlay.present(on: view, message: "Confirming")

        Task { @MainActor in
            defer { isPurchasing = false }
            do {
                let outcome = try await StoreKitService.shared.purchase(gift)
                overlay.dismiss()
                switch outcome {
                case .purchased:
                    deliver(gift)
                case .cancelled:
                    Toast.show("Purchase cancelled")
                case .pending:
                    Toast.show("Waiting for approval", kind: .warning,
                               detail: "Your purchase is pending. The gift arrives once it's approved.")
                case .unavailable:
                    Toast.error("That gift isn't available right now.")
                }
            } catch {
                overlay.dismiss()
                let message = (error as? LocalizedError)?.errorDescription ?? "The purchase could not be completed."
                Toast.error(message)
            }
        }
    }

    private func deliver(_ gift: Gift) {
        Haptics.success()
        store.sendMessage(to: peerID, kind: .gift, text: gift.name, giftID: gift.id)
        refreshCollection()
        dismiss(animated: true) {
            Toast.success("\(gift.name) sent", detail: "@\(store.authorHandle(of: self.peerID)) will see it now.")
        }
    }
}

// MARK: - Gift card

final class GiftCard: RowControl {

    var onSelect: (() -> Void)?

    private let gift: Gift
    private let nameLabel = UILabel()
    private let taglineLabel = UILabel()
    private let priceLabel = UILabel()
    private let ownedLabel = UILabel()

    init(gift: Gift) {
        self.gift = gift
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = Palette.surfaceHi.withAlphaComponent(0.55)
        layer.cornerRadius = 24
        layer.cornerCurve = .continuous
        layer.borderWidth = 1
        layer.borderColor = Palette.stroke.withAlphaComponent(0.8).cgColor
        accessibilityLabel = "\(gift.name), \(StoreKitService.shared.displayPrice(for: gift))"

        let art = GiftArtView(gift: gift, tile: 54, glyphPointSize: 24)

        // The card is half the screen wide and no wider, so the name and the
        // tagline get the full width under the art instead of the sliver left
        // beside it: nothing here is allowed to end in an ellipsis.
        nameLabel.text = gift.name
        nameLabel.font = .dancte(16, .bold)
        nameLabel.textColor = Palette.text
        nameLabel.textAlignment = .center
        nameLabel.lineBreakMode = .byClipping
        nameLabel.adjustsFontSizeToFitWidth = true
        nameLabel.minimumScaleFactor = 0.8

        taglineLabel.text = gift.tagline
        taglineLabel.font = .dancte(11, .medium)
        taglineLabel.textColor = Palette.textFaint
        taglineLabel.textAlignment = .center
        taglineLabel.lineBreakMode = .byClipping
        taglineLabel.adjustsFontSizeToFitWidth = true
        taglineLabel.minimumScaleFactor = 0.8

        priceLabel.text = StoreKitService.shared.displayPrice(for: gift)
        priceLabel.font = .dancte(15, .heavy)
        priceLabel.textColor = gift.accent

        ownedLabel.font = .dancte(9.5, .bold)
        ownedLabel.textColor = Palette.textFaint
        ownedLabel.textAlignment = .right

        let gap = UIView()
        gap.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let footer = UIStackView(arrangedSubviews: [priceLabel, gap, ownedLabel])
        footer.axis = .horizontal
        footer.alignment = .firstBaseline
        footer.spacing = 8

        addSubviews(art, nameLabel, taglineLabel, footer)
        NSLayoutConstraint.activate([
            art.topAnchor.constraint(equalTo: topAnchor, constant: 14),
            art.centerXAnchor.constraint(equalTo: centerXAnchor),

            nameLabel.topAnchor.constraint(equalTo: art.bottomAnchor, constant: 11),
            nameLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            nameLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),

            taglineLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 2),
            taglineLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            taglineLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),

            footer.topAnchor.constraint(equalTo: taglineLabel.bottomAnchor, constant: 7),
            footer.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            footer.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            footer.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -13)
        ])

        addAction(UIAction { [weak self] _ in
            Haptics.tap()
            self?.onSelect?()
        }, for: .touchUpInside)
        refreshPrice()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func refreshPrice() {
        priceLabel.text = StoreKitService.shared.displayPrice(for: gift)
        let owned = store.ownedCount(of: gift)
        ownedLabel.text = owned > 0 ? "OWNED ×\(owned)" : ""
    }

    override var isHighlighted: Bool {
        didSet {
            UIView.animate(withDuration: 0.12) {
                self.transform = self.isHighlighted ? CGAffineTransform(scaleX: 0.97, y: 0.97) : .identity
            }
        }
    }
}
