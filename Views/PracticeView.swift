import SwiftUI

/// The practice loop.
///
/// One word, one tap, next. No timer, no score during the session, no reward
/// animation. Progress is shown at the end, never mid-session: a parent who
/// sees "you're at 40%" after three misses starts coaching the child instead of
/// practicing with them, which defeats the point.
struct PracticeView: View {
    let onFinish: () -> Void

    @EnvironmentObject private var store: AppStore
    @StateObject private var speaker = WordSpeaker()

    @State private var queue: [TargetWord] = []
    @State private var index = 0
    @State private var attempts: [Attempt] = []
    @State private var sessionID = UUID()
    @State private var startedAt = Date()
    @State private var isDone = false
    @State private var showQuitConfirm = false

    private var current: TargetWord? {
        index < queue.count ? queue[index] : nil
    }

    var body: some View {
        ZStack {
            DS.bg.ignoresSafeArea()

            if isDone {
                summary
            } else if let word = current {
                practice(word)
            } else {
                ProgressView()
            }
        }
        .onAppear(perform: begin)
        .onDisappear { speaker.stop() }
    }

    // MARK: - Practice

    private func practice(_ word: TargetWord) -> some View {
        VStack(spacing: 0) {
            topBar

            Spacer(minLength: 12)

            wordCard(word)

            Spacer(minLength: 20)

            resultButtons(word)

            Spacer(minLength: 18)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 12)
    }

    private var topBar: some View {
        HStack {
            Button {
                showQuitConfirm = true
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(DS.inkMuted)
                    .frame(width: 34, height: 34)
                    .background(DS.card)
                    .clipShape(Circle())
            }
            .confirmationDialog("End this session?", isPresented: $showQuitConfirm, titleVisibility: .visible) {
                Button("End session", role: .destructive) { endSession() }
                Button("Keep going", role: .cancel) {}
            } message: {
                Text("Words you already marked will still be counted.")
            }

            Spacer()

            // Progress as segments rather than a percentage, so it reads as
            // "a few more" instead of "you are 30% successful".
            HStack(spacing: 4) {
                ForEach(0..<queue.count, id: \.self) { i in
                    Capsule()
                        .fill(i < index ? DS.accent : (i == index ? DS.accent.opacity(0.35) : DS.hairline))
                        .frame(width: 10, height: 4)
                }
            }

            Spacer()

            Text("\(index + 1)/\(queue.count)")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(DS.inkMuted)
                .frame(width: 34, alignment: .trailing)
        }
    }

    private func wordCard(_ word: TargetWord) -> some View {
        VStack(spacing: 18) {
            Text("/\(word.sound)/ · \(word.position.label)")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(DS.accent)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(DS.accentSoft)
                .clipShape(Capsule())

            Text(word.text)
                .font(.system(size: 56, weight: .bold, design: .rounded))
                .foregroundStyle(DS.ink)
                .minimumScaleFactor(0.45)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)

            Button {
                speaker.speak(word.text)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.system(size: 15))
                    Text("Hear it")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundStyle(DS.accent)
                .padding(.horizontal, 20)
                .padding(.vertical, 11)
                .background(DS.accentSoft)
                .clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(DS.card)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(DS.hairline, lineWidth: 1)
        )
    }

    private func resultButtons(_ word: TargetWord) -> some View {
        VStack(spacing: 10) {
            Text("Did \(store.state.child.name.isEmpty ? "they" : store.state.child.name) say it?")
                .font(.system(size: 14))
                .foregroundStyle(DS.inkMuted)

            ForEach(AttemptResult.allCases) { result in
                Button {
                    record(result, for: word)
                } label: {
                    HStack {
                        Text(result.label)
                        Spacer()
                        Image(systemName: icon(for: result))
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .padding(.horizontal, 20)
                }
                .buttonStyle(ResultButtonStyle(result: result))
            }
        }
    }

    private func icon(for result: AttemptResult) -> String {
        switch result {
        case .correct: return "checkmark"
        case .close: return "minus"
        case .missed: return "xmark"
        }
    }

    // MARK: - Summary

    private var summary: some View {
        VStack(spacing: 22) {
            Spacer()

            let correct = attempts.filter { $0.result == .correct }.count
            let close = attempts.filter { $0.result == .close }.count

            VStack(spacing: 10) {
                Text("\(attempts.count) words")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(DS.ink)
                Text("\(correct) got it · \(close) close · \(attempts.count - correct - close) not yet")
                    .font(.system(size: 15))
                    .foregroundStyle(DS.inkMuted)
            }

            VStack(spacing: 12) {
                Button("Done") {
                    onFinish()
                }
                .buttonStyle(PrimaryButtonStyle())

                Button("One more set") {
                    begin()
                    isDone = false
                }
                .buttonStyle(SecondaryButtonStyle())
            }
            .padding(.horizontal, 22)

            Spacer()
        }
    }

    // MARK: - Actions

    private func begin() {
        let all = store.state.targets
        guard !all.isEmpty else {
            onFinish()
            return
        }
        queue = Array(all.shuffled().prefix(10))
        index = 0
        attempts = []
        sessionID = UUID()
        startedAt = Date()
        isDone = false
    }

    private func record(_ result: AttemptResult, for word: TargetWord) {
        attempts.append(Attempt(
            wordID: word.id,
            wordText: word.text,
            sound: word.sound,
            position: word.position,
            result: result,
            date: Date(),
            sessionID: sessionID
        ))

        withAnimation(.easeOut(duration: 0.18)) {
            if index + 1 < queue.count {
                index += 1
            } else {
                endSession()
            }
        }
    }

    private func endSession() {
        speaker.stop()
        guard !attempts.isEmpty else {
            onFinish()
            return
        }
        let session = PracticeSession(
            id: sessionID,
            startedAt: startedAt,
            endedAt: Date(),
            wordCount: attempts.count,
            targetSound: attempts.first?.sound ?? ""
        )
        store.record(attempts, session: session)
        isDone = true
    }
}

struct ResultButtonStyle: ButtonStyle {
    let result: AttemptResult

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(DS.color(for: result))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(DS.soft(for: result))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .opacity(configuration.isPressed ? 0.78 : 1)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
