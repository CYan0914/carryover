import Foundation

/// The starter word lists.
///
/// Scope note: these are articulation targets, not a therapy programme. The app
/// never decides which sound a child should be working on and never claims a
/// sequence is clinically right. A therapist picks; this is only a typing
/// shortcut for families who would otherwise copy a handout by hand.
///
/// The lists are deliberately short and high-frequency. Every competing app in
/// this category is criticised for padding ("same words", "repetitive", "ran
/// out of content"), so the honest promise here is small and correct rather
/// than large and generic: the family's own words are first-class, these are
/// just a starting point.
enum WordLibrary {

    struct SoundGroup: Identifiable {
        var id: String { sound }
        let sound: String
        let example: String
        let words: [WordPosition: [String]]
    }

    static let groups: [SoundGroup] = [
        SoundGroup(sound: "r", example: "rabbit", words: [
            .initial: ["rabbit", "rain", "red", "ring", "rock", "room", "rope", "run"],
            .medial: ["carrot", "carry", "berry", "sorry", "cherry", "mirror"],
            .final: ["car", "door", "four", "star", "bear", "chair", "more"]
        ]),
        SoundGroup(sound: "s", example: "sun", words: [
            .initial: ["sun", "sock", "soup", "soap", "sand", "seat", "saw", "sip"],
            .medial: ["bicycle", "dancing", "messy", "missing", "pencil", "whistle"],
            .final: ["bus", "house", "ice", "mouse", "grass", "juice", "kiss"]
        ]),
        SoundGroup(sound: "l", example: "leaf", words: [
            .initial: ["leaf", "lion", "lamp", "leg", "lips", "lock", "lunch"],
            .medial: ["balloon", "elephant", "yellow", "salad", "pillow"],
            .final: ["ball", "bell", "apple", "table", "smile", "whale"]
        ]),
        SoundGroup(sound: "k", example: "cat", words: [
            .initial: ["cat", "cake", "cup", "cold", "corn", "key", "coat"],
            .medial: ["bacon", "cookie", "jacket", "monkey", "pocket"],
            .final: ["book", "bike", "duck", "milk", "sock", "cake"]
        ]),
        SoundGroup(sound: "g", example: "goat", words: [
            .initial: ["goat", "gate", "game", "gum", "girl", "gold"],
            .medial: ["tiger", "wagon", "sugar", "bigger"],
            .final: ["bag", "bug", "dog", "egg", "frog", "hug", "leg"]
        ]),
        SoundGroup(sound: "f", example: "fish", words: [
            .initial: ["fish", "foot", "fork", "five", "farm", "face"],
            .medial: ["coffee", "elephant", "awful", "muffin"],
            .final: ["leaf", "knife", "roof", "giraffe", "cough"]
        ]),
        SoundGroup(sound: "sh", example: "shoe", words: [
            .initial: ["shoe", "ship", "shop", "sheep", "shirt", "shell"],
            .medial: ["ocean", "washing", "sunshine", "mushroom"],
            .final: ["fish", "brush", "wash", "dish", "trash", "push"]
        ]),
        SoundGroup(sound: "ch", example: "chair", words: [
            .initial: ["chair", "cheese", "chicken", "chip", "chalk", "cherry"],
            .medial: ["teacher", "kitchen", "picture", "matches"],
            .final: ["beach", "watch", "lunch", "peach", "catch", "church"]
        ]),
        SoundGroup(sound: "th", example: "three", words: [
            .initial: ["three", "thumb", "think", "thirsty", "thirteen"],
            .medial: ["bathtub", "toothbrush", "something", "birthday"],
            .final: ["bath", "mouth", "tooth", "path", "math"]
        ]),
        SoundGroup(sound: "s-blends", example: "star", words: [
            .initial: ["star", "spoon", "snake", "slide", "smile", "swing", "stop"],
            .medial: ["basket", "whisper", "mister", "toaster"],
            .final: ["crisp", "gasp", "wasp"]
        ]),
        SoundGroup(sound: "r-blends", example: "tree", words: [
            .initial: ["tree", "green", "bread", "crab", "drum", "frog", "prize"],
            .medial: ["umbrella", "library", "surprise"],
            .final: ["—"]
        ]),
        SoundGroup(sound: "multi-syllable", example: "butterfly", words: [
            .initial: ["butterfly", "caterpillar", "elephant", "alligator", "helicopter"],
            .medial: ["spaghetti", "computer", "banana", "umbrella"],
            .final: ["refrigerator", "dinosaur", "avocado", "blueberry"]
        ])
    ]

    static func words(for sound: String, position: WordPosition) -> [String] {
        guard let group = groups.first(where: { $0.sound == sound }) else { return [] }
        return (group.words[position] ?? []).filter { $0 != "—" }
    }

    static var allSounds: [String] { groups.map { $0.sound } }
}
