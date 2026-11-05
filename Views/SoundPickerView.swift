import SwiftUI

/// Pick a sound, then confirm the words. Two steps, no wizard.
struct SoundPickerView: View {
    var isOnboarding: Bool = false

    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    @State private var selectedSound: String?

    var body: some View {
        List {
            if selectedSound == nil {
                Section {
                    ForEach(WordLibrary.groups) { group in
                        Button {
                            selectedSound = group.sound
                        } label: {
                            HStack(spacing: 14) {
                                Text("/\(group.sound)/")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(DS.accent)
                                    .frame(width: 74, alignment: .leading)
                                Text("as in \(group.example)")
                                    .font(.system(size: 15))
                                    .foregroundStyle(DS.inkMuted)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(DS.hairline)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                } header: {
                    Text("Which sound is the therapist working on?")
                } footer: {
                    Text("This only pre-fills a word list. It does not decide or change what your child should be working on.")
                }
            } else if let sound = selectedSound {
                WordSelectionSection(
                    sound: sound,
                    onDone: { dismiss() },
                    onBack: { selectedSound = nil }
                )
            }
        }
        .scrollContentBackground(.hidden)
        .background(DS.bg.ignoresSafeArea())
        .navigationTitle(isOnboarding ? "Target sound" : "Add words")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if isOnboarding {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Back") { dismiss() }
                }
            }
        }
    }
}

/// Position-by-position confirmation for one sound.
private struct WordSelectionSection: View {
    let sound: String
    let onDone: () -> Void
    let onBack: () -> Void

    @EnvironmentObject private var store: AppStore
    @State private var selected: Set<String> = []

    private var group: WordLibrary.SoundGroup? {
        WordLibrary.groups.first { $0.sound == sound }
    }

    var body: some View {
        Group {
            ForEach(WordPosition.allCases) { position in
                let words = WordLibrary.words(for: sound, position: position)
                if !words.isEmpty {
                    Section(header: Text(position.label)) {
                        ForEach(words, id: \.self) { word in
                            Button {
                                toggle(word)
                            } label: {
                                HStack {
                                    Text(word)
                                        .font(.system(size: 16))
                                        .foregroundStyle(DS.ink)
                                    Spacer()
                                    Image(systemName: selected.contains(word)
                                          ? "checkmark.circle.fill" : "circle")
                                        .font(.system(size: 18))
                                        .foregroundStyle(selected.contains(word) ? DS.accent : DS.hairline)
                                }
                                .padding(.vertical, 3)
                            }
                        }
                    }
                }
            }

            Section {
                Button {
                    addAll()
                } label: {
                    Text("Select all \(totalWords) words")
                        .font(.system(size: 15, weight: .medium))
                }

                Button {
                    save()
                    onDone()
                } label: {
                    Text(selected.isEmpty ? "Choose at least one word" : "Add \(selected.count) word\(selected.count == 1 ? "" : "s")")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(selected.isEmpty ? DS.inkMuted : DS.accent)
                        .frame(maxWidth: .infinity)
                }
                .disabled(selected.isEmpty)
            }

            Section {
                Button {
                    onBack()
                } label: {
                    Label("Different sound", systemImage: "chevron.left")
                        .font(.system(size: 15))
                }
            }
        }
    }

    private var totalWords: Int {
        WordPosition.allCases.reduce(0) { $0 + WordLibrary.words(for: sound, position: $1).count }
    }

    private func toggle(_ word: String) {
        if selected.contains(word) { selected.remove(word) } else { selected.insert(word) }
    }

    private func addAll() {
        for position in WordPosition.allCases {
            for word in WordLibrary.words(for: sound, position: position) {
                selected.insert(word)
            }
        }
    }

    private func save() {
        var newWords: [TargetWord] = []
        for position in WordPosition.allCases {
            for word in WordLibrary.words(for: sound, position: position) where selected.contains(word) {
                newWords.append(TargetWord(text: word, sound: sound, position: position, isCustom: false))
            }
        }
        store.addTargets(newWords)
    }
}
