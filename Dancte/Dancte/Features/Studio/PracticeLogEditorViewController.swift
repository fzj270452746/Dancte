import PhotosUI
import UIKit

/// Record a practice session — or edit and delete one you already logged.
///
/// This is the single most important screen in Dancte: everything else in the
/// Studio is derived from what gets entered here.
final class PracticeLogEditorViewController: UIViewController, OwnsNavigationBar {

    var prefersOwnHeader: Bool { true }

    private let existing: PracticeSession?

    private let scroll = ContentColumn(spacing: 20, gutter: 0)
    private let navBar = UIView()
    private let dayScroller = UIScrollView()
    private let dayStack = UIStackView(axis: .horizontal, spacing: 8)
    private let stepper = MinuteStepper(minutes: 60, tint: Palette.lime)
    private let stylePicker = StylePickerView(selected: [.hipHop], allowsMultiple: false)
    private let intensity = IntensitySelector(value: 3, tint: Palette.blaze)
    private let moodRow = MoodRowView(selected: .steady)
    private let drillFlow = TagFlowView(accent: Palette.cyan)
    private let drillField = FieldInput(label: nil, placeholder: "Add a drill you ran", symbol: "plus")
    private let notesCard = SurfaceCard(colors: [Palette.surfaceHi.withAlphaComponent(0.7), Palette.surface.withAlphaComponent(0.7)],
                                        radius: 22, border: Palette.stroke)
    private let notesView = UITextView()
    private let summaryLabel = UILabel()
    private let saveButton = PillButton("Save Session", symbol: "checkmark", style: .primary)
    private let coverTile = UIView()
    private let coverArt = ArtworkView(cornerRadius: 20)
    private let coverLabel = UILabel()
    private var coverName: String?
    private var coverHeight: NSLayoutConstraint!
    private let planStack = UIStackView(axis: .horizontal, spacing: 8)

    private var selectedDay: Date
    private var customDrills: Set<String> = []
    private var selectedPlanID: String?
    /// Set when the live timer hands over a finished workout to top up.
    private var prefill: PracticeDraft?

    init(session: PracticeSession? = nil, prefill: PracticeDraft? = nil) {
        self.existing = session
        self.prefill = prefill
        self.selectedDay = (session?.date ?? prefill?.date ?? Date()).startOfDay
        self.selectedPlanID = session?.planID ?? prefill?.planID
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
        scroll.setTopPadding(12)
        scroll.setBottomPadding(50)
        scroll.keyboardDismissMode = .interactive
        view.addSubviews(scroll)
        NSLayoutConstraint.activate([
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scroll.topAnchor.constraint(equalTo: navBar.bottomAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        buildDayPicker()
        buildMinutes()
        buildStyle()
        buildPlan()
        buildIntensity()
        buildMood()
        buildDrills()
        buildNotes()
        buildCover()
        buildSummary()
        buildSaveRow()

        if let existing {
            load(existing)
        } else {
            applyPrefill()
            refreshDrills()
            refreshPlanChips()
        }
        installKeyboardDismissOnTap()
        observeKeyboard()
    }

    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

    // MARK: - Chrome

    private func buildNav() {
        navBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubviews(navBar)

        let title = UILabel()
        title.text = existing == nil ? "Log a Session" : "Edit Session"
        title.font = .dancte(17, .bold)
        title.textColor = Palette.text
        title.translatesAutoresizingMaskIntoConstraints = false
        navBar.addSubviews(title)

        let close = IconButton(symbol: existing == nil ? "xmark" : "chevron.down", size: 40, background: .glass, pointSize: 14)
        close.onTap = { [weak self] in self?.dismissEditor() }
        navBar.addSubviews(close)

        NSLayoutConstraint.activate([
            navBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            navBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            navBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            navBar.heightAnchor.constraint(equalToConstant: 52),

            close.leadingAnchor.constraint(equalTo: navBar.leadingAnchor, constant: Metric.gutter),
            close.bottomAnchor.constraint(equalTo: navBar.bottomAnchor, constant: -4),

            title.centerXAnchor.constraint(equalTo: navBar.centerXAnchor),
            title.centerYAnchor.constraint(equalTo: close.centerYAnchor)
        ])

        if existing != nil {
            let delete = IconButton(symbol: "trash", size: 40, background: .glass, tint: Palette.magenta, pointSize: 15)
            delete.onTap = { [weak self] in self?.confirmDelete() }
            navBar.addSubviews(delete)
            NSLayoutConstraint.activate([
                delete.trailingAnchor.constraint(equalTo: navBar.trailingAnchor, constant: -Metric.gutter),
                delete.centerYAnchor.constraint(equalTo: close.centerYAnchor)
            ])
        }
    }

    private func section(_ eyebrow: String, _ title: String, hint: String? = nil) -> UIView {
        let header = SectionHeader(eyebrow: eyebrow, title: title)
        guard let hint else { return header }
        let label = UILabel()
        label.text = hint
        label.font = Typo.caption
        label.textColor = Palette.textFaint
        label.numberOfLines = 0
        let column = UIStackView(arrangedSubviews: [header, label])
        column.axis = .vertical
        column.spacing = 6
        return column
    }

    // MARK: - Sections

    private func buildDayPicker() {
        let column = UIStackView(axis: .vertical, spacing: 14)
        column.addArrangedSubview(section("When", "Day", hint: "Pick the day you trained — you can backfill the last two weeks."))
        scroll.add(column.gutterPadded())

        dayStack.translatesAutoresizingMaskIntoConstraints = false
        dayScroller.translatesAutoresizingMaskIntoConstraints = false
        dayScroller.showsHorizontalScrollIndicator = false
        dayScroller.contentInset = UIEdgeInsets(top: 0, left: Metric.gutter, bottom: 0, right: Metric.gutter)
        dayScroller.addSubviews(dayStack)
        NSLayoutConstraint.activate([
            dayStack.leadingAnchor.constraint(equalTo: dayScroller.contentLayoutGuide.leadingAnchor),
            dayStack.trailingAnchor.constraint(equalTo: dayScroller.contentLayoutGuide.trailingAnchor),
            dayStack.topAnchor.constraint(equalTo: dayScroller.contentLayoutGuide.topAnchor),
            dayStack.bottomAnchor.constraint(equalTo: dayScroller.contentLayoutGuide.bottomAnchor),
            dayStack.heightAnchor.constraint(equalTo: dayScroller.frameLayoutGuide.heightAnchor),
            dayScroller.heightAnchor.constraint(equalToConstant: 72)
        ])
        scroll.add(dayScroller)
        rebuildDays()
    }

    private func rebuildDays() {
        dayStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"

        for offset in (0..<14).reversed() {
            let day = Date().startOfDay.adding(days: -offset)
            let control = UIControl()
            control.translatesAutoresizingMaskIntoConstraints = false
            let isOn = Calendar.current.isDate(day, inSameDayAs: selectedDay)
            control.backgroundColor = isOn ? Palette.lime : Palette.surfaceHi.withAlphaComponent(0.6)
            control.layer.cornerRadius = 18
            control.layer.cornerCurve = .continuous
            control.layer.borderWidth = 1
            control.layer.borderColor = (isOn ? Palette.lime : Palette.stroke).cgColor
            control.accessibilityLabel = day.dayLabel

            let weekday = UILabel()
            weekday.text = formatter.string(from: day).uppercased()
            weekday.font = .dancte(10, .bold)
            weekday.textColor = isOn ? Palette.ink : Palette.textFaint
            weekday.textAlignment = .center
            weekday.translatesAutoresizingMaskIntoConstraints = false

            let number = UILabel()
            number.text = "\(Calendar.current.component(.day, from: day))"
            number.font = .dancte(19, .black)
            number.textColor = isOn ? Palette.ink : Palette.text
            number.textAlignment = .center
            number.translatesAutoresizingMaskIntoConstraints = false

            control.addSubviews(weekday, number)
            NSLayoutConstraint.activate([
                control.widthAnchor.constraint(equalToConstant: 54),
                weekday.centerXAnchor.constraint(equalTo: control.centerXAnchor),
                weekday.topAnchor.constraint(equalTo: control.topAnchor, constant: 12),
                number.centerXAnchor.constraint(equalTo: control.centerXAnchor),
                number.topAnchor.constraint(equalTo: weekday.bottomAnchor, constant: 2)
            ])

            let targetDay = day
            control.addAction(UIAction { [weak self] _ in
                Haptics.selection()
                self?.selectedDay = targetDay
                self?.rebuildDays()
                self?.refreshSummary()
            }, for: .touchUpInside)
            dayStack.addArrangedSubview(control)
        }

        // Open on today rather than two weeks ago.
        dayScroller.layoutIfNeeded()
        dayScroller.setContentOffset(CGPoint(x: max(0, dayScroller.contentSize.width - dayScroller.bounds.width), y: 0), animated: false)
    }

    private func buildMinutes() {
        let column = UIStackView(axis: .vertical, spacing: 14)
        column.addArrangedSubview(section("How long", "Time on the floor"))
        scroll.add(column.gutterPadded())

        stepper.onChange = { [weak self] _ in self?.refreshSummary() }
        scroll.add(stepper.gutterPadded())
    }

    private func buildStyle() {
        let column = UIStackView(axis: .vertical, spacing: 14)
        column.addArrangedSubview(section("What you trained", "Style", hint: "Pick the primary style for this session."))
        column.addArrangedSubview(stylePicker)
        scroll.add(column.gutterPadded())

        stylePicker.onToggle = { [weak self] _ in
            guard let self else { return }
            self.refreshDrills()
            self.refreshSummary()
        }
    }

    private func buildPlan() {
        let column = UIStackView(axis: .vertical, spacing: 14)
        column.addArrangedSubview(section("Counts towards", "Plan",
                                          hint: "Attribute this session to one of your plans, or leave it unattributed."))
        planStack.translatesAutoresizingMaskIntoConstraints = false
        let scroller = UIScrollView()
        scroller.translatesAutoresizingMaskIntoConstraints = false
        scroller.showsHorizontalScrollIndicator = false
        scroller.contentInset = UIEdgeInsets(top: 0, left: Metric.gutter, bottom: 0, right: Metric.gutter)
        scroller.addSubviews(planStack)
        NSLayoutConstraint.activate([
            planStack.leadingAnchor.constraint(equalTo: scroller.contentLayoutGuide.leadingAnchor),
            planStack.trailingAnchor.constraint(equalTo: scroller.contentLayoutGuide.trailingAnchor),
            planStack.topAnchor.constraint(equalTo: scroller.contentLayoutGuide.topAnchor),
            planStack.bottomAnchor.constraint(equalTo: scroller.contentLayoutGuide.bottomAnchor),
            planStack.heightAnchor.constraint(equalTo: scroller.frameLayoutGuide.heightAnchor),
            scroller.heightAnchor.constraint(equalToConstant: 40)
        ])
        scroll.add(column.gutterPadded())
        scroll.add(scroller)
    }

    private func refreshPlanChips() {
        planStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        // Nothing to attribute to when no plan is running — hide the whole row.
        let plans = store.activePlans
        guard !plans.isEmpty else { return }

        let style = stylePicker.selected.first ?? .freestyle
        if selectedPlanID == nil || !plans.contains(where: { $0.id == selectedPlanID }) {
            selectedPlanID = plans.first { $0.style == style }?.id
        }

        let none = ChipView(text: "No plan", accent: Palette.textMuted)
        none.isOn = selectedPlanID == nil
        none.onTap = { [weak self] in
            self?.selectedPlanID = nil
            self?.refreshPlanChips()
        }
        planStack.addArrangedSubview(none)

        for plan in plans {
            let chip = ChipView(text: plan.title, symbol: "target", accent: plan.style.accent)
            chip.isOn = plan.id == selectedPlanID
            chip.onTap = { [weak self] in
                self?.selectedPlanID = plan.id
                self?.refreshPlanChips()
            }
            planStack.addArrangedSubview(chip)
        }
    }

    /// Tops the editor up from a workout the live timer just finished.
    private func applyPrefill() {
        guard let prefill else { return }
        stepper.setValue(prefill.minutes)
        stylePicker.setSelection([prefill.style])
        customDrills.formUnion(prefill.drills)
    }

    private func buildIntensity() {
        let column = UIStackView(axis: .vertical, spacing: 14)
        column.addArrangedSubview(section("How hard", "Intensity", hint: "1 is a light technical session, 5 is everything you had."))
        column.addArrangedSubview(intensity)
        scroll.add(column.gutterPadded())
        intensity.onChange = { [weak self] _ in self?.refreshSummary() }
    }

    private func buildMood() {
        let column = UIStackView(arrangedSubviews: [section("How it felt", "Mood"), moodRow])
        column.axis = .vertical
        column.spacing = 12
        scroll.add(column.gutterPadded())
    }

    private func buildDrills() {
        let column = UIStackView(axis: .vertical, spacing: 14)
        column.addArrangedSubview(section("What you drilled", "Moves", hint: "Tap the moves you ran. Anything you log counts a rep against your skill tree."))
        column.addArrangedSubview(drillField)
        column.addArrangedSubview(drillFlow)
        scroll.add(column.gutterPadded())

        drillField.onReturn = { [weak self] in self?.commitDrill() }
        drillFlow.onToggle = { [weak self] tag in
            guard let self else { return }
            if self.drillFlow.selected.contains(tag) {
                self.customDrills.insert(tag)
            } else {
                self.customDrills.remove(tag)
            }
            self.refreshSummary()
        }
    }

    private func refreshDrills() {
        let style = stylePicker.selected.first ?? .freestyle
        var tags = style.commonDrills
        for drill in customDrills where !tags.contains(drill) { tags.append(drill) }
        drillFlow.setAccent(style.accent)
        drillFlow.apply(tags: tags, selected: customDrills)
    }

    private func commitDrill() {
        let value = drillField.text.trimmed
        guard !value.isEmpty else { return }
        customDrills.insert(value)
        drillField.text = ""
        refreshDrills()
        Haptics.tap()
        refreshSummary()
    }

    private func buildNotes() {
        let column = UIStackView(axis: .vertical, spacing: 14)
        column.addArrangedSubview(section("Anything else", "Notes"))

        notesView.backgroundColor = .clear
        notesView.font = .dancte(15, .regular)
        notesView.textColor = Palette.text
        notesView.tintColor = Palette.lime
        notesView.isScrollEnabled = false
        notesView.textContainerInset = UIEdgeInsets(top: 12, left: 10, bottom: 12, right: 10)
        notesView.translatesAutoresizingMaskIntoConstraints = false
        notesCard.addSubviews(notesView)
        NSLayoutConstraint.activate([
            notesCard.heightAnchor.constraint(greaterThanOrEqualToConstant: 118),
            notesView.leadingAnchor.constraint(equalTo: notesCard.leadingAnchor, constant: 6),
            notesView.trailingAnchor.constraint(equalTo: notesCard.trailingAnchor, constant: -6),
            notesView.topAnchor.constraint(equalTo: notesCard.topAnchor, constant: 4),
            notesView.bottomAnchor.constraint(equalTo: notesCard.bottomAnchor, constant: -4)
        ])
        column.addArrangedSubview(notesCard)
        scroll.add(column.gutterPadded())
    }

    private func buildCover() {
        let column = UIStackView(axis: .vertical, spacing: 14)
        column.addArrangedSubview(section("Optional", "Session photo", hint: "Attach one photo of the session. Tap again to remove it."))

        coverArt.setArtwork(assetName: "session_cover_placeholder", seed: "session-cover")
        coverArt.roundCorners(20)
        coverArt.isUserInteractionEnabled = false

        coverLabel.font = .dancte(13, .bold)
        coverLabel.textColor = Palette.textMuted
        coverLabel.text = "Add a photo"
        coverLabel.textAlignment = .center
        coverLabel.translatesAutoresizingMaskIntoConstraints = false

        let plus = UIImageView(image: UIImage(systemName: "camera.fill", withConfiguration: UIImage.SymbolConfiguration(pointSize: 20, weight: .bold)))
        plus.tintColor = Palette.lime
        plus.translatesAutoresizingMaskIntoConstraints = false

        coverTile.translatesAutoresizingMaskIntoConstraints = false
        coverTile.layer.cornerRadius = 20
        coverTile.layer.cornerCurve = .continuous
        coverTile.clipsToBounds = true
        coverTile.addSubviews(coverArt, plus, coverLabel)
        coverHeight = coverTile.heightAnchor.constraint(equalToConstant: 150)

        NSLayoutConstraint.activate([
            coverHeight,
            coverTile.widthAnchor.constraint(equalTo: coverTile.heightAnchor, multiplier: 1.4),
            coverArt.leadingAnchor.constraint(equalTo: coverTile.leadingAnchor),
            coverArt.trailingAnchor.constraint(equalTo: coverTile.trailingAnchor),
            coverArt.topAnchor.constraint(equalTo: coverTile.topAnchor),
            coverArt.bottomAnchor.constraint(equalTo: coverTile.bottomAnchor),
            plus.centerXAnchor.constraint(equalTo: coverTile.centerXAnchor),
            plus.centerYAnchor.constraint(equalTo: coverTile.centerYAnchor, constant: -12),
            coverLabel.centerXAnchor.constraint(equalTo: coverTile.centerXAnchor),
            coverLabel.topAnchor.constraint(equalTo: plus.bottomAnchor, constant: 8)
        ])
        coverTile.isHidden = true

        let button = PillButton("Attach a Photo", symbol: "photo.fill", style: .outline, height: 48)
        button.onTap = { [weak self] in self?.presentCoverPicker() }

        column.addArrangedSubview(button)
        column.addArrangedSubview(coverTile)
        scroll.add(column.gutterPadded())
    }

    private func buildSummary() {
        summaryLabel.font = .dancteMono(13, .bold)
        summaryLabel.textColor = Palette.lime
        summaryLabel.textAlignment = .center
        summaryLabel.numberOfLines = 0

        let card = SurfaceCard(colors: [Palette.lime.withAlphaComponent(0.12), Palette.surface],
                               radius: 20, border: Palette.lime.withAlphaComponent(0.32))
        card.addSubviews(summaryLabel)
        NSLayoutConstraint.activate([
            summaryLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            summaryLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            summaryLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            summaryLabel.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -14)
        ])
        scroll.add(card.gutterPadded())
    }

    private func buildSaveRow() {
        saveButton.onTap = { [weak self] in self?.save() }
        scroll.add(saveButton.gutterPadded())
    }

    // MARK: - State

    private func load(_ session: PracticeSession) {
        selectedDay = session.date.startOfDay
        rebuildDays()
        stepper.setValue(session.minutes)
        stylePicker.setSelected(session.style)
        intensity.setValue(session.intensity)
        moodRow.select(session.mood)
        customDrills = Set(session.drills)
        refreshDrills()
        selectedPlanID = session.planID
        refreshPlanChips()
        notesView.text = session.notes
        if let media = session.mediaName {
            coverName = media
            coverArt.setArtwork(assetName: media, seed: media)
            coverLabel.text = "Session photo attached"
            coverTile.isHidden = false
        }
        refreshSummary()
    }

    private func refreshSummary() {
        let style = stylePicker.selected.first ?? .freestyle
        let drills = drillFlow.selected.count
        summaryLabel.text = "\(stepper.minutes) min · \(style.title) · Intensity \(intensity.value) · \(moodRow.selected.title)"
            + (drills > 0 ? " · \(drills) drill\(drills == 1 ? "" : "s")" : "")
    }

    private func presentCoverPicker() {
        if coverName != nil {
            confirm(title: "Remove the session photo?",
                    message: nil,
                    confirmTitle: "Remove Photo") { [weak self] in
                guard let self else { return }
                if let name = self.coverName { MediaStore.remove(name) }
                self.coverName = nil
                self.coverTile.isHidden = true
                self.coverLabel.text = "Add a photo"
            }
            return
        }
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.selectionLimit = 1
        configuration.filter = .images
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = self
        present(picker, animated: true)
    }

    private func save() {
        view.endEditing(true)
        let style = stylePicker.selected.first ?? .freestyle
        let drills = Array(drillFlow.selected)

        if var session = existing {
            session.date = selectedDay
            session.minutes = stepper.minutes
            session.style = style
            session.intensity = intensity.value
            session.mood = moodRow.selected
            session.drills = drills
            session.notes = notesView.text.trimmed
            session.mediaName = coverName
            session.planID = selectedPlanID
            store.updateSession(session)
            Haptics.success()
            dismiss(animated: true) { Toast.success("Session updated") }
        } else {
            store.logSession(date: selectedDay,
                             minutes: stepper.minutes,
                             style: style,
                             intensity: intensity.value,
                             mood: moodRow.selected,
                             drills: drills,
                             notes: notesView.text.trimmed,
                             mediaName: coverName,
                             planID: selectedPlanID)
            Haptics.success()
            let streak = store.stats.currentStreak
            dismiss(animated: true) {
                Toast.success("Session logged", detail: "\(self.stepper.minutes) minutes · \(streak) day streak")
            }
        }
    }

    private func confirmDelete() {
        guard let existing else { return }
        confirm(title: "Delete this session?",
                message: "It will be removed from your history and your streaks will recalculate.",
                confirmTitle: "Delete Session") {
            store.deleteSession(existing.id)
            Toast.show("Session deleted")
            self.dismiss(animated: true)
        }
    }

    private func dismissEditor() {
        let hasContent = !notesView.text.trimmed.isEmpty || !customDrills.isEmpty
        guard existing == nil, hasContent else {
            dismiss(animated: true)
            return
        }
        confirm(title: "Discard this session?",
                message: "Nothing has been saved yet.",
                confirmTitle: "Discard") { [weak self] in
            self?.dismiss(animated: true)
        }
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

extension PracticeLogEditorViewController: PHPickerViewControllerDelegate {

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard let provider = results.first?.itemProvider, provider.canLoadObject(ofClass: UIImage.self) else { return }
        provider.loadObject(ofClass: UIImage.self) { [weak self] object, _ in
            guard let image = object as? UIImage else { return }
            let name = "session_\(UUID().uuidString.prefix(10))"
            let stored = MediaStore.save(image: image.downscaled(), name: name) ?? name
            DispatchQueue.main.async {
                self?.coverName = stored
                self?.coverArt.setArtwork(assetName: stored, seed: stored)
                self?.coverLabel.text = "Session photo attached"
                self?.coverTile.isHidden = false
                Haptics.success()
            }
        }
    }
}
