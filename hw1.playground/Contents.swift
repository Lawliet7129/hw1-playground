import Foundation

// MARK: - Map

/// The directions the player can walk in. The raw value is the word the player types.
enum Direction: String, CaseIterable {
    case north, south, east, west, up, down
}

/// Identifies each room of the castle.
enum RoomID {
    case pianoHall, library, garden, storeroom, attic, treetop
}

/// A single location in the castle.
struct Room {
    let name: String
    let description: String
    /// Which room lies in each direction. Directions missing from this dictionary are walls.
    let exits: [Direction: RoomID]
    /// Items lying around the room, waiting to be picked up.
    var items: [any Item]
    /// The character who lives  in each room (same as the original Deemo I)
    let resident: (any Resident)?
}

// MARK: - Items

/// Something the player can pick up, carry around, and use.
protocol Item {
    /// The single word the player types to refer to this item, e.g. "lantern".
    var name: String { get }
    /// What the player sees when they look closely at the item.
    var description: String { get }
    /// Runs when the player types "use <name>". Items can read and change the game's state.
    func use(in game: inout DeemoGame, context: AdventureGameContext)
}

/// A page of sheet music. Playing it on the piano makes the tree grow.
///  If a tree reaches certain height (40m), player can escape.
struct SheetMusic: Item {
    let name: String
    /// The song's proper title, e.g. "Dream".
    let title: String
    /// How many metres the tree grows the first time this song is played.
    let growth: Int
    /// Narration for the moment the song is played.
    let playingText: String

    var description: String {
        return """
            A sheet of music titled "\(title)". The notes seem to rearrange themselves when \
            you aren't looking.
            """
    }

    func use(in game: inout DeemoGame, context: AdventureGameContext) {
        game.play(song: self, context: context)
    }
}

/// A brass lantern. Once lit, it lets the player climb the dark stairs to the attic.
struct Lantern: Item {
    let name = "lantern"
    let description = """
        A dented brass lantern with a stub of candle inside. A book of matches is tied to \
        the handle.
        """

    func use(in game: inout DeemoGame, context: AdventureGameContext) {
        if game.isLanternLit {
            context.write("The lantern is already burning steadily.")
        } else {
            game.isLanternLit = true
            context.write("""
                You strike a match and light the lantern. Warm light pushes the shadows back \
                into the corners.
                """)
        }
    }
}

/// A faded photograph. Looking at it closely brings the player's memory back.
struct Photograph: Item {
    let name = "photograph"
    let description = """
        A creased photograph of three children in front of a piano. In this light the faces \
        are hard to make out.
        """

    func use(in game: inout DeemoGame, context: AdventureGameContext) {
        if game.hasRemembered {
            context.write("You already know who they are. You keep the photograph close anyway.")
            return
        }
        game.hasRemembered = true
        context.write("""
            You look closely. Three children in front of a piano: a girl with your face, a boy \
            with kind eyes at the keys, and an older girl with her arms around them both. The \
            names come back all at once. Alice. That's you. Hans, your brother, who was driving \
            that night. Celia, your sister. And the shadow in the hall, who plays and never \
            speaks, and grows a tree so that you can leave... you know him now.
            """)
    }
}

// MARK: - Characters

/// A character who lives in one of the rooms and can be talked to.
protocol Resident {
    /// How the character is referred to in the room description, e.g. "the masked lady".
    var name: String { get }
    /// Runs when the player types "talk". What gets said depends on the game's state, and
    /// some characters change that state (for example, by handing over an item).
    func talk(to game: inout DeemoGame, context: AdventureGameContext)
}

/// The shadow at the piano. He never speaks, but he makes himself understood.
struct Deemo: Resident {
    let name = "Deemo"

    func talk(to game: inout DeemoGame, context: AdventureGameContext) {
        if game.hasRemembered {
            context.write("""
                "Hans," you say. The shadow goes very still. Then, slowly, Deemo nods, and \
                turns back to the keys.
                """)
        } else if game.treeHeight == 0 {
            context.write("""
                Deemo doesn't speak. A long, ink-black hand lifts from the keys and points: \
                at the piano, at the sapling, and then up at the skylight.
                """)
        } else if game.treeHeight < DeemoGame.skylightHeight {
            context.write("""
                Deemo tilts his head toward the tree, then taps the empty music stand. He \
                wants more songs.
                """)
        } else {
            context.write("""
                Deemo looks up at the branches pressed against the skylight, then at you. \
                He does not move to stop you.
                """)
        }
    }
}

/// The woman in the white mask who waits in the attic.
struct MaskedLady: Resident {
    let name = "the masked lady"

    func talk(to game: inout DeemoGame, context: AdventureGameContext) {
        if game.hasRemembered {
            context.write("""
                "So you remember," the masked lady says. "Then you know I'll be there when \
                you wake up. Go on."
                """)
        } else if game.hasMetMaskedLady {
            context.write("\"Go home, little one,\" the masked lady says. \"He wants you to.\"")
        } else {
            game.hasMetMaskedLady = true
            game.inventory.append(Photograph())
            context.write("""
                The masked lady turns her head toward your lantern. "You shouldn't be up \
                here," she says, not unkindly. "None of us should." She takes something from \
                her sleeve and presses it into your hand: a photograph. "Look at it when \
                you're ready. Then go home. He wants you to go home."
                """)
            context.write("You take the photograph.")
        }
    }
}

// MARK: - The game

/// A text adventure based on Rayark's rhythm game Deemo. A girl falls into a castle where a
/// silent shadow plays the piano. Every song she plays makes a tree grow toward the skylight.
/// Once it is tall enough she can climb out and go home, or choose not to.
struct DeemoGame: AdventureGame {
    /// How tall the tree must grow, in metres, before its branches reach the skylight.
    static let skylightHeight = 40

    /// The map, keyed by room. Items are removed from rooms as the player picks them up.
    var rooms: [RoomID: Room] = DeemoGame.makeRooms()
    var location = RoomID.pianoHall
    var inventory: [any Item] = []
    /// Height of the tree growing out of the piano, in metres.
    var treeHeight = 0
    /// Titles of songs that have already been played. Each song only grows the tree once.
    var playedSongs: Set<String> = []
    var isLanternLit = false
    var hasMetMaskedLady = false
    var hasRemembered = false

    var title: String {
        return "Deemo  (tree: \(treeHeight) m)"
    }

    /// The room the player is standing in. makeRooms() creates an entry for every RoomID,
    /// so this lookup is guaranteed to succeed.
    var currentRoom: Room {
        return rooms[location]!
    }

    // MARK: Setup

    static func makeRooms() -> [RoomID: Room] {
        let dream = SheetMusic(
            name: "dream", title: "Dream", growth: 8,
            playingText: """
                The melody is simple and a little sad, like something hummed to a child. \
                Deemo's hands join yours on the low keys, and the sapling unfolds new leaves.
                """)
        let magnolia = SheetMusic(
            name: "magnolia", title: "Magnolia", growth: 12,
            playingText: """
                The song rushes and tumbles, faster than you thought you could play. Petals \
                blow in from the garden and settle on the keys, and the trunk thickens under \
                your eyes.
                """)
        let sairai = SheetMusic(
            name: "sairai", title: "Sairai", growth: 20,
            playingText: """
                This one you already know, somehow. You play it with your eyes closed, and \
                when you open them the hall is full of leaves.
                """)

        let pianoHall = Room(
            name: "The Piano Hall",
            description: """
                A vast hall of dark wood and darker glass. In its centre stands a grand piano, \
                and out of the piano itself grows a tree, reaching for the round skylight far \
                above. Deemo, the shadow, sits at the keys. An archway leads west into a \
                library and east out to a garden. Stairs climb north into darkness, and a low \
                door to the south opens on a storeroom.
                """,
            exits: [
                .west: .library, .east: .garden, .north: .attic, .south: .storeroom,
                .up: .treetop,
            ],
            items: [],
            resident: Deemo())
        let library = Room(
            name: "The Library",
            description: """
                Shelves rise into shadow on every side. Every book you open is blank. On the \
                reading desk a single sheet of music lies open, the ink still wet.
                """,
            exits: [.east: .pianoHall],
            items: [dream],
            resident: nil)
        let garden = Room(
            name: "The Garden",
            description: """
                A walled garden under a paper-white sky, silent except for falling petals. A \
                great magnolia stands in the middle, dropping every flower it has. Something \
                pale is caught in its lower branches.
                """,
            exits: [.west: .pianoHall],
            items: [magnolia],
            resident: nil)
        let storeroom = Room(
            name: "The Storeroom",
            description: """
                Crates, dust sheets, and a music box with its key snapped off. Beside the door \
                a brass lantern hangs from a nail.
                """,
            exits: [.north: .pianoHall],
            items: [Lantern()],
            resident: nil)
        let attic = Room(
            name: "The Attic",
            description: """
                Slanted rafters, thick dust, and a hundred little things your lantern picks \
                out one by one: a rocking horse, a mirror turned to face the wall, a child's \
                drawing of a tree. On a steamer trunk sits a woman in a white mask, very \
                still. A page of music pokes out from under the trunk's lid.
                """,
            exits: [.south: .pianoHall],
            items: [sairai],
            resident: MaskedLady())
        let treetop = Room(
            name: "The Treetop",
            description: """
                You climb through leaves the colour of ink until the trunk thins to a single \
                branch. The skylight is right there, a circle of true daylight, warm on your \
                face. Far below, the piano has gone quiet. Deemo is looking up.
                """,
            exits: [.down: .pianoHall],
            items: [],
            resident: nil)

        return [
            .pianoHall: pianoHall,
            .library: library,
            .garden: garden,
            .storeroom: storeroom,
            .attic: attic,
            .treetop: treetop,
        ]
    }

    // MARK: AdventureGame

    mutating func start(context: AdventureGameContext) {
        context.write("""
            A flash of light, and you're falling: through clouds, through a window of glass \
            and stars, and then you're lying on cold stone, unhurt. You don't remember your \
            name. You don't remember how you got here. Far above you is a round skylight, and \
            beside you a tall shadow shaped like a man sits at a grand piano, waiting.
            """)
        context.write("(Type \"help\" to see what you can do.)")
        describeCurrentRoom(context: context)
    }

    mutating func handle(input: String, context: AdventureGameContext) {
        let words = input.lowercased().split(separator: " ").map(String.init)
        guard let command = words.first else {
            context.write("Please enter a command. Type \"help\" if you're stuck.")
            return
        }
        let argument = words.dropFirst().joined(separator: " ")

        switch command {
        case "help":
            showHelp(context: context)
        case "look":
            look(at: argument, context: context)
        case "take", "get":
            take(argument, context: context)
        case "inventory", "i":
            showInventory(context: context)
        case "use", "play":
            use(argument, context: context)
        case "talk":
            talk(context: context)
        case "climb":
            move(.up, context: context)
        case "leave":
            leave(context: context)
        case "stay":
            stay(context: context)
        default:
            if let direction = Direction(rawValue: command) {
                move(direction, context: context)
            } else {
                context.write("You don't know how to \"\(command)\". Try \"help\".")
            }
        }
    }

    // MARK: Commands

    func showHelp(context: AdventureGameContext) {
        context.write("Commands:")
        context.write("  north / south / east / west / up / down - walk in that direction")
        context.write("  climb - the same as up")
        context.write("  look [item] - look around, or look closely at an item")
        context.write("  take <item> - pick up an item")
        context.write("  inventory - list what you're carrying")
        context.write("  use <item> - use something you're carrying")
        context.write("  play <song> - sit at the piano and play a sheet of music (same as use)")
        context.write("  talk - speak to whoever is in the room")
        context.write("  leave - at the treetop, go home through the skylight")
        context.write("  stay - at the treetop, climb back down and stay with Deemo")
        context.write("  help - show this list")
    }

    func describeCurrentRoom(context: AdventureGameContext) {
        let room = currentRoom
        context.write("[ \(room.name) ]")
        context.write(room.description)
        if location == .pianoHall {
            context.write(treeDescription)
        }
        if location == .treetop {
            context.write(memoryHint)
            context.write("""
                Type "leave" to go home through the skylight, or "stay" to climb back down \
                and stay with Deemo.
                """)
        }
        if let resident = room.resident {
            context.write("You're not alone: \(resident.name) is here.")
        }
        if !room.items.isEmpty {
            let names = room.items.map { $0.name }
            context.write("Items here: \(names.joined(separator: ", "))")
        }
        let exits = Direction.allCases.filter { room.exits[$0] != nil }.map { $0.rawValue }
        context.write("Exits: \(exits.joined(separator: ", "))")
    }

    /// The tree looks different depending on how much of the story has been played.
    var treeDescription: String {
        if treeHeight == 0 {
            return """
                The tree is only a sapling, no taller than your knee, but the keys under \
                Deemo's hands hum with something waiting.
                """
        } else if treeHeight < DeemoGame.skylightHeight {
            return "The tree stands \(treeHeight) m tall, its branches straining for the skylight."
        } else {
            return "The tree's highest branches press against the skylight. You could climb it."
        }
    }

    /// A nudge at the treetop about the photograph, which decides how leaving ends.
    var memoryHint: String {
        if hasRemembered {
            return "You know who is sitting at the piano below, and what you would be leaving."
        } else if inventory.contains(where: { $0 is Photograph }) {
            return """
                The photograph in your pocket feels heavy. You still haven't looked at it \
                properly ("use photograph").
                """
        } else {
            return """
                Something about the shadow below nags at you, like a name you can't quite \
                reach. Maybe someone in this castle knows it.
                """
        }
    }

    func look(at name: String, context: AdventureGameContext) {
        if name.isEmpty {
            describeCurrentRoom(context: context)
            return
        }
        let nearby = inventory + currentRoom.items
        if let item = nearby.first(where: { $0.name == name }) {
            context.write(item.description)
        } else {
            context.write("You don't see any \"\(name)\" here.")
        }
    }

    mutating func take(_ name: String, context: AdventureGameContext) {
        if name.isEmpty {
            context.write("Take what?")
            return
        }
        guard let index = currentRoom.items.firstIndex(where: { $0.name == name }) else {
            context.write("There's no \"\(name)\" here to take.")
            return
        }
        let item = currentRoom.items[index]
        rooms[location]?.items.remove(at: index)
        inventory.append(item)
        context.write("You pick up the \(item.name).")
    }

    func showInventory(context: AdventureGameContext) {
        if inventory.isEmpty {
            context.write("You aren't carrying anything.")
        } else {
            let names = inventory.map { $0.name }
            context.write("You are carrying: \(names.joined(separator: ", "))")
        }
    }

    mutating func use(_ name: String, context: AdventureGameContext) {
        if name.isEmpty {
            context.write("Use what?")
            return
        }
        guard let item = inventory.first(where: { $0.name == name }) else {
            context.write("You aren't carrying a \"\(name)\".")
            return
        }
        item.use(in: &self, context: context)
    }

    mutating func talk(context: AdventureGameContext) {
        guard let resident = currentRoom.resident else {
            context.write("There's no one here to talk to. The castle is very quiet.")
            return
        }
        resident.talk(to: &self, context: context)
    }

    mutating func move(_ direction: Direction, context: AdventureGameContext) {
        guard let destination = currentRoom.exits[direction] else {
            context.write("You can't go \(direction.rawValue) from here.")
            return
        }
        if let reason = reasonBlocked(entering: destination) {
            context.write(reason)
            return
        }
        location = destination
        describeCurrentRoom(context: context)
    }

    /// Some doors only open once the player has done something. Returns why the player
    /// can't enter `room` yet, or nil if the way is clear.
    func reasonBlocked(entering room: RoomID) -> String? {
        switch room {
        case .attic where !isLanternLit:
            return """
                You take three steps up the stairs and the dark swallows them whole. \
                Somewhere above, someone is humming. You'd need a light to go any further.
                """
        case .treetop where treeHeight < DeemoGame.skylightHeight:
            return """
                You get a few branches up before they thin out to twigs. The skylight is \
                still far above. The tree needs to grow taller (\(treeHeight) m of \
                \(DeemoGame.skylightHeight) m).
                """
        default:
            return nil
        }
    }

    /// Plays a sheet of music on the piano, growing the tree if the song is new.
    mutating func play(song: SheetMusic, context: AdventureGameContext) {
        guard location == .pianoHall else {
            context.write("There's no piano here. The only piano is in the hall.")
            return
        }
        if playedSongs.contains(song.title) {
            context.write("""
                You play "\(song.title)" again. The leaves shiver, but the tree has already \
                taken all it can from this melody.
                """)
            return
        }
        playedSongs.insert(song.title)
        treeHeight += song.growth
        context.write("You sit beside Deemo and play \"\(song.title)\". \(song.playingText)")
        context.write("The tree grows \(song.growth) m. It now stands \(treeHeight) m tall.")
        if treeHeight >= DeemoGame.skylightHeight {
            context.write("Its highest branches brush the skylight. You could climb up now.")
        }
    }

    // MARK: Endings

    mutating func leave(context: AdventureGameContext) {
        guard location == .treetop else {
            context.write("The only way out of this place is up, through the skylight.")
            return
        }
        if hasRemembered {
            context.write("""
                Before you climb through, you look down one last time. "Thank you, Hans," \
                you say, and the shadow lifts one hand: to wave, or to say go. You go. You \
                wake in a hospital bed with sunlight on the sheets. Your sister Celia is \
                asleep in the chair beside it, and on the table, in your brother's \
                handwriting, is a page of sheet music titled "Dream".
                """)
            context.write("--- ENDING 2 of 3: Remembered ---")
        } else {
            context.write("""
                You push the skylight open and pull yourself through into white light. \
                Behind and below you, a shadow at a piano comes apart, gently, like petals \
                in wind. You wake in a bed that smells of antiseptic, with a melody in your \
                head you can't place. You will hum it for the rest of your life, and never \
                know why.
                """)
            context.write("--- ENDING 1 of 3: A Melody You Can't Place ---")
        }
        context.endGame()
    }

    mutating func stay(context: AdventureGameContext) {
        guard location == .treetop else {
            context.write("You stay where you are for a while. Nothing changes.")
            return
        }
        context.write("""
            You look at the daylight for a long moment. Then you climb back down, all the \
            way, and sit on the bench beside Deemo. He shifts to make room. Somewhere above, \
            the skylight clouds over, and the two of you play, and the tree goes on growing, \
            and you never do find out how tall it gets.
            """)
        context.write("--- ENDING 3 of 3: Stay ---")
        context.endGame()
    }
}


DeemoGame.run()
