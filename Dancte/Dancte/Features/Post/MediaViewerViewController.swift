import UIKit

/// Full-screen media viewer. Multiple attachments page horizontally, and any
/// clip inside plays to full screen with its own transport controls.
final class MediaViewerViewController: UIViewController {

    private let media: [MediaItem]
    private let startIndex: Int
    private let authorTitle: String

    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = 0
        layout.minimumInteritemSpacing = 0
        let view = UICollectionView(frame: .zero, collectionViewLayout: layout)
        view.isPagingEnabled = true
        view.showsHorizontalScrollIndicator = false
        view.backgroundColor = .clear
        view.register(MediaPageCell.self, forCellWithReuseIdentifier: MediaPageCell.reuseID)
        view.dataSource = self
        view.delegate = self
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let closeButton = IconButton(symbol: "xmark", size: 40, background: .glass, tint: .white, pointSize: 14)
    private let titleLabel = UILabel()
    private let counterLabel = UILabel()
    private let pageDots = UIStackView(axis: .horizontal, spacing: 6)

    init(media: [MediaItem], startIndex: Int, title: String) {
        self.media = media
        self.startIndex = max(0, min(startIndex, max(0, media.count - 1)))
        self.authorTitle = title
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .fullScreen
        modalTransitionStyle = .crossDissolve
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var prefersStatusBarHidden: Bool { true }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Palette.ink

        let backdrop = StudioBackdropView()
        view.addSubviews(backdrop)
        backdrop.pinEdges(to: view)

        view.addSubviews(collectionView, closeButton)
        NSLayoutConstraint.activate([
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            closeButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: Metric.gutter),
            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 6)
        ])

        titleLabel.text = authorTitle
        titleLabel.font = .dancte(15, .bold)
        titleLabel.textColor = .white
        counterLabel.font = .dancteMono(12.5, .bold)
        counterLabel.textColor = UIColor.white.withAlphaComponent(0.7)
        counterLabel.textAlignment = .right

        let header = UIStackView(arrangedSubviews: [titleLabel, UIView(), counterLabel])
        header.axis = .horizontal
        header.spacing = 10
        header.translatesAutoresizingMaskIntoConstraints = false
        // The viewer chrome sits inside a scrim so it reads over any frame.
        let bar = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
        bar.layer.cornerRadius = 22
        bar.layer.cornerCurve = .continuous
        bar.clipsToBounds = true
        bar.translatesAutoresizingMaskIntoConstraints = false

        view.addSubviews(bar)
        // An effect view only accepts children on its content view.
        bar.contentView.addSubviews(header)
        NSLayoutConstraint.activate([
            bar.leadingAnchor.constraint(equalTo: closeButton.trailingAnchor, constant: 12),
            bar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -Metric.gutter),
            bar.centerYAnchor.constraint(equalTo: closeButton.centerYAnchor),
            bar.heightAnchor.constraint(equalToConstant: 44),

            header.leadingAnchor.constraint(equalTo: bar.leadingAnchor, constant: 16),
            header.trailingAnchor.constraint(equalTo: bar.trailingAnchor, constant: -16),
            header.centerYAnchor.constraint(equalTo: bar.centerYAnchor)
        ])

        if media.count > 1 {
            buildDots()
        }

        closeButton.onTap = { [weak self] in
            self?.dismiss(animated: true)
        }

        collectionView.layoutIfNeeded()
        collectionView.setContentOffset(CGPoint(x: CGFloat(startIndex) * collectionView.bounds.width, y: 0), animated: false)
        updateChrome()
    }

    private func buildDots() {
        pageDots.translatesAutoresizingMaskIntoConstraints = false
        view.addSubviews(pageDots)
        NSLayoutConstraint.activate([
            pageDots.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            pageDots.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -18),
            pageDots.heightAnchor.constraint(equalToConstant: 8)
        ])
        for _ in media {
            let dot = UIView()
            dot.translatesAutoresizingMaskIntoConstraints = false
            dot.layer.cornerRadius = 3
            dot.widthAnchor.constraint(equalToConstant: 6).isActive = true
            dot.heightAnchor.constraint(equalToConstant: 6).isActive = true
            pageDots.addArrangedSubview(dot)
        }
        refreshDots()
    }

    private func refreshDots() {
        let current = Int(round(collectionView.contentOffset.x / max(1, collectionView.bounds.width)))
        for (index, dot) in pageDots.arrangedSubviews.enumerated() {
            dot.backgroundColor = index == current ? Palette.lime : UIColor.white.withAlphaComponent(0.28)
        }
    }

    private func updateChrome() {
        let current = Int(round(collectionView.contentOffset.x / max(1, collectionView.bounds.width)))
        counterLabel.text = "\(min(current + 1, media.count)) / \(media.count)"
        for case let cell as MediaPageCell in collectionView.visibleCells {
            cell.setActive(cell.index == current)
        }
    }
}

extension MediaViewerViewController: UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        media.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: MediaPageCell.reuseID, for: indexPath)
        if let page = cell as? MediaPageCell {
            page.configure(item: media[indexPath.item], index: indexPath.item, accent: Palette.lime)
        }
        return cell
    }

    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        collectionView.bounds.size
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        refreshDots()
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        updateChrome()
    }
}

// MARK: - Page cell

final class MediaPageCell: UICollectionViewCell {

    static let reuseID = "MediaPageCell"

    private let artwork = ArtworkView(cornerRadius: 0, contentMode: .scaleAspectFit)
    private let controls = ClipControlBar(showsTitles: false)
    private let centerPlay = IconButton(symbol: "play.fill", size: 68, background: .gradient(Grad.lime), pointSize: 26)
    private(set) var index: Int = 0
    private var player: ClipPlayer?
    private var item: MediaItem?

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.backgroundColor = .clear

        artwork.showsScrim = false
        contentView.addSubviews(artwork, centerPlay, controls)
        NSLayoutConstraint.activate([
            artwork.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            artwork.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            artwork.topAnchor.constraint(equalTo: contentView.topAnchor),
            artwork.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            centerPlay.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            centerPlay.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),

            controls.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: Metric.gutter),
            controls.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -Metric.gutter),
            controls.bottomAnchor.constraint(equalTo: contentView.safeAreaLayoutGuide.bottomAnchor, constant: -34)
        ])

        centerPlay.onTap = { [weak self] in self?.player?.play() }
        controls.onTogglePlay = { [weak self] in self?.player?.toggle() }
        controls.onSkip = { [weak self] delta in self?.player?.skip(delta) }
        controls.onScrub = { [weak self] value in self?.player?.seek(to: value) }
        controls.onScrubEnd = { [weak self] value in self?.player?.seek(to: value) }

        let tap = UITapGestureRecognizer(target: self, action: #selector(togglePlay))
        tap.delegate = ControlExemptTapDelegate.exclusive
        artwork.addGestureRecognizer(tap)
        artwork.isUserInteractionEnabled = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(item: MediaItem, index: Int, accent: UIColor) {
        self.item = item
        self.index = index
        artwork.setMediaArtwork(item)

        let isVideo = item.kind == .video
        controls.isHidden = !isVideo
        centerPlay.isHidden = !isVideo
        controls.setAccent(accent)

        if isVideo {
            let player = ClipPlayer(assetName: item.assetName, duration: item.duration, hostView: artwork)
            player.onUpdate = { [weak self] time, playing in
                self?.controls.update(time: time, playing: playing)
                self?.centerPlay.isHidden = playing
            }
            player.onFinish = { [weak self] in self?.centerPlay.isHidden = false }
            player.onDurationReady = { [weak self] seconds in
                self?.controls.setDuration(seconds)
            }
            controls.configure(title: "", subtitle: "",
                               duration: VideoDuration.known(item.assetName) ?? item.duration)
            self.player = player
        } else {
            player = nil
        }
    }

    func setActive(_ active: Bool) {
        guard item?.kind == .video else { return }
        if !active { player?.pause() }
    }

    @objc private func togglePlay() {
        guard item?.kind == .video else { return }
        player?.toggle()
        centerPlay.isHidden = player?.isPlaying ?? false
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        player?.pause()
        player = nil
    }
}
