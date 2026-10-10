import UIKit

struct LegalSection {
    let heading: String
    let body: String
}

enum LegalDocument {
    case terms
    case privacy
    case eula

    var title: String {
        switch self {
        case .terms:   return "Terms of Service"
        case .privacy: return "Privacy Policy"
        case .eula:    return "End User License Agreement"
        }
    }

    var shortTitle: String {
        switch self {
        case .terms:   return "Terms of Service"
        case .privacy: return "Privacy Policy"
        case .eula:    return "EULA"
        }
    }

    var eyebrow: String {
        switch self {
        case .terms:   return "Legal"
        case .privacy: return "Privacy"
        case .eula:    return "License"
        }
    }

    var symbol: String {
        switch self {
        case .terms:   return "doc.text.fill"
        case .privacy: return "hand.raised.fill"
        case .eula:    return "checkmark.seal.fill"
        }
    }

    var accent: UIColor {
        switch self {
        case .terms:   return Palette.lime
        case .privacy: return Palette.cyan
        case .eula:    return Palette.violet
        }
    }

    var updated: String { "Last updated 9 October 2026" }

    var summary: String {
        switch self {
        case .terms:
            return "The rules for using Dancte — what you can post, how the community is moderated, and what happens if something goes wrong."
        case .privacy:
            return "What we collect, why we collect it, how long we keep it, and the controls you have over your own information."
        case .eula:
            return "The licence that governs the Dancte application itself, including in-app purchases and the limits of our liability."
        }
    }

    var sections: [LegalSection] {
        switch self {
        case .terms:   return LegalDocument.termsSections
        case .privacy: return LegalDocument.privacySections
        case .eula:    return LegalDocument.eulaSections
        }
    }

    // MARK: - Terms of Service

    private static let termsSections: [LegalSection] = [
        LegalSection(heading: "1. Accepting these terms", body: """
        By creating an account or using Dancte you agree to these Terms of Service. If you do not agree, please do not use the app. You must be at least 13 years old, and old enough in your country to consent to using a social service, to hold an account.

        If you use Dancte on behalf of a crew, studio or organisation, you confirm that you have authority to accept these terms for that organisation.
        """),

        LegalSection(heading: "2. Your account", body: """
        You are responsible for the activity on your account and for keeping your password private. Choose a password you do not use anywhere else. Tell us immediately if you believe someone else has access to your account.

        You may hold one personal account. Accounts created to impersonate another dancer, crew or brand, or to evade a suspension, may be removed.
        """),

        LegalSection(heading: "3. What you can post", body: """
        You keep ownership of everything you post — your clips, your captions, your practice logs. By posting, you grant Dancte a worldwide, non-exclusive, royalty-free licence to host, store, reproduce and display that content inside the app, so that we can show it to other dancers and keep the service running. This licence ends when you delete the content, except where copies remain in backups for a reasonable period.

        You must own the rights to the music, footage and images you upload, or otherwise have permission to use them. Do not post content that is unlawful, hateful, sexually explicit, harassing, deceptive, or that depicts another person without their consent.
        """),

        LegalSection(heading: "4. Direct messages and calls", body: """
        Dancte does not allow messaging between strangers. Conversations are available only between dancers who have both agreed to a connection — that is, mutual follows or an accepted friend request. You can end a connection at any time, and doing so stops further messages.

        Treat private conversations as private. Do not screenshot, record or republish another dancer's messages, images or calls without their permission.
        """),

        LegalSection(heading: "5. Gifts and in-app purchases", body: """
        Chat gifts are optional consumable items bought through your Apple Account. Purchases are billed by Apple, are consumed when sent, and are not refundable by Dancte. Refund requests are handled by Apple under their media services terms.

        Prices are shown in your local currency before you confirm a purchase. We may change the gifts available, or their prices, at any time; a change never affects a purchase you have already completed.
        """),

        LegalSection(heading: "6. Community moderation", body: """
        Every dancer can report a post, a comment or an account. When you report content we may remove it, remove the account, or take no action if the content does not breach these terms. Reporting an account also lets you block it, which hides that dancer's content from your feeds and removes any connection between you.

        We may remove content or suspend accounts that breach these terms, that infringe someone else's rights, or that we are legally required to remove. Where it is reasonable to do so, we will tell you what happened and why.
        """),

        LegalSection(heading: "7. Copyright", body: """
        If you believe your work has been used on Dancte without permission, report the post and select "Illegal Content", including enough detail for us to identify the work and your rights in it. We will remove or disable access to the material while we review the report.

        Repeated infringement results in the account being removed.
        """),

        LegalSection(heading: "8. Practice tracking is not medical advice", body: """
        Dancte helps you plan and record dance training. Training information, streak counts and progress figures are provided for your own motivation. They are not medical, physiotherapy or professional coaching advice.

        Dance is physically demanding. Warm up, train within your limits, and consult a qualified professional before starting a new programme, particularly if you are injured, pregnant, or have a medical condition.
        """),

        LegalSection(heading: "9. Availability and changes", body: """
        We work to keep Dancte available, but we do not promise uninterrupted service. Features may change, and we may suspend the service for maintenance.

        We may update these terms. If a change is significant we will tell you in the app before it takes effect. Continuing to use Dancte after a change means you accept the updated terms.
        """),

        LegalSection(heading: "10. Ending your use", body: """
        You can delete your account at any time from the settings screen. Deletion removes your profile, your posts, your comments, your conversations and your practice history from the service, and it cannot be undone.

        If you breach these terms we may suspend or remove your account. Where the law allows, our liability to you is limited to the amount you have paid us in the twelve months before the event giving rise to the claim.
        """)
    ]

    // MARK: - Privacy Policy

    private static let privacySections: [LegalSection] = [
        LegalSection(heading: "1. What this policy covers", body: """
        This policy explains how Dancte handles your information when you use the app. It covers the account you create, the content you post, the messages you send and the practice sessions you record.
        """),

        LegalSection(heading: "2. Information you give us", body: """
        Account details: your username, display name, password (stored only as a salted hash), and the profile information you choose to add such as your bio, city, crew and dance styles. If you sign in with Apple, we receive a stable Apple user identifier plus the name and email address you choose to share the first time you authorise the app.

        Content: the posts, photos, clips, comments and tags you publish, the practice sessions you log, the messages you send and the gifts you purchase.
        """),

        LegalSection(heading: "3. Information kept on your device", body: """
        Your practice log, drafts, feed history and session are stored locally on your device so the app works instantly and offline. Clearing the app's data or deleting your account removes this local copy.

        We do not use third-party advertising trackers, and we do not sell your personal information.
        """),

        LegalSection(heading: "4. How we use your information", body: """
        To run the service: authenticating you, showing your feed, delivering your messages, keeping your practice history in sync across sessions, and completing in-app purchases through Apple.

        To keep the community safe: reviewing reports, removing content that breaches our terms, and preventing abuse.

        To improve the app: understanding which features are used, in aggregate and in a form that does not identify you.
        """),

        LegalSection(heading: "5. Who we share it with", body: """
        Other dancers see what you publish publicly — your profile, posts, comments and practice milestones you choose to share. Your private conversations are visible only to the dancers in them.

        Apple processes payments and, if you use Sign in with Apple, your sign-in. We share information with service providers who host and operate the app on our behalf, and with authorities where we are legally required to do so.
        """),

        LegalSection(heading: "6. How long we keep it", body: """
        We keep your account information while your account exists. When you delete your account we remove your profile, posts, comments, conversations and practice history from the live service. Residual copies may remain in encrypted backups for a short period before they are overwritten on our normal backup cycle.
        """),

        LegalSection(heading: "7. Your choices and rights", body: """
        You can edit your profile, delete any post, delete any comment, and delete your account directly in the app. You can also request a copy of the information associated with your account, or ask us to correct it.

        Depending on where you live you may have additional rights, including the right to object to certain processing or to lodge a complaint with your local data protection authority.
        """),

        LegalSection(heading: "8. Children", body: """
        Dancte is not intended for children under 13, and we do not knowingly collect information from them. If we learn that a child under 13 has created an account, we will remove it.
        """),

        LegalSection(heading: "9. Security", body: """
        We use encryption in transit, salted password hashing and access controls to protect your information. No system is perfectly secure, so please use a strong, unique password and keep it to yourself.
        """),

        LegalSection(heading: "10. Contact", body: """
        Questions about this policy, or about your information, can be sent from the About screen inside the app. We aim to respond within thirty days.
        """)
    ]

    // MARK: - EULA

    private static let eulaSections: [LegalSection] = [
        LegalSection(heading: "1. Licence granted", body: """
        Dancte grants you a personal, non-transferable, non-exclusive licence to use this application on Apple-branded devices that you own or control, as permitted by the Apple Media Services Terms and Conditions. This licence is for your own non-commercial use unless we agree otherwise in writing.
        """),

        LegalSection(heading: "2. Scope of use", body: """
        You may not copy, modify, distribute, sell, lease, sublicense or reverse engineer the application, or attempt to derive its source code, except to the extent that such restriction is prohibited by applicable law. You may not remove or obscure any proprietary notice.
        """),

        LegalSection(heading: "3. In-app purchases", body: """
        Chat gifts are consumable items purchased through your Apple Account and are subject to the Apple Media Services Terms and Conditions. Purchases are tied to your Apple Account and cannot be transferred between accounts. Dancte does not process payments and cannot issue refunds directly.
        """),

        LegalSection(heading: "4. Maintenance and support", body: """
        Dancte is solely responsible for providing maintenance and support for the application. Apple has no obligation to furnish any maintenance or support services with respect to the application.
        """),

        LegalSection(heading: "5. Warranty", body: """
        The application is provided "as is" and "as available", without warranty of any kind to the maximum extent permitted by law. If the application fails to conform to any applicable warranty, you may notify Apple, and Apple may refund the purchase price, if any. To the maximum extent permitted by law, Apple has no other warranty obligation whatsoever with respect to the application.
        """),

        LegalSection(heading: "6. Product claims", body: """
        Dancte, not Apple, is responsible for addressing any claims relating to the application or your possession and use of it, including product liability claims, claims that the application fails to conform to a legal or regulatory requirement, and claims arising under consumer protection or similar legislation.
        """),

        LegalSection(heading: "7. Intellectual property claims", body: """
        If a third party claims that the application infringes their intellectual property rights, Dancte — not Apple — is responsible for the investigation, defence, settlement and discharge of that claim.
        """),

        LegalSection(heading: "8. Legal compliance and third-party terms", body: """
        You confirm that you are not located in a country subject to a United States government embargo, and that you are not listed on any United States government list of prohibited or restricted parties. You must comply with applicable third-party terms when using the application.
        """),

        LegalSection(heading: "9. Third-party beneficiary", body: """
        Apple and Apple's subsidiaries are third-party beneficiaries of this licence, and upon your acceptance they have the right to enforce it against you.
        """),

        LegalSection(heading: "10. Termination", body: """
        This licence is effective until terminated. Your rights under it end automatically if you fail to comply with any term. On termination you must stop using the application and delete all copies from your devices.
        """)
    ]
}

// MARK: - Reader

final class LegalDocumentViewController: UIViewController {

    private let document: LegalDocument
    private weak var sourceAnchor: UIView?

    init(document: LegalDocument, sourceAnchor: UIView? = nil) {
        self.document = document
        self.sourceAnchor = sourceAnchor
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Palette.ink
        installBrandBackButton()
        styleNavigationBar(title: document.title)

        let backdrop = StudioBackdropView()
        view.addSubviews(backdrop)
        backdrop.pinEdges(to: view)

        let scroll = ContentColumn(spacing: 22)
        scroll.setTopPadding(18)
        scroll.setBottomPadding(60)
        view.addSubviews(scroll)
        scroll.pinEdges(to: view)

        let header = SurfaceCard(colors: Grad.forColor(document.accent).map { $0.withAlphaComponent(0.22) },
                                 radius: 26,
                                 border: document.accent.withAlphaComponent(0.4))
        let icon = UIImageView(image: UIImage(systemName: document.symbol,
                                              withConfiguration: UIImage.SymbolConfiguration(pointSize: 22, weight: .bold)))
        icon.tintColor = document.accent
        // The column stretches its arranged subviews to full width, which smeared
        // the glyph across the whole card. Pin it to its natural size instead.
        icon.contentMode = .left
        let titleLabel = UILabel()
        titleLabel.text = document.title
        titleLabel.font = .dancte(21, .black)
        titleLabel.textColor = Palette.text
        titleLabel.numberOfLines = 2
        let updatedLabel = UILabel()
        updatedLabel.attributedText = NSAttributedString(string: document.updated.uppercased(), attributes: [
            .kern: 1.2, .font: UIFont.dancte(10, .bold), .foregroundColor: Palette.textFaint
        ])
        let summaryLabel = UILabel()
        summaryLabel.text = document.summary
        summaryLabel.font = Typo.body
        summaryLabel.textColor = Palette.textMuted
        summaryLabel.numberOfLines = 0

        let headerColumn = UIStackView(arrangedSubviews: [icon, titleLabel, updatedLabel, summaryLabel])
        headerColumn.axis = .vertical
        headerColumn.spacing = 10
        headerColumn.setCustomSpacing(14, after: icon)
        headerColumn.setCustomSpacing(16, after: updatedLabel)
        header.addSubviews(headerColumn)
        NSLayoutConstraint.activate([
            headerColumn.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 20),
            headerColumn.trailingAnchor.constraint(equalTo: header.trailingAnchor, constant: -20),
            headerColumn.topAnchor.constraint(equalTo: header.topAnchor, constant: 22),
            headerColumn.bottomAnchor.constraint(equalTo: header.bottomAnchor, constant: -22)
        ])
        scroll.add(header)

        for section in document.sections {
            scroll.add(makeSection(section))
        }

        let footer = UILabel()
        footer.text = "Dancte · \(document.title) · \(document.updated)"
        footer.font = Typo.caption
        footer.textColor = Palette.textFaint
        footer.textAlignment = .center
        scroll.add(footer)
    }

    private func makeSection(_ section: LegalSection) -> UIView {
        let heading = UILabel()
        heading.text = section.heading
        heading.font = .dancte(17, .bold)
        heading.textColor = document.accent
        heading.numberOfLines = 0

        let body = UILabel()
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 4.5
        body.attributedText = NSAttributedString(string: section.body, attributes: [
            .font: UIFont.dancte(14.5, .regular),
            .foregroundColor: Palette.textMuted,
            .paragraphStyle: paragraph
        ])
        body.numberOfLines = 0

        let column = UIStackView(arrangedSubviews: [heading, body])
        column.axis = .vertical
        column.spacing = 8
        return column
    }
}

// MARK: - Consent footer

/// The fixed footer required under every sign-in surface.
final class LegalConsentFooter: UIView {

    var onOpen: ((LegalDocument) -> Void)?

    private let label = UILabel()

    init(alignment: NSTextAlignment = .center) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        label.numberOfLines = 0
        label.textAlignment = alignment
        label.translatesAutoresizingMaskIntoConstraints = false
        label.isUserInteractionEnabled = true
        addSubview(label)
        label.pinEdges(to: self)

        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignment
        paragraph.lineSpacing = 3

        let base: [NSAttributedString.Key: Any] = [
            .font: UIFont.dancte(12, .medium),
            .foregroundColor: Palette.textFaint,
            .paragraphStyle: paragraph
        ]

        let text = NSMutableAttributedString(string: "By continuing you agree with ", attributes: base)
        text.append(highlight("Terms of Service"))
        text.append(NSAttributedString(string: " & ", attributes: base))
        text.append(highlight("Privacy Policy"))
        text.append(NSAttributedString(string: "\n", attributes: base))
        text.append(highlight("EULA"))

        let full = text.string as NSString
        text.addAttribute(.link, value: "dancte://terms", range: full.range(of: "Terms of Service"))
        text.addAttribute(.link, value: "dancte://privacy", range: full.range(of: "Privacy Policy"))
        text.addAttribute(.link, value: "dancte://eula", range: full.range(of: "EULA"))

        label.attributedText = text
        label.accessibilityLabel = "By continuing you agree with Terms of Service and Privacy Policy, and the EULA."

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        label.addGestureRecognizer(tap)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func highlight(_ value: String) -> NSAttributedString {
        NSAttributedString(string: value, attributes: [
            .font: UIFont.dancte(12, .heavy),
            .foregroundColor: Palette.lime,
            .underlineStyle: NSUnderlineStyle.single.rawValue,
            .underlineColor: Palette.lime.withAlphaComponent(0.5)
        ])
    }

    @objc private func handleTap(_ recognizer: UITapGestureRecognizer) {
        guard let range = textRange(at: recognizer.location(in: label)) else { return }
        let value = (label.attributedText?.string as NSString?)?.substring(with: range) ?? ""
        Haptics.tap()
        switch value {
        case "Terms of Service": onOpen?(.terms)
        case "Privacy Policy":   onOpen?(.privacy)
        case "EULA":             onOpen?(.eula)
        default: break
        }
    }

    /// Hit-tests which of the three links (if any) sits under the touch.
    private func textRange(at point: CGPoint) -> NSRange? {
        guard let attributed = label.attributedText else { return nil }
        let textStorage = NSTextStorage(attributedString: attributed)
        let layoutManager = NSLayoutManager()
        let textContainer = NSTextContainer(size: CGSize(width: label.bounds.width, height: .greatestFiniteMagnitude))
        textContainer.lineFragmentPadding = 0
        textContainer.maximumNumberOfLines = label.numberOfLines
        textContainer.lineBreakMode = label.lineBreakMode
        layoutManager.addTextContainer(textContainer)
        textStorage.addLayoutManager(layoutManager)

        let index = layoutManager.characterIndex(for: point, in: textContainer,
                                                 fractionOfDistanceBetweenInsertionPoints: nil)
        guard index < attributed.length else { return nil }
        let string = attributed.string as NSString
        for candidate in ["Terms of Service", "Privacy Policy", "EULA"] {
            let range = string.range(of: candidate)
            if range.location != NSNotFound, NSLocationInRange(index, range) { return range }
        }
        return nil
    }
}
