# Deemo I

*For instructions, consult the HW1 Assignment on the [CIS 1951 website](https://www.seas.upenn.edu/~cis1951/26sp/assignments/).*

A text adventure based on Rayark's rhythm game Deemo I (https://en.wikipedia.org/wiki/Deemo).

Storyline: A girl falls into a castle where a silent shadow sits at a grand piano. Every song she plays makes the tree growing out of the piano taller. Once it reaches the skylight she can climb out and go home, or choose not to.

Built and tested with Xcode 26.6 (release version, not a beta). The code only uses Swift 5 features, and it also compiles cleanly with a Swift 5.10 toolchain, so it should run under Xcode 15 as well.

## Explanations

**What locations/rooms does your game have?**

1. **The Piano Hall**: the starting room and hub. Deemo sits at the piano here, and the tree grows out of the piano. Every other room connects to it.
2. **The Library** (west of the hall):  shelves of blank books. The "Dream" sheet music is on the reading desk.
3. **The Garden** (east of the hall): a walled garden with a magnolia tree. The "Magnolia" sheet music is caught in its branches.
4. **The Storeroom** (south of the hall): crates and a broken music box. The lantern hangs by the door.
5. **The Attic** (north of the hall): pitch dark until you bring a lit lantern. The masked lady waits here, and the "Sairai" sheet music is under her trunk.
6. **The Treetop** (up from the hall, only can be reached once the tree is 40 m tall): the branch just below the skylight, where the player decides how the story ends.

**What items does your game have?**

1. **Sheet music** (`dream`, `magnolia`, `sairai`) - three `SheetMusic` items found in the library, garden, and attic. Playing one at the piano grows the tree by 8, 12, or 20 meters. Each song only counts once, so all three are needed to reach the 40 m skylight.
2. **Lantern** - a `Lantern` found in the storeroom. `use lantern` lights it, which is the only way to get past the dark stairs into the attic.
3. **Photograph** - a `Photograph` the masked lady hands you when you talk to her. `use photograph` restores the girl's memory, *which changes the ending you get when you leave*. It is possible to reach the ending without using Photograph, in which case player gets a different ending.

**Explain how your code is designed. In particular, describe how you used structs or enums, as well as protocols.**

The map is built from two enums and a struct. `Direction` is a `String`-backed, `CaseIterable` enum, so a typed word like `"north"` is parsed straight into a direction with `Direction(rawValue:)`, and `look` lists a room's exits in a fixed order by iterating `allCases`. `RoomID` names each room and is the key of the `rooms` dictionary. `Room` is a struct holding a name, description, an `exits` dictionary from `Direction` to `RoomID`, the items lying on the floor, and an optional resident.

There are two protocols. `Item` requires a `name`, a `description`, and a `use(in:context:)` method that receives the game struct `inout`, so an item can change the game's state. `SheetMusic`, `Lantern`, and `Photograph` each conform and implement `use` differently (grow the tree, light the lantern, restore memory). `Resident` requires a `name` and a `talk(to:context:)` method; `Deemo` and `MaskedLady` conform, and their dialogue depends on the game's state (tree height, whether you remember). Both protocols are used through existentials: rooms store `[any Item]` and `(any Resident)?`, the inventory is `[any Item]`, and the `use`/`talk` commands just call the protocol method on whatever they find, so the game struct never needs to know which concrete item or character it is dealing with. Removing a conformance means that item or character can no longer be placed in a room, and the code stops compiling.

All state lives in `DeemoGame`: the rooms dictionary (items are removed from it as they are picked up), the player's location, the inventory, the tree height, the set of songs already played, and three flags (lantern lit, met the masked lady, remembered). Pressing Reset re-creates the struct, so everything returns to its initial state.

**How do you use optionals in your program?**

* `Direction(rawValue: command)` is a failable initializer. If the word isn't a direction, the game reports an unknown command instead.
* `currentRoom.exits[direction]` is `nil` when there is a wall in that direction, so `move` tells the player they can't go that way.
* `reasonBlocked(entering:)` returns `String?`: the message explaining why a door is locked (attic without a lit lantern, treetop before the tree is tall enough), or `nil` when the way is clear.
* `Room.resident` is `(any Resident)?`. `talk` in an empty room hits the `nil` case and says there is no one to talk to.
* `take`, `use`, and `look <item>` use `firstIndex(where:)` / `first(where:)`, which return `nil` when the named item isn't in the room or inventory.
* `words.first` is `nil` when the player submits an empty line.

**Did you implement any extra features you're proud of and want to show off?**

* The title bar shows the tree's current height and updates as you play songs.
* The hall's description and Deemo's dialogue change with the tree's height, and the masked lady's and Deemo's dialogue change again once you have used the photograph.
* Each song grows the tree only once; replaying it gives a different message and no growth.
* At the treetop, a hint line changes depending on whether you have the photograph and whether you have used it, so the two ways of leaving are discoverable.
* `look <item>` describes an item in the room or your inventory. `climb` works as an alias for `up`, `get` for `take`, `i` for `inventory`, and `play` for `use`.

## Endings

There are three endings. All of them require all three songs to be played so the tree reaches the skylight. At the treetop the game tells you to type `leave` or `stay`, and nudges you about the photograph if you are carrying it but haven't used it. Each ending prints its number (1, 2, or 3 of 3).

### Ending 1: A Melody You Can't Place (leave without remembering)

```
west
take dream
east
play dream
east
take magnolia
west
play magnolia
south
take lantern
north
use lantern
north
take sairai
south
play sairai
up
leave
```

### Ending 2: Remembered (talk to the masked lady, use the photograph, then leave)

```
west
take dream
east
play dream
east
take magnolia
west
play magnolia
south
take lantern
north
use lantern
north
take sairai
talk
use photograph
south
play sairai
up
leave
```

### Ending 3: Stay

```
west
take dream
east
play dream
east
take magnolia
west
play magnolia
south
take lantern
north
use lantern
north
take sairai
south
play sairai
up
stay
```
