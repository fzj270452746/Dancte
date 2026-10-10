import UIKit

/// The preset programme library. Starting one writes a real plan with today's
/// date and stocks the skill tree with the moves it is built around.
final class PlanTemplatesViewController: UIViewController {

    private let scroll = ContentColumn(spacing: 18, gutter: 0)
    private let listStack = UIStackView(axis: .vertical, spacing: 14)

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Palette.ink

        let backdrop = StudioBackdropView()
        view.addSubviews(backdrop)
        backdrop.pinEdges(to: view)

        installBrandBackButton()
        styleNavigationBar(title: "Programmes", subtitle: "Start from a plan that already works")

        scroll.setTopPadding(12)
        scroll.setBottomPadding(40)
        view.addSubviews(scroll)
        scroll.pinEdges(to: view)

        let intro = UILabel()
        intro.text = "Every programme sets a weekly minute target, a session count and the moves it is built around. You can edit any of it after you start."
        intro.font = Typo.body
        intro.textColor = Palette.textMuted
        intro.numberOfLines = 0
        scroll.add(intro.gutterPadded())

        scroll.add(listStack.gutterPadded())
        build()
    }

    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

    private func build() {
        for template in SeedData.planTemplates {
            listStack.addArrangedSubview(makeCard(template))
        }
    }

    private func makeCard(_ template: PracticePlanTemplate) -> UIView {
        let accent = template.style.accent
        let card = SurfaceCard(colors: [accent.withAlphaComponent(0.16), Palette.surface],
                               radius: 26, border: accent.withAlphaComponent(0.38))

        let eyebrow = UILabel()
        eyebrow.attributedText = NSAttributedString(
            string: "\(template.style.title.uppercased()) · \(template.weeks) WEEKS",
            attributes: [.kern: 1.4, .font: UIFont.dancte(9.5, .bold), .foregroundColor: accent]
        )

        let title = UILabel()
        title.text = template.title
        title.font = .dancte(21, .black)
        title.textColor = Palette.text
        title.numberOfLines = 2

        let blurb = UILabel()
        blurb.text = template.blurb
        blurb.font = Typo.callout
        blurb.textColor = Palette.textMuted
        blurb.numberOfLines = 2

        let metrics = UILabel()
        metrics.attributedText = NSAttributedString(
            string: "\(template.sessionsPerWeek) sessions · \(Format.minutes(template.minutesPerWeek)) a week",
            attributes: [.font: UIFont.dancteMono(11.5, .semibold), .foregroundColor: Palette.textFaint]
        )

        let drillFlow = TagFlowView(tags: template.drills, selected: [], accent: accent)
        drillFlow.onToggle = { _ in }

        let focus = UILabel()
        focus.text = template.focus
        focus.font = Typo.caption
        focus.textColor = Palette.textFaint
        focus.numberOfLines = 3

        let start = PillButton("Start This Plan", symbol: "play.fill", style: .primary, height: 48)
        start.onTap = { [weak self] in self?.start(template) }

        let column = UIStackView(arrangedSubviews: [eyebrow, title, blurb, metrics, drillFlow, focus, start])
        column.axis = .vertical
        column.spacing = 8
        column.setCustomSpacing(12, after: title)
        column.setCustomSpacing(14, after: metrics)
        column.setCustomSpacing(14, after: drillFlow)

        card.addSubviews(column)
        NSLayoutConstraint.activate([
            column.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 18),
            column.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -18),
            column.topAnchor.constraint(equalTo: card.topAnchor, constant: 18),
            column.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -18)
        ])
        return card
    }

    private func start(_ template: PracticePlanTemplate) {
        let plan = store.startPlan(from: template)
        Haptics.success()
        Toast.success("\(plan.title) started", detail: "\(plan.totalWeeks) weeks · \(Format.minutes(plan.weeklyMinuteTarget)) a week")
        navigationController?.pushViewController(PlanDetailViewController(planID: plan.id), animated: true)
    }
}
