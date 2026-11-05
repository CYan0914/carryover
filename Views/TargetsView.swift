import SwiftUI

struct TargetsView: View {
    @EnvironmentObject private var store: AppStore
    @State private var showPicker = false
    @State private var newWord = ""
    @State private var newSound = ""
    @State private var newPosition: WordPosition = .initial
    @State private var showAddSheet = false

    private var grouped: [(String, [TargetWord])] {
        Dictionary(grouping: store.state.targets, by: { $0.sound })
            .map { ($0.key, $0.value.sorted { $0.text < $1.text }) }
            .sorted { $0.0 < $1.0 }
    }

    var body: some View {
        NavigationStack {
            List {
                if store.state.targets.isEmpty {
                    Section {
                        Text("No words yet. Add the sound your therapist is working on, or type the exact words from their handout.")
                            .font(.system(size: 15))
                            .foregroundStyle(DS.inkMuted)
                    }
                }

                ForEach(grouped, id: \.0) { sound, words in
                    Section {
                        ForEach(words) { word in
                            HStack {
                                Text(word.text)
                                    .font(.system(size: 16))
                                    .foregroundStyle(DS.ink)
                                Spacer()
                                Text(word.position.label)
                                    .font(.system(size: 12))
                                    .foregroundStyle(DS.inkMuted)
                                if word.isCustom {
                                    Image(systemName: "pencil")
                                        .font(.system(size: 10))
                                        .foregroundStyle(DS.hairline)
                                }
                            }
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                store.removeTarget(id: words[index].id)
                            }
                        }
                    } header: {
                        HStack {
                            Text("/\(sound)/")
                            Spacer()
                            Text("\(words.count)")
                                .foregroundStyle(DS.inkMuted)
                        }
                    } footer: {
                        if sound == grouped.last?.0 {
                            Text("Swipe a word to remove it. Removing a word keeps its history in the report.")
                        }
                    }
                }

                Section {
                    Button {
                        showPicker = true
                    } label: {
                        Label("Add from word library", systemImage: "text.badge.plus")
                            .font(.system(size: 16))
                    }

                    Button {
                        showAddSheet = true
                    } label: {
                        Label("Type the therapist's exact words", systemImage: "square.and.pencil")
                            .font(.system(size: 16))
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(DS.bg.ignoresSafeArea())
            .navigationTitle("Words")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showPicker) {
                NavigationStack { SoundPickerView() }
            }
            .sheet(isPresented: $showAddSheet) {
                addSheet
            }
        }
    }

    private var addSheet: some View {
        NavigationStack {
            Form {
                Section("Word") {
                    TextField("e.g. Spiderman", text: $newWord)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                Section("Target sound") {
                    TextField("e.g. sp", text: $newSound)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                Section("Where is the sound in the word?") {
                    Picker("Position", selection: $newPosition) {
                        ForEach(WordPosition.allCases) { p in
                            Text(p.label).tag(p)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                Section {
                    Text("Copy the words exactly as they appear on the therapist's handout. Do not add sounds or syllables they did not give you.")
                        .font(.system(size: 13))
                        .foregroundStyle(DS.inkMuted)
                }
            }
            .navigationTitle("Add a word")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { resetAdd() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let word = newWord.trimmingCharacters(in: .whitespacesAndNewlines)
                        let sound = newSound.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !word.isEmpty, !sound.isEmpty else { return }
                        store.addTarget(TargetWord(text: word, sound: sound,
                                                   position: newPosition, isCustom: true))
                        resetAdd()
                    }
                    .disabled(newWord.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                              || newSound.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func resetAdd() {
        newWord = ""
        newSound = ""
        newPosition = .initial
        showAddSheet = false
    }
}
