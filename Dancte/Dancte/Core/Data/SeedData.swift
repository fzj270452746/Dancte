import Foundation

struct SeedContent {
    var users: [User] = []
    var posts: [Post] = []
    var comments: [Comment] = []
    var spotlight: [DanceVideo] = []
    var gifts: [Gift] = []
    var conversations: [Conversation] = []
    var accounts: [Account] = []
    var libraries: [String: Library] = [:]
    /// user id -> that account's starting training log
    var practiceLogs: [String: PracticeLog] = [:]
}

/// Builds the studio the app opens into. Every identifier is stable so the
/// seeded library (likes, saves, friends) still lines up across launches.
enum SeedData {

    static let demoHandle = "dance"
    static let demoSecret = "123456"

    /// Ready-made programmes offered in the plan library. Static content — a
    /// template is never stored, only the plan it spawns.
    static let planTemplates: [PracticePlanTemplate] = [
        PracticePlanTemplate(id: "tpl_foundation",
                             title: "Foundation Builder",
                             style: .breaking,
                             weeks: 4,
                             sessionsPerWeek: 4,
                             minutesPerWeek: 240,
                             focus: "Own top rock, the six step and a dependable baby freeze before chasing power.",
                             blurb: "Four weeks of fundamentals for dancers new to breaking.",
                             drills: ["Top Rock", "Six Step", "Baby Freeze", "Chair Freeze"]),
        PracticePlanTemplate(id: "tpl_windmill",
                             title: "Windmill in 30 Days",
                             style: .breaking,
                             weeks: 4,
                             sessionsPerWeek: 5,
                             minutesPerWeek: 300,
                             focus: "Thirty days of rotation work, exit drills and the conditioning to hold it.",
                             blurb: "One month, one power move, no detours.",
                             drills: ["Windmill", "Backspin", "Swipe", "Baby Freeze"]),
        PracticePlanTemplate(id: "tpl_pocket",
                             title: "Pocket & Groove",
                             style: .hipHop,
                             weeks: 6,
                             sessionsPerWeek: 3,
                             minutesPerWeek: 150,
                             focus: "Sit in the pocket at 78–90 BPM before adding speed or size.",
                             blurb: "Deepen the bounce and stop rushing the beat.",
                             drills: ["Bounce Groove", "Rock Steady", "Party Rock", "Running Man"]),
        PracticePlanTemplate(id: "tpl_footwork",
                             title: "Footwork Endurance",
                             style: .house,
                             weeks: 4,
                             sessionsPerWeek: 4,
                             minutesPerWeek: 200,
                             focus: "Hold clean footwork for three straight minutes without losing the groove.",
                             blurb: "Build the legs and lungs for long house sets.",
                             drills: ["Shuffle", "Jacking", "Loose Legs", "Cross Step"]),
        PracticePlanTemplate(id: "tpl_pop",
                             title: "Pop Lab",
                             style: .popping,
                             weeks: 4,
                             sessionsPerWeek: 3,
                             minutesPerWeek: 165,
                             focus: "Isolate the hit until the pop lands exactly on the beat, every beat.",
                             blurb: "Four weeks of texture, control and clean hits.",
                             drills: ["The Pop", "Wave", "Ticking", "Robot"]),
        PracticePlanTemplate(id: "tpl_battle",
                             title: "Battle Prep",
                             style: .krump,
                             weeks: 3,
                             sessionsPerWeek: 4,
                             minutesPerWeek: 180,
                             focus: "Three rounds at full energy with nothing saved. Build the stamina to hold character.",
                             blurb: "Sharpen a three-round set for the next jam.",
                             drills: ["Chest Pop", "Bucket", "Stomp", "Character"])
    ]

    static func build() -> SeedContent {
        var content = SeedContent()
        let now = Date()

        // MARK: People

        let people: [(id: String, handle: String, name: String, avatar: String, city: String, crew: String, styles: [DanceStyle], followers: Int, following: Int, posts: Int, verified: Bool, bio: String)] = [
            // The signed-in dancer starts with no follows and no followers in
            // either direction: both counts only ever move because somebody
            // actually followed somebody, so the numbers on the profile are real.
            ("u_me", demoHandle, "Dance", "avatar_me", "Los Angeles, US", "Open Floor Collective", [.hipHop, .breaking, .freestyle], 0, 0, 1, false,
             "Logging every session. Chasing a clean windmill and a deeper groove. Open floor, always."),

            ("u_maya", "wave.maya", "Maya Okafor", "avatar_maya", "Brooklyn, US", "Concrete Bloom", [.breaking, .hipHop], 48_200, 610, 4, true,
             "B-girl. Windmills, freezes, and long nights in the lab. Crew: Concrete Bloom."),

            ("u_rin", "rin.flux", "Rin Takahashi", "avatar_rin", "Osaka, JP", "Flux Unit", [.popping, .tutting], 31_540, 288, 3, true,
             "Popper. Obsessed with texture, waves and the space between beats."),

            ("u_dre", "dre.krump", "Andre Silva", "avatar_dre", "Lisbon, PT", "Sons of Rage", [.krump, .freestyle], 22_870, 401, 2, false,
             "Krump is therapy. Chest pops, buckets, and honesty."),

            ("u_lex", "lex.lock", "Lexa Novak", "avatar_lex", "Berlin, DE", "Funky Mechanism", [.locking, .waacking], 19_340, 355, 2, true,
             "Locker. Points sharp, soul sharper. Funky Mechanism since 2016."),

            ("u_juno", "juno.house", "Juno Adeyemi", "avatar_juno", "London, UK", "Night Bus", [.house, .litefeet], 27_600, 512, 2, true,
             "House head. Jacking on the 4, footwork on the 1."),

            ("u_kai", "kai.tutt", "Kai Nguyen", "avatar_kai", "Toronto, CA", "Grid Theory", [.tutting, .popping], 14_020, 190, 1, false,
             "Angles, digits, geometry. Grid Theory."),

            ("u_sol", "sol.waack", "Sol Marín", "avatar_sol", "Barcelona, ES", "Punk Armada", [.waacking, .jazzFunk], 16_780, 240, 1, false,
             "Waacking with drama. Arms up, chin higher."),

            ("u_tee", "tee.lite", "Tiana Brooks", "avatar_tee", "Atlanta, US", "Quick Step", [.litefeet, .hipHop], 12_450, 330, 1, false,
             "Litefeet. Get-downs, hat tricks and speed."),

            ("u_nyx", "nyx.funk", "Nyx Laurent", "avatar_nyx", "Paris, FR", "Velvet Riot", [.jazzFunk, .house], 21_300, 402, 2, true,
             "Choreographer. Sharp lines, soft landing. Velvet Riot."),

            ("u_ronin", "coach.ronin", "Ronin Vega", "avatar_ronin", "Seoul, KR", "Dancte Studio", [.breaking, .freestyle], 132_000, 88, 0, true,
             "Breaking coach on Dancte. Twenty years on the floor, still drilling basics."),

            ("u_ember", "coach.ember", "Ember Cole", "avatar_ember", "Chicago, US", "Dancte Studio", [.hipHop, .house], 98_400, 74, 1, true,
             "Hip-Hop coach on Dancte. Groove first, tricks later.")
        ]

        content.users = people.map { person in
            User(id: person.id,
                 handle: person.handle,
                 displayName: person.name,
                 avatarName: person.avatar,
                 bio: person.bio,
                 city: person.city,
                 crew: person.crew,
                 styles: person.styles,
                 followerCount: person.followers,
                 followingCount: person.following,
                 postCount: person.posts,
                 isVerified: person.verified,
                 joinedAt: now.adding(days: -person.followers % 900 - 60))
        }

        content.accounts = [Account(id: "acc_demo",
                                    userID: "u_me",
                                    handle: demoHandle,
                                    secret: demoSecret,
                                    provider: .password,
                                    createdAt: now.adding(days: -420))]

        // MARK: Spotlight clips

        content.spotlight = [
            DanceVideo(id: "v_01", title: "Windmill to Baby Freeze",
                       subtitle: "Thread the transition without touching down",
                       coachID: "u_ronin", style: .breaking, level: .intermediate,
                       duration: 372, assetName: "clip_spotlight_01", posterName: "poster_spotlight_01",
                       viewCount: 184_300, likeCount: 12_840),
            DanceVideo(id: "v_02", title: "The Pop, Explained",
                       subtitle: "Isolate the muscle, then release on the beat",
                       coachID: "u_rin", style: .popping, level: .beginner,
                       duration: 428, assetName: "clip_spotlight_02", posterName: "poster_spotlight_02",
                       viewCount: 121_900, likeCount: 9_420),
            DanceVideo(id: "v_03", title: "Chest Pop Fundamentals",
                       subtitle: "Build the hit, keep the character",
                       coachID: "u_dre", style: .krump, level: .beginner,
                       duration: 295, assetName: "clip_spotlight_03", posterName: "poster_spotlight_03",
                       viewCount: 96_750, likeCount: 7_210),
            DanceVideo(id: "v_04", title: "House Footwork Drills",
                       subtitle: "Six drills that fix your shuffle",
                       coachID: "u_juno", style: .house, level: .intermediate,
                       duration: 512, assetName: "clip_spotlight_04", posterName: "poster_spotlight_04",
                       viewCount: 143_100, likeCount: 10_030),
            DanceVideo(id: "v_05", title: "Locking: Points & Locks",
                       subtitle: "The two moves that define the style",
                       coachID: "u_lex", style: .locking, level: .beginner,
                       duration: 336, assetName: "clip_spotlight_05", posterName: "poster_spotlight_05",
                       viewCount: 88_640, likeCount: 6_580)
        ]

        // MARK: Gifts

        let giftSeed: [(String, String, String, Int)] = [
            ("patch", "Crew Patch", "Rep the set", 0),
            ("mixtape", "Mixtape", "Share the sound", 1),
            ("cap", "Fresh Cap", "Never a bad hair day", 2),
            ("kicks", "Box Fresh Kicks", "Crispy soles only", 3),
            ("boombox", "Boombox", "Turn the block up", 4),
            ("trophy", "Battle Trophy", "Winner takes the floor", 5),
            ("crown", "The Crown", "King of the circle", 6)
        ]

        content.gifts = giftSeed.enumerated().map { index, item in
            Gift(id: item.0,
                 name: item.1,
                 tagline: item.2,
                 tier: item.3,
                 assetName: "gift_\(item.0)",
                 accentIndex: index)
        }

        // MARK: Posts

        /// Only the media that actually shipped is listed. A key with no file
        /// behind it is dropped, so a post shows its real footage and nothing
        /// stands in for the frames that were never delivered. A post that
        /// carries art named after another shoot passes the keys in `assets`.
        func media(_ postID: String, images: Int, video: Bool, aspect: CGFloat = 0.8,
                   duration: Double = 0, assets: [String] = []) -> [MediaItem] {
            if video {
                guard Assets.hasVideo("clip_\(postID)") else { return [] }
                return [MediaItem(id: "\(postID)_m1", kind: .video,
                                  assetName: "clip_\(postID)", duration: duration, aspect: 0.75,
                                  caption: "Session clip")]
            }
            let names = assets.isEmpty
                ? (1...max(1, images)).map { "media_\(postID)_\($0)" }
                : assets
            return names.enumerated().map { offset, name in
                MediaItem(id: "\(postID)_m\(offset + 1)", kind: .image,
                          assetName: name,
                          aspect: (offset + 1).isMultiple(of: 3) ? 1.0 : aspect,
                          caption: "")
            }.filter { Assets.hasImage($0.assetName) }
        }

        let postSeed: [(id: String, author: String, text: String, tags: [String], style: DanceStyle?, hoursAgo: Double, likes: Int, media: [MediaItem])] = [
            ("p_01", "u_maya",
             "Three weeks on the same transition and it finally clicked tonight. Windmill straight into a baby freeze — no hands, no hop. The trick was slowing the second rotation down instead of muscling it.",
             ["breaking", "windmill", "freeze", "drills"], .breaking, 3, 1_284, media("p_01", images: 0, video: true, duration: 46)),

            ("p_02", "u_rin",
             "Hot take: your pop is late, not weak. Record yourself at half speed and you'll see the hit landing after the snare instead of on it. Fixed mine in one session.",
             ["popping", "technique", "tips"], .popping, 7, 862, []),

            ("p_03", "u_dre",
             "Session 40 of the year. Two hours of chest pops and buckets until my ribs hurt in a good way. Krump is the only place I get to be completely honest.",
             ["krump", "consistency", "training"], .krump, 11, 733, media("p_03", images: 3, video: false)),

            ("p_04", "u_juno",
             "New drill set for the shuffle. Four bars, one move per bar, no freestyle allowed until the fourth pass. My feet hate me and my footwork has never been cleaner.",
             ["house", "footwork", "drill"], .house, 19, 1_042, media("p_04", images: 0, video: true, duration: 62)),

            ("p_05", "u_lex",
             "Locking workshop recap. We spent ninety minutes on points alone and it was the best class I've taught all year. Precision is the flex.",
             ["locking", "workshop", "berlin"], .locking, 26, 596, media("p_05", images: 2, video: false)),

            ("p_06", "u_kai",
             "Grid study no. 12. Six frames, one continuous shape. Tutting is just slow maths with your hands.",
             ["tutting", "geometry", "study"], .tutting, 33, 421, media("p_06", images: 6, video: false)),

            ("p_07", "u_sol",
             "Punk Armada rehearsal. We built this whole phrase around one whistle and it turned into the loudest two minutes of the set. Arms up, chin higher.",
             ["waacking", "rehearsal", "crew"], .waacking, 40, 688, media("p_07", images: 0, video: true, duration: 78)),

            ("p_08", "u_tee",
             "Litefeet lab. Hat trick into a get-down, then straight back up on the horn. Speed is easy — landing it on beat is the whole job.",
             ["litefeet", "getdown", "speed"], .litefeet, 52, 512, media("p_08", images: 1, video: false)),

            ("p_09", "u_nyx",
             "Velvet Riot dropped the new phrase tonight. Nine counts, three formations, zero margin for a late arm. Sharp lines, soft landing.",
             ["jazzfunk", "choreography", "paris"], .jazzFunk, 61, 907, media("p_09", images: 0, video: true, duration: 55)),

            ("p_10", "u_nyx",
             "Battle recap from the weekend. Watch the footwork in the second round — that's what years of drilling the basics buys you. Precision wins battles.",
             ["breaking", "battle", "recap"], .breaking, 70, 2_310, media("p_10", images: 1, video: false)),

            ("p_11", "u_ember",
             "Reminder for everyone in this week's groove class: stop counting and start listening. If you can talk while you dance, you're not dancing yet.",
             ["hiphop", "groove", "class"], .hipHop, 82, 1_455, []),

            ("p_12", "u_maya",
             "Studio at 1am hits different. Empty room, one speaker, two hours of top rock. This is the part nobody posts about.",
             ["breaking", "toprock", "studio", "late night"], .breaking, 96, 1_766,
             media("p_12", images: 1, video: false, assets: ["media_p_05_1"])),

            ("p_13", "u_rin",
             "Wave practice, slowed to 70%. If you can't do it slow you don't own it yet.",
             ["popping", "wave", "practice"], .popping, 110, 634, media("p_13", images: 0, video: true, duration: 38)),

            ("p_14", "u_me",
             "One month into keeping an actual practice log. Turns out I was training four hours a week and telling myself it was ten. Numbers don't lie.",
             ["practice", "consistency", "progress"], .hipHop, 130, 248, media("p_14", images: 2, video: false))
        ]

        content.posts = postSeed.map { seed in
            Post(id: seed.id,
                 authorID: seed.author,
                 text: seed.text,
                 media: seed.media,
                 tags: seed.tags,
                 style: seed.style,
                 createdAt: now.addingTimeInterval(-seed.hoursAgo * 3_600),
                 likeCount: seed.likes,
                 isSeeded: true)
        }

        // MARK: Comments

        let commentSeed: [String: [String]] = [
            "p_01": ["The slow rotation tip just fixed my windmill. Thank you.",
                     "Clean freeze, no hop at all. Respect.",
                     "How long were you drilling before the transition stopped fighting you?",
                     "This is the video I needed three months ago.",
                     "Baby freeze entry is so underrated. Great work."],
            "p_02": ["Half speed recording genuinely changed everything for me.",
                     "Late pop is the realest note I've read all week.",
                     "Sending this to my whole crew right now.",
                     "So it's a timing problem not a strength problem. Mind blown."],
            "p_03": ["Session 40 is serious. Consistency is the whole game.",
                     "Ribs hurting in a good way is the krump signature.",
                     "Bucket work is brutal and you make it look easy."],
            "p_04": ["The no-freestyle rule is genius. Stealing this drill set.",
                     "Four bars, one move. Simple and it hurts.",
                     "My shuffle needed exactly this, thank you.",
                     "Saved. Running this tomorrow morning.",
                     "Footwork looking sharp in the clip."],
            "p_05": ["Ninety minutes on points sounds like heaven honestly.",
                     "Precision is the flex. Putting that on a shirt.",
                     "Best locking class I've taken, and I wasn't even there."],
            "p_06": ["Slow maths with your hands is the perfect description.",
                     "Frame six is unreal. How do you keep the line so clean?",
                     "Grid Theory stays undefeated.",
                     "I've been trying this shape for a month and you made it look easy."],
            "p_07": ["The whistle turning into two minutes of chaos. Love it.",
                     "Arms up chin higher. Screaming.",
                     "This is the loudest thing I've seen all week.",
                     "Punk Armada never misses."],
            "p_08": ["Landing on the horn is the whole job. Preach.",
                     "Speed is easy, timing is everything. Facts.",
                     "The get-down at the end is so clean."],
            "p_09": ["Nine counts and three formations is a lot of trust. Beautiful.",
                     "Sharp lines, soft landing. That's the whole method.",
                     "Velvet Riot is on another level this season.",
                     "Watching the arm timing on loop.",
                     "How long did this take to clean?"],
            "p_10": ["Basics win battles. Every single time.",
                     "That second round footwork is a masterclass.",
                     "Twenty years showing in eight seconds.",
                     "Saving this for my students.",
                     "The control is unreal."],
            "p_11": ["If you can talk while you dance you're not dancing yet. Ouch. Needed it.",
                     "Groove first. Always.",
                     "This is going on my studio wall.",
                     "Best advice I've gotten from a teacher all year."],
            "p_12": ["The 1am studio sessions are where it actually happens.",
                     "Nobody posts the empty room. Respect for showing it.",
                     "Two hours of top rock sounds like a perfect night.",
                     "This is the realest post on here."],
            "p_13": ["If you can't do it slow you don't own it. Framing this.",
                     "70% is where the truth lives.",
                     "Wave looking butter smooth.",
                     "Trying this tonight."],
            "p_14": ["The log doesn't lie. Best decision I made this year too.",
                     "Four hours feeling like ten is so real.",
                     "One month in and already seeing it. Keep going.",
                     "Tracking changed my training completely."]
        ]

        let commenters = ["u_maya", "u_rin", "u_dre", "u_lex", "u_juno", "u_kai", "u_sol", "u_tee", "u_nyx", "u_ember", "u_ronin"]

        for (postOffset, entry) in commentSeed.sorted(by: { $0.key < $1.key }).enumerated() {
            let postID = entry.key
            let postAuthor = content.posts.first { $0.id == postID }?.authorID
            for (index, text) in entry.value.enumerated() {
                var author = commenters[(postOffset * 3 + index) % commenters.count]
                if author == postAuthor { author = commenters[(postOffset * 3 + index + 4) % commenters.count] }
                content.comments.append(Comment(
                    id: "\(postID)_c\(index + 1)",
                    postID: postID,
                    authorID: author,
                    text: text,
                    createdAt: now.addingTimeInterval(-Double(3 - min(2, index)) * 1_800 - Double(index * 640)),
                    likeCount: max(0, 42 - index * 9)
                ))
            }
        }

        // MARK: Practice history
        //
        // Six consecutive days ending today so the streak reads as live, then a
        // realistic eight-week tail with rest days built in.

        // The tail leans on the two styles the demo dancer is running plans in,
        // the way a real log would — the rest of the styles still show up often
        // enough to keep the breakdown interesting.
        let tailPool: [DanceStyle] = [.breaking, .hipHop, .breaking, .hipHop, .breaking, .hipHop,
                                      .breaking, .hipHop, .popping, .house, .locking]
        let drillPool: [DanceStyle: [String]] = DanceStyle.allCases.reduce(into: [:]) { result, style in
            result[style] = style.commonDrills
        }
        let moods = PracticeMood.allCases
        let notesPool = [
            "Felt heavy for the first twenty minutes, then it opened up.",
            "Metronome at 82 BPM the whole way. Slower than usual but cleaner.",
            "Filmed the last three rounds — the difference is obvious now.",
            "Legs were dead from yesterday so I kept it technical instead of athletic.",
            "Best session this week. Everything landed on the snare.",
            "Worked the same four counts for an hour. Boring and necessary.",
            "Trained with the crew, which always pushes the intensity up.",
            "Short session before class. Kept it to fundamentals only.",
            ""
        ]

        /// Sessions logged against the two plans the demo dancer is running, so
        /// plan progress reads as real work rather than an empty target.
        func planID(for style: DanceStyle) -> String? {
            switch style {
            case .breaking: return "pl_01"
            case .hipHop:   return "pl_02"
            default:        return nil
            }
        }

        // The session covers that actually shipped. Sessions rotate through
        // them, and a session gets no cover at all when the set is absent.
        let sessionCovers = (1...9)
            .map { String(format: "clip_session_%02d", $0) }
            .filter { Assets.hasImage($0) }

        func sessionCover(for index: Int) -> String? {
            guard index.isMultiple(of: 7), !sessionCovers.isEmpty else { return nil }
            return sessionCovers[(index / 7) % sessionCovers.count]
        }

        func makeSession(index: Int, day: Date, minutes: Int, style: DanceStyle, intensity: Int) -> PracticeSession {
            var generator = SeededRandom(seed: "session-\(index)")
            let drills = drillPool[style] ?? ["Fundamentals"]
            let chosen = Array(drills.shuffled(using: &generator).prefix(generator.int(1...3)))
            let startedAt = day.addingTimeInterval(Double(generator.int(7...20)) * 3_600)
            return PracticeSession(
                id: String(format: "s_seed_%03d", index),
                date: startedAt,
                minutes: minutes,
                style: style,
                intensity: intensity,
                mood: generator.pick(moods),
                drills: chosen,
                notes: generator.pick(notesPool),
                mediaName: sessionCover(for: index),
                createdAt: startedAt,
                planID: planID(for: style)
            )
        }

        var log = PracticeLog()
        var sessionIndex = 0

        // Live streak: the last six days, today included. The styles are hand
        // picked so the two running plans both have work against them this week.
        let streakMinutes = [72, 55, 90, 45, 68, 84]
        let streakIntensity = [4, 3, 5, 3, 4, 4]
        let streakStyles: [DanceStyle] = [.popping, .breaking, .hipHop, .breaking, .hipHop, .breaking]
        for offset in (0..<6).reversed() {
            let day = now.adding(days: -offset).startOfDay
            sessionIndex += 1
            log.sessions.append(makeSession(
                index: sessionIndex,
                day: day,
                minutes: streakMinutes[5 - offset],
                style: streakStyles[sessionIndex - 1],
                intensity: streakIntensity[5 - offset]
            ))
        }

        // Eight-week tail with rest days.
        for offset in 6...62 {
            var dayRandom = SeededRandom(seed: "day-\(offset)")
            if dayRandom.int(0...9) < 3 { continue }   // rest day
            let day = now.adding(days: -offset).startOfDay
            sessionIndex += 1
            let doubles = dayRandom.int(0...9) < 2
            log.sessions.append(makeSession(
                index: sessionIndex,
                day: day,
                minutes: dayRandom.int(35...115),
                style: dayRandom.pick(tailPool),
                intensity: dayRandom.int(2...5)
            ))
            if doubles {
                sessionIndex += 1
                log.sessions.append(makeSession(
                    index: sessionIndex,
                    day: day,
                    minutes: dayRandom.int(20...55),
                    style: dayRandom.pick(tailPool),
                    intensity: dayRandom.int(1...3)
                ))
            }
        }

        log.sessions.sort { $0.date > $1.date }

        // MARK: Plans

        log.plans = [
            PracticePlan(id: "pl_01",
                         title: "Windmill to Freeze",
                         style: .breaking,
                         weeklyMinuteTarget: 150,
                         weeklySessionTarget: 3,
                         focus: "Thread windmill into a baby freeze without touching down, ten clean reps in a row.",
                         startDate: now.adding(days: -21),
                         endDate: now.adding(days: 21),
                         accentIndex: 0),
            PracticePlan(id: "pl_02",
                         title: "Pocket Deepening",
                         style: .hipHop,
                         weeklyMinuteTarget: 120,
                         weeklySessionTarget: 3,
                         focus: "Groove at 78–86 BPM. Stop rushing the bounce, sit in the pocket.",
                         startDate: now.adding(days: -10),
                         endDate: now.adding(days: 32),
                         accentIndex: 1)
        ]

        // MARK: Skill tree

        let moveSeed: [(String, DanceStyle, MoveStage, Int, Int, String?)] = [
            ("Top Rock", .breaking, .battleReady, 84, 2, "Keep the shoulders loose — the arms are doing too much."),
            ("Six Step", .breaking, .clean, 61, 4, "Clean at 90 BPM, rushes past 100."),
            ("Windmill", .breaking, .drilling, 47, 1, "Still hopping on the exit. Slow the rotation, don't muscle it."),
            ("Baby Freeze", .breaking, .drilling, 33, 1, nil),
            ("Swipe", .breaking, .discovered, 12, 9, nil),
            ("Bounce Groove", .hipHop, .battleReady, 96, 3, nil),
            ("Rock Steady", .hipHop, .clean, 58, 5, nil),
            ("Party Rock", .hipHop, .drilling, 26, 6, nil),
            ("The Pop", .popping, .clean, 72, 8, "The hit lands late on the 2. Get it on the beat."),
            ("Wave", .popping, .drilling, 39, 8, "Elbows still break the line."),
            ("Robot", .popping, .discovered, 9, 14, nil),
            ("Shuffle", .house, .clean, 64, 11, nil),
            ("Jacking", .house, .drilling, 31, 12, nil),
            ("Points", .locking, .clean, 52, 16, nil),
            ("Locks", .locking, .drilling, 24, 17, nil),
            ("Chest Pop", .krump, .drilling, 41, 20, nil),
            ("Box", .tutting, .drilling, 18, 22, nil)
        ]

        log.moves = moveSeed.map { item in
            MoveSkill(id: "mv_\(item.0.lowercased().replacingOccurrences(of: " ", with: "_"))",
                      name: item.0,
                      style: item.1,
                      stage: item.2,
                      reps: item.3,
                      updatedAt: now.adding(days: -item.4),
                      notes: item.5,
                      targetReps: [60, 100, 150, 200][item.3 % 4])
        }

        log.goals = PracticeGoals(weeklyMinuteTarget: 240,
                                  weeklySessionTarget: 4,
                                  focusStyle: .breaking,
                                  restDays: [7])   // Saturday off

        content.practiceLogs = ["u_me": log]

        // MARK: Conversations

        func message(_ id: String, _ from: String, _ text: String, minutesAgo: Double, read: Bool = true, kind: MessageKind = .text, gift: String? = nil) -> ChatMessage {
            ChatMessage(id: id, senderID: from, kind: kind, text: text, giftID: gift,
                        createdAt: now.addingTimeInterval(-minutesAgo * 60), isRead: read)
        }

        content.conversations = [
            Conversation(id: "cv_maya", peerID: "u_maya", messages: [
                message("m_maya_1", "u_maya", "Yo that windmill clip you sent — the second rotation is way cleaner than last month.", minutesAgo: 320),
                message("m_maya_2", "u_me", "Thanks! Spent the whole week just on the exit. Still hopping sometimes.", minutesAgo: 312),
                message("m_maya_3", "u_maya", "Try slowing the rotation instead of muscling it. Changed everything for me.", minutesAgo: 300),
                message("m_maya_4", "u_me", "That's exactly what I needed. Session tomorrow at 8?", minutesAgo: 180),
                message("m_maya_5", "u_maya", "Make it 9 and I'm there. Bringing the speaker.", minutesAgo: 26, read: false)
            ]),
            Conversation(id: "cv_rin", peerID: "u_rin", messages: [
                message("m_rin_1", "u_rin", "Are you coming to the popping lab on Saturday?", minutesAgo: 1_500),
                message("m_rin_2", "u_me", "I'm in. What's the focus this time?", minutesAgo: 1_480),
                message("m_rin_3", "u_rin", "Texture. Two hours of waves and ticks, nothing else.", minutesAgo: 1_470),
                message("m_rin_4", "u_me", "Perfect. My waves are still crunchy.", minutesAgo: 1_460),
                message("m_rin_5", "u_rin", "They're not crunchy, they're just honest. See you Saturday.", minutesAgo: 1_440)
            ]),
            Conversation(id: "cv_juno", peerID: "u_juno", messages: [
                message("m_juno_1", "u_juno", "Sent you the four-bar shuffle drill we talked about.", minutesAgo: 2_800),
                message("m_juno_2", "u_me", "Got it. Ran it twice tonight — the third bar is brutal.", minutesAgo: 2_760),
                message("m_juno_3", "u_juno", "Third bar humbles everyone. Keep it slow until the feet stop thinking.", minutesAgo: 2_740),
                message("m_juno_4", "u_me", "Deal. Logging it as a session so I can't pretend I didn't.", minutesAgo: 2_700)
            ])
        ]

        // MARK: The signed-in dancer's shelf
        //
        // Following and followers deliberately start empty. The crew below are
        // connections the demo dancer already has — they are why the inbox has
        // conversations — but the two follow counts are only ever moved by a real
        // follow, so an empty profile honestly reports an empty profile.

        var library = Library()
        library.friends = ["u_maya", "u_rin", "u_juno"]
        library.incomingRequests = ["u_sol", "u_tee"]
        library.outgoingRequests = []
        library.likedPostIDs = ["p_02", "p_05", "p_09", "p_11"]
        library.savedPostIDs = ["p_04", "p_06"]
        library.ownedGifts = ["patch": 2, "mixtape": 1]
        content.libraries = ["u_me": library]

        return content
    }
}
