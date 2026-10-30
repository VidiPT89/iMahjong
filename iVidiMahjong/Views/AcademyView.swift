import SwiftUI

/// The Riichi Academy hub: short lessons, endless drills and the coached table.
struct AcademyView: View {
    @EnvironmentObject var loc: Localization
    @ObservedObject var progress: AcademyProgress
    let onBack: () -> Void
    let onLesson: (Int) -> Void
    let onDrill: (DrillKind) -> Void
    let onTable: () -> Void

    var body: some View {
        let pt = loc.lang == .pt
        let done = progress.completedLessons
        ZStack {
            BackgroundGlow()
            VStack(spacing: 0) {
                ScreenHeader(title: pt ? "Academia Riichi" : "Riichi Academy", onBack: onBack)
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        AcademyCard {
                            Text(pt ? "\(done.count) de \(ACADEMY_LESSONS.count) lições" : "\(done.count) of \(ACADEMY_LESSONS.count) lessons")
                                .font(.system(size: 15, weight: .semibold, design: .rounded)).foregroundColor(Theme.text)
                            ProgressView(value: Double(done.count), total: Double(ACADEMY_LESSONS.count)).tint(Theme.accent)
                            Text(pt ? "Cada lição leva 2 minutos e acaba com uma pergunta." : "Each lesson takes 2 minutes and ends with a question.")
                                .font(.system(size: 12, design: .rounded)).foregroundColor(Theme.textDim)
                        }

                        SectionLabel(text: pt ? "Lições" : "Lessons")
                        ForEach(Array(ACADEMY_LESSONS.enumerated()), id: \.offset) { index, lesson in
                            Button(action: { onLesson(index) }) {
                                HStack(spacing: 12) {
                                    ZStack {
                                        Circle().fill(done.contains(lesson.id) ? Theme.ok : Theme.bgPanel2).frame(width: 32, height: 32)
                                        if done.contains(lesson.id) {
                                            Image(systemName: "checkmark").font(.system(size: 13, weight: .bold)).foregroundColor(.white)
                                        } else {
                                            Text("\(index + 1)").font(.system(size: 13, weight: .bold, design: .rounded)).foregroundColor(Theme.text)
                                        }
                                    }
                                    Text(lesson.title(loc.lang)).font(.system(size: 15, weight: .medium, design: .rounded)).foregroundColor(Theme.text)
                                    Spacer()
                                    Image(systemName: "chevron.right").foregroundColor(Theme.textDim)
                                }
                                .padding(.vertical, 10).padding(.horizontal, 14)
                                .background(RoundedRectangle(cornerRadius: 12).fill(Theme.bgPanel))
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("lesson-\(lesson.id)")
                        }

                        SectionLabel(text: pt ? "Treinos sem fim" : "Endless drills")
                        drillCard(.waits, icon: "scope",
                                  title: pt ? "Que fichas esperas?" : "What are you waiting on?",
                                  detail: pt ? "Encontra todas as esperas de uma mão em tenpai." : "Find every wait of a tenpai hand.")
                        drillCard(.discard, icon: "hand.point.up.left",
                                  title: pt ? "Melhor descarte" : "Best discard",
                                  detail: pt ? "Escolhe o descarte que deixa mais fichas vencedoras." : "Pick the discard that leaves the most winning tiles.")
                        drillCard(.score, icon: "number",
                                  title: pt ? "Conta os pontos" : "Count the points",
                                  detail: pt ? "Yaku, han, fu e pagamento, passo a passo." : "Yaku, han, fu and payment, step by step.")

                        SectionLabel(text: pt ? "Praticar a jogar" : "Practise by playing")
                        Button(action: onTable) {
                            AcademyCard {
                                Label(pt ? "Mesa Riichi com treinador" : "Coached Riichi table", systemImage: "person.3")
                                    .font(.system(size: 15, weight: .semibold, design: .rounded)).foregroundColor(Theme.text)
                                Text(pt ? "Contra bots ou com amigos no mesmo aparelho. O treinador mostra esperas, sugere descartes e avisa de furiten e mãos sem yaku."
                                        : "Against bots or friends on one device. The coach shows waits, suggests discards and warns about furiten and hands with no yaku.")
                                    .font(.system(size: 12, design: .rounded)).foregroundColor(Theme.textDim)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .frame(maxWidth: 560).padding(20).frame(maxWidth: .infinity)
                }
            }
        }
    }

    private func drillCard(_ kind: DrillKind, icon: String, title: String, detail: String) -> some View {
        let stats = progress.stats(kind)
        let pt = loc.lang == .pt
        return Button(action: { onDrill(kind) }) {
            AcademyCard {
                HStack {
                    Label(title, systemImage: icon).font(.system(size: 15, weight: .semibold, design: .rounded)).foregroundColor(Theme.text)
                    Spacer()
                    Image(systemName: "chevron.right").foregroundColor(Theme.textDim)
                }
                Text(detail).font(.system(size: 12, design: .rounded)).foregroundColor(Theme.textDim)
                if stats.answered > 0 {
                    Text(pt ? "Acertos \(stats.correct)/\(stats.answered) · melhor série \(stats.bestStreak)"
                            : "Correct \(stats.correct)/\(stats.answered) · best streak \(stats.bestStreak)")
                        .font(.system(size: 11, weight: .semibold, design: .rounded)).foregroundColor(Theme.accent)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("drill-\(kind.rawValue)")
    }
}

struct LessonView: View {
    @EnvironmentObject var loc: Localization
    @ObservedObject var progress: AcademyProgress
    let index: Int
    let onBack: () -> Void
    let onNext: (Int) -> Void

    @State private var chosen: Int?

    private var lesson: Lesson { ACADEMY_LESSONS[index] }

    var body: some View {
        let lang = loc.lang
        let pt = lang == .pt
        ZStack {
            BackgroundGlow()
            VStack(spacing: 0) {
                ScreenHeader(title: pt ? "Lição \(index + 1)" : "Lesson \(index + 1)", onBack: onBack)
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(lesson.title(lang)).font(.system(size: 26, weight: .bold, design: .rounded)).foregroundColor(Theme.text)
                        ForEach(Array(lesson.paragraphs.enumerated()), id: \.offset) { _, p in
                            Text(p(lang)).font(.system(size: 15, design: .rounded)).foregroundColor(Theme.textDim)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        ForEach(Array(lesson.examples.enumerated()), id: \.offset) { _, example in
                            AcademyCard {
                                Text(example.caption(lang)).font(.system(size: 13, weight: .semibold, design: .rounded)).foregroundColor(Theme.accent)
                                TileRow(tiles: example.tiles, maxTile: 44)
                            }
                        }
                        quiz(lang)
                    }
                    .frame(maxWidth: 620).padding(20).frame(maxWidth: .infinity)
                }
            }
        }
    }

    @ViewBuilder
    private func quiz(_ lang: Lang) -> some View {
        let pt = lang == .pt
        let q = lesson.quiz
        AcademyCard {
            SectionLabel(text: pt ? "Pergunta" : "Question")
            Text(q.question(lang)).font(.system(size: 16, weight: .semibold, design: .rounded)).foregroundColor(Theme.text)
                .fixedSize(horizontal: false, vertical: true)
            ForEach(Array(q.options.enumerated()), id: \.offset) { i, option in
                Button(action: { answer(i) }) {
                    HStack(spacing: 10) {
                        if let text = option.text {
                            Text(text(lang)).font(.system(size: 15, weight: .medium, design: .rounded)).foregroundColor(Theme.text)
                        }
                        if !option.tiles.isEmpty {
                            HStack(spacing: 3) { ForEach(Array(option.tiles.enumerated()), id: \.offset) { _, t in StudyTile(typeId: t, width: 34) } }
                        }
                        Spacer()
                        if let chosen, i == q.answer || i == chosen {
                            Image(systemName: i == q.answer ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(i == q.answer ? Theme.ok : Theme.danger)
                        }
                    }
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Theme.bgPanel2))
                }
                .buttonStyle(.plain)
                .allowsHitTesting(chosen == nil)
                .accessibilityIdentifier("quiz-option-\(i)")
            }
            if let chosen {
                Text(chosen == q.answer ? (pt ? "Certo!" : "Correct!") : (pt ? "Ainda não." : "Not quite."))
                    .font(.system(size: 15, weight: .bold, design: .rounded)).foregroundColor(chosen == q.answer ? Theme.ok : Theme.danger)
                Text(q.explanation(lang)).font(.system(size: 14, design: .rounded)).foregroundColor(Theme.textDim)
                    .fixedSize(horizontal: false, vertical: true)
                if chosen == q.answer {
                    if index + 1 < ACADEMY_LESSONS.count {
                        Button(pt ? "Próxima lição" : "Next lesson") { onNext(index + 1) }.buttonStyle(PrimaryButtonStyle())
                    } else {
                        Button(pt ? "Voltar à Academia" : "Back to the Academy", action: onBack).buttonStyle(PrimaryButtonStyle())
                    }
                } else {
                    Button(pt ? "Tentar outra vez" : "Try again") { self.chosen = nil }.buttonStyle(SecondaryButtonStyle())
                }
            }
        }
    }

    private func answer(_ i: Int) {
        chosen = i
        if i == lesson.quiz.answer { progress.markLessonDone(lesson.id) }
    }
}
