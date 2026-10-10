import UIKit

/// Everything running right now, everything that has finished, and the way in
/// to the preset programmes.
final class PlanCenterViewController: UIViewController {

    private let scroll = ContentColumn(spacing: 22, gutter: 0)
    private let runningStack = UIStackView(axis: .vertical, spacing: 12)
    private let finishedStack = UIStackView(axis: .vertical, spacing: 10)

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Palette.ink

        let backdrop = StudioBackdropView()
        view.addSubviews(backdrop)
        backdrop.pinEdges(to: view)

        installBrandBackButton()
        styleNavigationBar(title: "Plans", subtitle: "What you're chasing right now")

        let newButton = UIBarButtonItem(image: UIImage(systemName: "plus"),
                                        style: .plain,
                                        target: self,
                                        action: #selector(presentNewPlan))
        newButton.tintColor = Palette.lime
        navigationItem.rightBarButtonItem = newButton

        scroll.setTopPadding(12)
        scroll.setBottomPadding(40)
        view.addSubviews(scroll)
        scroll.pinEdges(to: view)

        buildTemplatesEntry()
        scroll.add(makeSection(eyebrow: "On the clock", title: "Running", stack: runningStack))
        scroll.add(makeSection(eyebrow: "Past programmes", title: "Finished", stack: finishedStack))

        NotificationCenter.default.addObserver(self, selector: #selector(reload),
                                               name: .danctePractice, object: nil)
        reload()
    }

    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

    private func buildTemplatesEntry() {
        let card = SurfaceCard(colors: [Palette.violet.withAlphaComponent(0.18), Palette.surface],
                               radius: 26, border: Palette.violet.withAlphaComponent(0.4))
        let icon = UIImageView(image: UIImage(systemName: "square.stack.3d.up.fill", withConfiguration:
                                                UIImage.SymbolConfiguration(pointSize: 20, weight: .bold)))
        icon.tintColor = Palette.violet

        let title = UILabel()
        title.text = "Preset programmes"
        title.font = .dancte(17, .bold)
        title.textColor = Palette.text

        let detail = UILabel()
        detail.text = "Six ready-made plans, from four weeks of fundamentals to a month on one power move."
        detail.font = Typo.caption
        detail.textColor = Palette.textMuted
        detail.numberOfLines = 2

        let text = UIStackView(arrangedSubviews: [title, detail])
        text.axis = .vertical
        text.spacing = 3

        let chevron = UIImageView(image: UIImage(systemName: "chevron.right", withConfiguration:
                                                    UIImage.SymbolConfiguration(pointSize: 13, weight: .bold)))
        chevron.tintColor = Palette.textFaint
        chevron.setContentHuggingPriority(.required, for: .horizontal)

        let row = UIStackView(arrangedSubviews: [icon, text, chevron])
        row.axis = .horizontal
        row.spacing = 14
        row.alignment = .center
        icon.setContentHuggingPriority(.required, for: .horizontal)

        card.addSubviews(row)
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 18),
            row.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -18),
            row.topAnchor.constraint(equalTo: card.topAnchor, constant: 18),
            row.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -18)
        ])

        let tap = ClosureControl { [weak self] in
            self?.navigationController?.pushViewController(PlanTemplatesViewController(), animated: true)
        }
        card.addSubviews(tap)
        tap.pinEdges(to: card)

        scroll.add(card.gutterPadded())
    }

    private func makeSection(eyebrow: String, title: String, stack: UIStackView) -> UIView {
        let header = SectionHeader(eyebrow: eyebrow, title: title)
        let column = UIStackView(arrangedSubviews: [header, stack])
        column.axis = .vertical
        column.spacing = 14
        return column.gutterPadded()
    }

    @objc private func reload() {
        runningStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        finishedStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        let running = store.activePlans
        if running.isEmpty {
            let empty = EmptyStateView(symbol: "target",
                                       title: "Nothing on the clock",
                                       message: "Start a preset programme or write your own weekly target. A plan turns practice into something you can finish.",
                                       actionTitle: "Browse templates",
                                       compact: true)
            empty.onAction = { [weak self] in
                self?.navigationController?.pushViewController(PlanTemplatesViewController(), animated: true)
            }
            runningStack.addArrangedSubview(empty)
            empty.heightAnchor.constraint(equalToConstant: 280).isActive = true
        } else {
            for plan in running {
                let card = PlanProgressCard(plan: plan)
                card.onTap = { [weak self] in self?.open(plan) }
                runningStack.addArrangedSubview(card)
            }
        }

        let finished = store.finishedPlans
        if finished.isEmpty {
            let label = UILabel()
            label.text = "No plan has run its course yet."
            label.font = Typo.caption
            label.textColor = Palette.textFaint
            finishedStack.addArrangedSubview(label)
        } else {
            for plan in finished {
                finishedStack.addArrangedSubview(makeFinishedRow(plan))
            }
        }
    }

    private func makeFinishedRow(_ plan: PracticePlan) -> UIView {
        let card = SurfaceCard(colors: Grad.card, radius: 22, border: Palette.stroke.withAlphaComponent(0.8))

        let title = UILabel()
        title.text = plan.title
        title.font = .dancte(16, .bold)
        title.textColor = Palette.text

        let detail = UILabel()
        let adherence = store.adherence(for: plan)
        detail.text = "\(plan.style.title) · \(plan.totalWeeks) weeks · \(Int(adherence * 100))% of weeks hit the target"
        detail.font = Typo.caption
        detail.textColor = Palette.textMuted

        let text = UIStackView(arrangedSubviews: [title, detail])
        text.axis = .vertical
        text.spacing = 2

        let chip = ChipView(text: "Finished", accent: Palette.textFaint, horizontalPadding: 10, fontSize: 10.5)
        chip.setContentHuggingPriority(.required, for: .horizontal)

        let row = UIStackView(arrangedSubviews: [text, chip])
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

        let tap = ClosureControl { [weak self] in self?.open(plan) }
        card.addSubviews(tap)
        tap.pinEdges(to: card)
        return card
    }

    private func open(_ plan: PracticePlan) {
        navigationController?.pushViewController(PlanDetailViewController(planID: plan.id), animated: true)
    }

    @objc private func presentNewPlan() {
        presentSheet(PracticePlanEditorViewController(plan: nil))
    }
}
