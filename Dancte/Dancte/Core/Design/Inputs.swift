import UIKit

// MARK: - Text input

/// Dancte's single text field style: dark pill, optional label, inline error.
final class FieldInput: UIView, UITextFieldDelegate {

    enum FieldKind {
        case plain, email, password, numeric
    }

    let textField = UITextField()

    private let container = UIView()
    private let errorLabel = UILabel()
    private let revealButton = UIButton(type: .system)
    private let column = UIStackView(axis: .vertical, spacing: 7)

    var onChange: ((String) -> Void)?
    var onReturn: (() -> Void)?

    var text: String {
        get { textField.text ?? "" }
        set { textField.text = newValue }
    }

    init(label: String?, placeholder: String, kind: FieldKind = .plain, symbol: String? = nil) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        container.backgroundColor = Palette.surfaceHi.withAlphaComponent(0.85)
        container.layer.cornerRadius = 18
        container.layer.cornerCurve = .continuous
        container.layer.borderWidth = 1
        container.layer.borderColor = Palette.stroke.cgColor
        container.translatesAutoresizingMaskIntoConstraints = false

        textField.font = .dancte(15.5, .medium)
        textField.textColor = Palette.text
        textField.tintColor = Palette.lime
        textField.delegate = self
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.autocorrectionType = .no
        textField.spellCheckingType = .no
        textField.attributedPlaceholder = NSAttributedString(string: placeholder, attributes: [
            .foregroundColor: Palette.textFaint,
            .font: UIFont.dancte(15.5, .regular)
        ])
        textField.addTarget(self, action: #selector(editingChanged), for: .editingChanged)
        textField.addTarget(self, action: #selector(editingBegan), for: .editingDidBegin)
        textField.addTarget(self, action: #selector(editingEnded), for: .editingDidEnd)
        textField.accessibilityLabel = label ?? placeholder

        switch kind {
        case .email:
            textField.keyboardType = .emailAddress
            textField.autocapitalizationType = .none
            textField.textContentType = .username
        case .numeric:
            textField.keyboardType = .numberPad
        case .password:
            textField.isSecureTextEntry = true
            textField.autocapitalizationType = .none
            textField.textContentType = .password
        case .plain:
            textField.autocapitalizationType = .sentences
        }

        var rowItems: [UIView] = []
        if let symbol {
            let icon = UIImageView(image: UIImage(systemName: symbol,
                                                  withConfiguration: UIImage.SymbolConfiguration(pointSize: 16, weight: .semibold)))
            icon.tintColor = Palette.textFaint
            icon.contentMode = .center
            icon.translatesAutoresizingMaskIntoConstraints = false
            icon.widthAnchor.constraint(equalToConstant: 24).isActive = true
            rowItems.append(icon)
        }
        rowItems.append(textField)

        if kind == .password {
            revealButton.setImage(UIImage(systemName: "eye",
                                          withConfiguration: UIImage.SymbolConfiguration(pointSize: 15, weight: .semibold)), for: .normal)
            revealButton.tintColor = Palette.textFaint
            revealButton.addTarget(self, action: #selector(toggleReveal), for: .touchUpInside)
            revealButton.translatesAutoresizingMaskIntoConstraints = false
            revealButton.widthAnchor.constraint(equalToConstant: 28).isActive = true
            revealButton.accessibilityLabel = "Show password"
            rowItems.append(revealButton)
        }

        let row = UIStackView(arrangedSubviews: rowItems)
        row.axis = .horizontal
        row.spacing = 10
        row.alignment = .center
        row.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(row)

        errorLabel.font = Typo.caption
        errorLabel.textColor = Palette.magenta
        errorLabel.numberOfLines = 0
        errorLabel.isHidden = true
        errorLabel.translatesAutoresizingMaskIntoConstraints = false

        if let label {
            let titleLabel = UILabel()
            titleLabel.attributedText = NSAttributedString(string: label.uppercased(), attributes: [
                .kern: 1.3, .font: UIFont.dancte(10, .bold), .foregroundColor: Palette.textFaint
            ])
            titleLabel.translatesAutoresizingMaskIntoConstraints = false
            column.addArrangedSubview(titleLabel)
        }
        column.addArrangedSubview(container)
        column.addArrangedSubview(errorLabel)
        addSubview(column)
        column.pinEdges(to: self)

        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            row.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -14),
            row.topAnchor.constraint(equalTo: container.topAnchor, constant: 15),
            row.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -15),
            container.heightAnchor.constraint(greaterThanOrEqualToConstant: 54)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    @discardableResult
    override func becomeFirstResponder() -> Bool { textField.becomeFirstResponder() }

    @discardableResult
    override func resignFirstResponder() -> Bool { textField.resignFirstResponder() }

    override var isFirstResponder: Bool { textField.isFirstResponder }

    var hasError: Bool { !errorLabel.isHidden }

    func showError(_ message: String?) {
        errorLabel.text = message
        errorLabel.isHidden = message == nil
        container.layer.borderColor = (message == nil ? Palette.stroke : Palette.magenta).cgColor
        guard message != nil else { return }
        shake()
        Haptics.error()
    }

    func setEnabled(_ enabled: Bool) {
        textField.isEnabled = enabled
        alpha = enabled ? 1 : 0.55
    }

    @objc private func editingChanged() {
        if hasError { showError(nil) }
        onChange?(text)
    }

    @objc private func editingBegan() {
        UIView.animate(withDuration: 0.2) { self.container.layer.borderColor = Palette.lime.withAlphaComponent(0.7).cgColor }
    }

    @objc private func editingEnded() {
        UIView.animate(withDuration: 0.2) { self.container.layer.borderColor = Palette.stroke.cgColor }
    }

    @objc private func toggleReveal() {
        textField.isSecureTextEntry.toggle()
        let symbol = textField.isSecureTextEntry ? "eye" : "eye.slash"
        revealButton.setImage(UIImage(systemName: symbol,
                                      withConfiguration: UIImage.SymbolConfiguration(pointSize: 15, weight: .semibold)), for: .normal)
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        onReturn?()
        return true
    }
}

// MARK: - Tag flow

/// Wrapping chip cloud used for post tags and practice drills.
final class TagFlowView: UIView {

    var onToggle: ((String) -> Void)?

    private(set) var tags: [String] = []
    private(set) var selected: Set<String> = []
    private(set) var chips: [ChipView] = []
    private let spacing: CGFloat = 8
    private var accent: UIColor
    private var measuredHeight: CGFloat = 34

    init(tags: [String] = [], selected: Set<String> = [], accent: UIColor = Palette.lime) {
        self.accent = accent
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        apply(tags: tags, selected: selected)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func setAccent(_ color: UIColor) {
        accent = color
        apply(tags: tags, selected: selected)
    }

    func apply(tags: [String], selected: Set<String>) {
        self.tags = tags
        self.selected = selected
        chips.forEach { $0.removeFromSuperview() }
        chips = tags.map { tag in
            let chip = ChipView(text: tag, accent: accent)
            chip.isOn = selected.contains(tag)
            chip.onTap = { [weak self, weak chip] in
                guard let self, let chip else { return }
                if self.selected.contains(tag) {
                    self.selected.remove(tag)
                } else {
                    self.selected.insert(tag)
                }
                chip.isOn = self.selected.contains(tag)
                self.onToggle?(tag)
            }
            addSubview(chip)
            return chip
        }
        invalidateIntrinsicContentSize()
        setNeedsLayout()
    }

    func setSelection(_ selection: Set<String>) {
        selected = selection
        for chip in chips where !selection.contains(chip.accessibilityLabel ?? "") {
            chip.isOn = false
        }
        for chip in chips where selection.contains(chip.accessibilityLabel ?? "") {
            chip.isOn = true
        }
    }

    private func layout(in width: CGFloat) -> CGFloat {
        guard width > 0 else { return 34 }
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        for chip in chips {
            let size = chip.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
            if x + size.width > width, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            chip.frame = CGRect(origin: CGPoint(x: x, y: y), size: size)
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return max(y + rowHeight, 34)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        measuredHeight = layout(in: bounds.width)
        invalidateIntrinsicContentSize()
    }

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: measuredHeight)
    }

    override func systemLayoutSizeFitting(_ targetSize: CGSize,
                                          withHorizontalFittingPriority horizontalFittingPriority: UILayoutPriority,
                                          verticalFittingPriority: UILayoutPriority) -> CGSize {
        let width = targetSize.width > 0 ? targetSize.width : bounds.width
        guard width > 0 else { return CGSize(width: 200, height: measuredHeight) }
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        for chip in chips {
            let size = chip.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
            if x + size.width > width, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: width, height: max(y + rowHeight, 34))
    }
}

// MARK: - Dance style picker

final class StylePickerView: UIView {

    var onToggle: ((DanceStyle) -> Void)?
    private(set) var selected: Set<DanceStyle> = []

    private struct Tile {
        let control: UIControl
        let icon: UIImageView
        let title: UILabel
        let blurb: UILabel
    }

    private var tiles: [DanceStyle: Tile] = [:]
    private let allowsMultiple: Bool

    init(styles: [DanceStyle] = DanceStyle.allCases, selected: Set<DanceStyle> = [], allowsMultiple: Bool = true) {
        self.allowsMultiple = allowsMultiple
        self.selected = selected
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        let rows = UIStackView(axis: .vertical, spacing: 10)
        addSubview(rows)
        rows.pinEdges(to: self)

        var pending: [UIView] = []
        for (index, style) in styles.enumerated() {
            pending.append(makeTile(for: style))
            if pending.count == 2 || index == styles.count - 1 {
                let row = UIStackView(axis: .horizontal, spacing: 10, distribution: .fillEqually)
                pending.forEach { row.addArrangedSubview($0) }
                if pending.count < 2 { row.addArrangedSubview(UIView()) }
                rows.addArrangedSubview(row)
                pending = []
            }
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func makeTile(for style: DanceStyle) -> UIControl {
        let control = UIControl()
        control.translatesAutoresizingMaskIntoConstraints = false
        control.layer.cornerRadius = 20
        control.layer.cornerCurve = .continuous
        control.layer.borderWidth = 1
        control.accessibilityLabel = style.title
        control.accessibilityTraits = .button

        let icon = UIImageView(image: UIImage(systemName: style.symbol,
                                              withConfiguration: UIImage.SymbolConfiguration(pointSize: 18, weight: .bold)))
        icon.contentMode = .center
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.isUserInteractionEnabled = false

        let title = UILabel()
        title.text = style.title
        title.font = .dancte(15, .bold)

        let blurb = UILabel()
        blurb.text = style.blurb
        blurb.font = .dancte(10.5, .medium)
        blurb.numberOfLines = 2

        let text = UIStackView(arrangedSubviews: [title, blurb])
        text.axis = .vertical
        text.spacing = 1
        text.translatesAutoresizingMaskIntoConstraints = false
        text.isUserInteractionEnabled = false

        control.addSubviews(icon, text)
        NSLayoutConstraint.activate([
            control.heightAnchor.constraint(equalToConstant: 82),
            icon.leadingAnchor.constraint(equalTo: control.leadingAnchor, constant: 14),
            icon.centerYAnchor.constraint(equalTo: control.centerYAnchor),
            text.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 10),
            text.trailingAnchor.constraint(equalTo: control.trailingAnchor, constant: -10),
            text.centerYAnchor.constraint(equalTo: control.centerYAnchor)
        ])

        let tile = Tile(control: control, icon: icon, title: title, blurb: blurb)
        tiles[style] = tile
        control.addAction(UIAction { [weak self] _ in self?.toggle(style) }, for: .touchUpInside)
        paint(style, tile: tile, isOn: selected.contains(style))
        return control
    }

    private func toggle(_ style: DanceStyle) {
        Haptics.selection()
        if allowsMultiple {
            if selected.contains(style) { selected.remove(style) } else { selected.insert(style) }
        } else {
            selected = selected.contains(style) ? [] : [style]
        }
        for (candidate, tile) in tiles {
            paint(candidate, tile: tile, isOn: selected.contains(candidate))
        }
        onToggle?(style)
    }

    func setSelected(_ style: DanceStyle) {
        selected = [style]
        for (candidate, tile) in tiles {
            paint(candidate, tile: tile, isOn: candidate == style)
        }
    }

    func setSelection(_ styles: Set<DanceStyle>) {
        selected = styles
        for (candidate, tile) in tiles {
            paint(candidate, tile: tile, isOn: styles.contains(candidate))
        }
    }

    private func paint(_ style: DanceStyle, tile: Tile, isOn: Bool) {
        if isOn {
            tile.control.backgroundColor = style.accent.withAlphaComponent(0.18)
            tile.control.layer.borderColor = style.accent.cgColor
            tile.icon.tintColor = style.accent
            tile.title.textColor = Palette.text
            tile.blurb.textColor = Palette.textMuted
        } else {
            tile.control.backgroundColor = Palette.surfaceHi.withAlphaComponent(0.6)
            tile.control.layer.borderColor = Palette.stroke.cgColor
            tile.icon.tintColor = Palette.textFaint
            tile.title.textColor = Palette.textMuted
            tile.blurb.textColor = Palette.textFaint
        }
    }
}

// MARK: - Intensity selector

final class IntensitySelector: UIView {

    var onChange: ((Int) -> Void)?
    private(set) var value: Int

    private var bars: [(control: UIControl, label: UILabel)] = []
    private var tint: UIColor

    init(value: Int = 3, tint: UIColor = Palette.blaze) {
        self.value = min(5, max(1, value))
        self.tint = tint
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        let stack = UIStackView(axis: .horizontal, spacing: 8, distribution: .fillEqually)
        addSubview(stack)
        stack.pinEdges(to: self)

        for index in 1...5 {
            let bar = UIControl()
            bar.translatesAutoresizingMaskIntoConstraints = false
            bar.layer.cornerRadius = 12
            bar.layer.cornerCurve = .continuous
            bar.layer.borderWidth = 1
            bar.accessibilityLabel = "Intensity \(index) of 5"
            bar.heightAnchor.constraint(equalToConstant: 46).isActive = true

            let label = UILabel()
            label.text = "\(index)"
            label.font = .dancte(15, .heavy)
            label.textAlignment = .center
            label.isUserInteractionEnabled = false
            label.translatesAutoresizingMaskIntoConstraints = false
            bar.addSubview(label)
            NSLayoutConstraint.activate([
                label.centerXAnchor.constraint(equalTo: bar.centerXAnchor),
                label.centerYAnchor.constraint(equalTo: bar.centerYAnchor)
            ])
            bar.addAction(UIAction { [weak self] _ in
                Haptics.selection()
                self?.value = index
                self?.refresh()
                self?.onChange?(index)
            }, for: .touchUpInside)

            bars.append((bar, label))
            stack.addArrangedSubview(bar)
        }
        refresh()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func setTint(_ color: UIColor) {
        tint = color
        refresh()
    }

    func setValue(_ value: Int) {
        self.value = min(5, max(1, value))
        refresh()
    }

    private func refresh() {
        for (index, bar) in bars.enumerated() {
            let isOn = index + 1 <= value
            bar.control.backgroundColor = isOn ? tint.withAlphaComponent(0.22) : Palette.surfaceHi.withAlphaComponent(0.5)
            bar.control.layer.borderColor = (isOn ? tint : Palette.stroke).cgColor
            bar.label.textColor = isOn ? tint : Palette.textFaint
        }
    }
}

// MARK: - Minute stepper

final class MinuteStepper: UIView {

    var onChange: ((Int) -> Void)?
    private(set) var minutes: Int

    private let valueLabel = UILabel()
    private let slider = UISlider()
    private var tint: UIColor

    init(minutes: Int = 60, tint: UIColor = Palette.lime) {
        self.minutes = min(300, max(5, minutes))
        self.tint = tint
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        let minus = IconButton(symbol: "minus", size: 46, background: .glass, tint: Palette.text, pointSize: 16)
        let plus = IconButton(symbol: "plus", size: 46, background: .gradient(Grad.forColor(tint)), pointSize: 16)

        valueLabel.font = .dancteMono(38, .black)
        valueLabel.textColor = Palette.text
        valueLabel.textAlignment = .center

        let unit = UILabel()
        unit.attributedText = NSAttributedString(string: "MINUTES", attributes: [
            .kern: 1.6, .font: UIFont.dancte(10, .bold), .foregroundColor: Palette.textFaint
        ])
        unit.textAlignment = .center

        let valueColumn = UIStackView(arrangedSubviews: [valueLabel, unit])
        valueColumn.axis = .vertical
        valueColumn.spacing = 0
        valueColumn.alignment = .center

        let row = UIStackView(arrangedSubviews: [minus, valueColumn, plus])
        row.axis = .horizontal
        row.spacing = 18
        row.alignment = .center
        minus.setContentHuggingPriority(.required, for: .horizontal)
        plus.setContentHuggingPriority(.required, for: .horizontal)
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)

        slider.minimumValue = 5
        slider.maximumValue = 300
        slider.value = Float(self.minutes)
        slider.minimumTrackTintColor = tint
        slider.maximumTrackTintColor = Palette.stroke
        slider.translatesAutoresizingMaskIntoConstraints = false
        slider.addTarget(self, action: #selector(sliderChanged), for: .valueChanged)
        addSubview(slider)

        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: leadingAnchor),
            row.trailingAnchor.constraint(equalTo: trailingAnchor),
            row.topAnchor.constraint(equalTo: topAnchor),
            slider.topAnchor.constraint(equalTo: row.bottomAnchor, constant: 18),
            slider.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
            slider.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
            slider.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        minus.onTap = { [weak self] in self?.bump(-5) }
        plus.onTap = { [weak self] in self?.bump(5) }
        refreshThumb()
        refresh()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func setValue(_ value: Int, notify: Bool = false) {
        minutes = min(300, max(5, value))
        slider.value = Float(minutes)
        refresh()
        if notify { onChange?(minutes) }
    }

    func setTint(_ color: UIColor) {
        tint = color
        slider.minimumTrackTintColor = color
        refreshThumb()
    }

    private func bump(_ delta: Int) {
        minutes = min(300, max(5, minutes + delta))
        slider.value = Float(minutes)
        refresh()
        onChange?(minutes)
    }

    @objc private func sliderChanged() {
        minutes = min(300, max(5, Int(slider.value.rounded())))
        refresh()
        onChange?(minutes)
    }

    private func refresh() {
        valueLabel.text = "\(minutes)"
        valueLabel.pulse(1.04, duration: 0.1)
    }

    private func refreshThumb() {
        let size = CGSize(width: 26, height: 26)
        let thumb = UIGraphicsImageRenderer(size: size).image { context in
            let ctx = context.cgContext
            ctx.setFillColor(UIColor.white.cgColor)
            ctx.fillEllipse(in: CGRect(origin: .zero, size: size))
            ctx.setFillColor(self.tint.cgColor)
            ctx.fillEllipse(in: CGRect(x: 5, y: 5, width: 16, height: 16))
        }
        slider.setThumbImage(thumb, for: .normal)
    }
}

// MARK: - Mood row

final class MoodRowView: UIView {

    var onSelect: ((PracticeMood) -> Void)?
    private(set) var selected: PracticeMood

    private var chips: [PracticeMood: ChipView] = [:]

    init(selected: PracticeMood = .steady) {
        self.selected = selected
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        let scroll = UIScrollView()
        scroll.showsHorizontalScrollIndicator = false
        scroll.translatesAutoresizingMaskIntoConstraints = false
        addSubview(scroll)
        scroll.pinEdges(to: self)

        let stack = UIStackView(axis: .horizontal, spacing: 8)
        stack.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(stack)

        for mood in PracticeMood.allCases {
            let chip = ChipView(text: mood.title, symbol: mood.symbol, accent: mood.accent)
            chip.isOn = mood == selected
            chip.onTap = { [weak self] in
                guard let self else { return }
                self.selected = mood
                for (candidate, chip) in self.chips { chip.isOn = candidate == mood }
                self.onSelect?(mood)
            }
            chips[mood] = chip
            stack.addArrangedSubview(chip)
        }

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
            stack.heightAnchor.constraint(equalTo: scroll.frameLayoutGuide.heightAnchor),
            heightAnchor.constraint(equalToConstant: 40)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func select(_ mood: PracticeMood) {
        selected = mood
        for (candidate, chip) in chips { chip.isOn = candidate == mood }
    }
}

// MARK: - Search field

final class SearchField: UIView {

    var onChange: ((String) -> Void)?

    private let field = UITextField()

    init(placeholder: String = "Search") {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = Palette.surfaceHi.withAlphaComponent(0.8)
        layer.cornerRadius = 20
        layer.cornerCurve = .continuous
        layer.borderWidth = 1
        layer.borderColor = Palette.stroke.cgColor

        let icon = UIImageView(image: UIImage(systemName: "magnifyingglass",
                                              withConfiguration: UIImage.SymbolConfiguration(pointSize: 15, weight: .bold)))
        icon.tintColor = Palette.textFaint
        icon.contentMode = .center
        icon.setContentHuggingPriority(.required, for: .horizontal)
        icon.setContentCompressionResistancePriority(.required, for: .horizontal)
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.widthAnchor.constraint(equalToConstant: 18).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 18).isActive = true

        field.font = .dancte(15.5, .medium)
        field.textColor = Palette.text
        field.tintColor = Palette.lime
        field.attributedPlaceholder = NSAttributedString(string: placeholder, attributes: [
            .foregroundColor: Palette.textFaint,
            .font: UIFont.dancte(15.5, .regular)
        ])
        field.translatesAutoresizingMaskIntoConstraints = false
        field.autocorrectionType = .no
        field.addTarget(self, action: #selector(changed), for: .editingChanged)

        addSubviews(icon, field)
        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 44),
            icon.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 15),
            icon.centerYAnchor.constraint(equalTo: centerYAnchor),
            field.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 10),
            field.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            field.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    var text: String { field.text ?? "" }

    @objc private func changed() { onChange?(text) }

    override func becomeFirstResponder() -> Bool { field.becomeFirstResponder() }
}
