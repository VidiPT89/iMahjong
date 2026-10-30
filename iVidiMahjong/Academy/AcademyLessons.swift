import Foundation

/// Text written in both app languages side by side, so each lesson reads as one unit.
struct Bilingual {
    let pt: String
    let en: String
}

struct LessonExample {
    let caption: Bilingual
    let tiles: [String]
}

struct LessonQuiz {
    let question: Bilingual
    /// Each option is either text or a row of tiles.
    let options: [(text: Bilingual?, tiles: [String])]
    let answer: Int
    let explanation: Bilingual
}

struct Lesson {
    let id: String
    let title: Bilingual
    let paragraphs: [Bilingual]
    let examples: [LessonExample]
    let quiz: LessonQuiz
}

private func B(_ pt: String, _ en: String) -> Bilingual { Bilingual(pt: pt, en: en) }

let ACADEMY_LESSONS: [Lesson] = [
    Lesson(
        id: "tiles",
        title: B("As 136 fichas", "The 136 tiles"),
        paragraphs: [
            B("Há três naipes numerados de 1 a 9: Caracteres (萬), Círculos e Bambus. Cada ficha existe em 4 cópias.",
              "There are three suits numbered 1 to 9: Characters (萬), Circles and Bamboo. Every tile comes in 4 copies."),
            B("As honras são os 4 ventos (Este, Sul, Oeste, Norte) e os 3 dragões (branco, verde, vermelho). Não têm número e nunca formam sequências.",
              "Honors are the 4 winds (East, South, West, North) and the 3 dragons (white, green, red). They have no number and never form runs."),
            B("Os 1 e os 9 chamam-se terminais. Do 2 ao 8 são as simples, e isso vai importar para os yaku.",
              "1s and 9s are terminals. 2 to 8 are simples, which matters for yaku later."),
        ],
        examples: [
            LessonExample(caption: B("Um de cada naipe", "One of each suit"), tiles: ["m5", "p5", "s5"]),
            LessonExample(caption: B("Terminais", "Terminals"), tiles: ["m1", "m9", "p1", "s9"]),
            LessonExample(caption: B("Honras", "Honors"), tiles: ["wE", "wS", "wW", "wN", "dW", "dG", "dR"]),
        ],
        quiz: LessonQuiz(
            question: B("Qual destas fichas é uma simples?", "Which of these tiles is a simple?"),
            options: [(nil, ["m1"]), (nil, ["wE"]), (nil, ["p5"]), (nil, ["dR"])],
            answer: 2,
            explanation: B("O 5 de Círculos está entre 2 e 8. O 1 é terminal; o vento e o dragão são honras.",
                           "The 5 of Circles is between 2 and 8. The 1 is a terminal; the wind and dragon are honors.")
        )
    ),
    Lesson(
        id: "hand",
        title: B("A mão vencedora", "The winning hand"),
        paragraphs: [
            B("Tens 13 fichas. Em cada vez compras uma e descartas outra. Ganhas quando as 14 formam 4 grupos e 1 par.",
              "You hold 13 tiles. Each turn you draw one and discard one. You win when the 14 make 4 groups and 1 pair."),
            B("Um grupo é uma sequência (três seguidas do mesmo naipe, como 3-4-5 de Bambus) ou uma trinca (três iguais).",
              "A group is a run (three in a row of the same suit, like 3-4-5 Bamboo) or a triplet (three of a kind)."),
            B("Há duas exceções: sete pares diferentes (Chiitoitsu) e as treze órfãs (Kokushi Musou).",
              "There are two exceptions: seven different pairs (Chiitoitsu) and the thirteen orphans (Kokushi Musou)."),
        ],
        examples: [
            LessonExample(caption: B("Mão completa: 123m 456p 345s 777s + par de Este", "Complete: 123m 456p 345s 777s + East pair"),
                          tiles: ["m1", "m2", "m3", "p4", "p5", "p6", "s3", "s4", "s5", "s7", "s7", "s7", "wE", "wE"]),
            LessonExample(caption: B("Sete pares", "Seven pairs"),
                          tiles: ["m2", "m2", "m8", "m8", "p3", "p3", "p9", "p9", "s1", "s1", "wN", "wN", "dG", "dG"]),
        ],
        quiz: LessonQuiz(
            question: B("Qual destes grupos é válido?", "Which of these groups is valid?"),
            options: [(nil, ["s8", "s9", "s1"]), (nil, ["wE", "wS", "wW"]), (nil, ["p7", "p8", "p9"]), (nil, ["m3", "p4", "s5"])],
            answer: 2,
            explanation: B("7-8-9 de Círculos é uma sequência. Os números não dão a volta (8-9-1), as honras não fazem sequências e não se misturam naipes.",
                           "7-8-9 Circles is a run. Numbers don't wrap around (8-9-1), honors never make runs and suits can't be mixed.")
        )
    ),
    Lesson(
        id: "waits",
        title: B("Esperas (tenpai)", "Waits (tenpai)"),
        paragraphs: [
            B("Estás em tenpai quando te falta uma ficha para ganhar. As fichas que completam a mão são a tua espera.",
              "You are tenpai when one tile away from winning. The tiles that complete your hand are your wait."),
            B("Ryanmen: dois seguidos abertos dos dois lados (4-5 espera 3 ou 6). É a melhor espera, até 8 fichas.",
              "Ryanmen: two in a row open on both sides (4-5 waits on 3 or 6). The best wait, up to 8 tiles."),
            B("Kanchan: falta a do meio (4-6 espera 5). Penchan: ponta (1-2 espera 3; 8-9 espera 7). Shanpon: dois pares, qualquer um vira trinca. Tanki: uma ficha isolada à espera do par.",
              "Kanchan: missing the middle (4-6 waits on 5). Penchan: edge (1-2 waits on 3; 8-9 waits on 7). Shanpon: two pairs, either becomes a triplet. Tanki: one lone tile waiting for its pair."),
        ],
        examples: [
            LessonExample(caption: B("Ryanmen: espera 3 ou 6", "Ryanmen: waits on 3 or 6"), tiles: ["s4", "s5"]),
            LessonExample(caption: B("Kanchan: espera 5", "Kanchan: waits on 5"), tiles: ["p4", "p6"]),
            LessonExample(caption: B("Penchan: espera 3", "Penchan: waits on 3"), tiles: ["m1", "m2"]),
            LessonExample(caption: B("Shanpon: espera Este ou 9", "Shanpon: waits on East or 9"), tiles: ["wE", "wE", "s9", "s9"]),
        ],
        quiz: LessonQuiz(
            question: B("A mão está completa exceto por 7-8 de Caracteres. Que fichas esperas?", "The hand is complete except for 7-8 Characters. Which tiles do you wait on?"),
            options: [(B("Só o 9", "Only 9"), []), (B("6 ou 9", "6 or 9"), []), (B("Só o 6", "Only 6"), []), (B("7 ou 8", "7 or 8"), [])],
            answer: 1,
            explanation: B("7-8 é um ryanmen: completa com 6 (6-7-8) ou com 9 (7-8-9).",
                           "7-8 is a ryanmen: it completes with 6 (6-7-8) or with 9 (7-8-9).")
        )
    ),
    Lesson(
        id: "yaku",
        title: B("Sem yaku não há vitória", "No yaku, no win"),
        paragraphs: [
            B("No Riichi não basta ter 4 grupos e 1 par: a mão precisa de pelo menos um yaku, um padrão que dá han.",
              "In Riichi, 4 groups and a pair aren't enough: the hand needs at least one yaku, a pattern worth han."),
            B("Os mais comuns: Riichi (declarar com a mão fechada), Menzen Tsumo (ganhar por compra própria com a mão fechada), Tanyao (só simples, 2 a 8), Yakuhai (trinca de dragão, do vento da ronda ou do teu vento) e Pinfu (só sequências, par sem valor, espera ryanmen).",
              "The most common: Riichi (declared with a closed hand), Menzen Tsumo (self-draw win with a closed hand), Tanyao (simples only, 2 to 8), Yakuhai (triplet of a dragon, the round wind or your seat wind) and Pinfu (all runs, valueless pair, ryanmen wait)."),
            B("A dora soma han, mas não é um yaku: uma mão só com dora não pode ganhar.",
              "Dora adds han but is not a yaku: a hand with only dora cannot win."),
        ],
        examples: [
            LessonExample(caption: B("Tanyao: nenhuma terminal nem honra", "Tanyao: no terminals or honors"),
                          tiles: ["m2", "m3", "m4", "p3", "p4", "p5", "p6", "p7", "p8", "s4", "s4", "s4", "s6", "s6"]),
            LessonExample(caption: B("Yakuhai: trinca de dragão vermelho", "Yakuhai: red dragon triplet"), tiles: ["dR", "dR", "dR"]),
        ],
        quiz: LessonQuiz(
            question: B("Qual destes NÃO é um yaku?", "Which of these is NOT a yaku?"),
            options: [(B("Riichi", "Riichi"), []), (B("Tanyao", "Tanyao"), []), (B("Dora", "Dora"), []), (B("Yakuhai", "Yakuhai"), [])],
            answer: 2,
            explanation: B("A dora só aumenta o valor de uma mão que já tem yaku.", "Dora only raises the value of a hand that already has a yaku.")
        )
    ),
    Lesson(
        id: "closed",
        title: B("Mão fechada, chamadas e Riichi", "Closed hands, calls and Riichi"),
        paragraphs: [
            B("Chi (sequência, só do jogador à tua esquerda), Pon (trinca) e Kan (quadra) pegam no descarte de outro jogador. A mão fica aberta.",
              "Chi (a run, only from the player on your left), Pon (triplet) and Kan (quad) take another player's discard. The hand becomes open."),
            B("Uma mão aberta perde Riichi, Menzen Tsumo e Pinfu, e vários yaku valem menos 1 han (Honitsu, Ittsu, Sanshoku, Chanta).",
              "An open hand loses Riichi, Menzen Tsumo and Pinfu, and several yaku are worth 1 han less (Honitsu, Ittsu, Sanshoku, Chanta)."),
            B("Riichi: com a mão fechada e em tenpai, apostas 1000 pontos e a mão fica trancada. Ganhas 1 han, a ura-dora e, se ganhares antes da tua próxima vez sem chamadas pelo meio, Ippatsu.",
              "Riichi: closed and tenpai, you bet 1000 points and your hand locks. You get 1 han, ura-dora and, if you win before your next turn with no calls in between, Ippatsu."),
        ],
        examples: [
            LessonExample(caption: B("Pon de dragão verde (mão aberta)", "Green dragon pon (open hand)"), tiles: ["dG", "dG", "dG"]),
        ],
        quiz: LessonQuiz(
            question: B("Fizeste Pon de 5 de Círculos e estás em tenpai. Podes declarar Riichi?", "You called Pon on 5 Circles and you are tenpai. Can you declare Riichi?"),
            options: [(B("Sim", "Yes"), []), (B("Não, a mão está aberta", "No, the hand is open"), []), (B("Só por Tsumo", "Only by Tsumo"), [])],
            answer: 1,
            explanation: B("O Riichi exige a mão completamente fechada. Depois de um Pon precisas de outro yaku, como Tanyao ou Yakuhai.",
                           "Riichi needs a fully closed hand. After a Pon you need another yaku, such as Tanyao or Yakuhai.")
        )
    ),
    Lesson(
        id: "furiten",
        title: B("Furiten", "Furiten"),
        paragraphs: [
            B("Se alguma das tuas esperas está nos teus próprios descartes, estás em furiten: não podes ganhar por Ron, só por Tsumo.",
              "If any of your waits is in your own discards, you are furiten: you can't win by Ron, only by Tsumo."),
            B("Também ficas em furiten se deixares passar uma ficha vencedora, até à tua próxima compra. Em Riichi, dura até ao fim da mão.",
              "You are also furiten after letting a winning tile go by, until your next draw. In Riichi, it lasts until the hand ends."),
            B("Na mesa com treinador, o iVidiMahjong avisa-te quando estás em furiten.",
              "At the coached table, iVidiMahjong warns you when you are furiten."),
        ],
        examples: [
            LessonExample(caption: B("Esperas 3 ou 6 de Círculos…", "Waiting on 3 or 6 Circles…"), tiles: ["p4", "p5"]),
            LessonExample(caption: B("…mas já descartaste o 6", "…but you already discarded the 6"), tiles: ["p6"]),
        ],
        quiz: LessonQuiz(
            question: B("Esperas 3 ou 6 de Círculos e já descartaste um 6. Um adversário descarta o 3. Podes fazer Ron?",
                        "You wait on 3 or 6 Circles and discarded a 6 earlier. An opponent discards the 3. Can you call Ron?"),
            options: [(B("Sim, o 3 não está nos meus descartes", "Yes, the 3 isn't in my discards"), []), (B("Não, estou em furiten", "No, I'm furiten"), [])],
            answer: 1,
            explanation: B("O furiten conta todas as esperas: basta uma delas estar nos teus descartes. Só podes ganhar por Tsumo.",
                           "Furiten covers every wait: one of them in your discards is enough. You can only win by Tsumo.")
        )
    ),
    Lesson(
        id: "dora",
        title: B("Dora", "Dora"),
        paragraphs: [
            B("No início da mão vira-se um indicador. A dora é a ficha seguinte: depois do 9 vem o 1.",
              "At the start of the hand an indicator is flipped. Dora is the next tile: after 9 comes 1."),
            B("Ventos: Este → Sul → Oeste → Norte → Este. Dragões: branco → verde → vermelho → branco.",
              "Winds: East → South → West → North → East. Dragons: white → green → red → white."),
            B("Cada dora na mão vale 1 han. Cada Kan revela mais um indicador.",
              "Each dora in your hand is worth 1 han. Every Kan reveals one more indicator."),
        ],
        examples: [
            LessonExample(caption: B("Indicador 9 de Caracteres → dora 1", "Indicator 9 Characters → dora 1"), tiles: ["m9", "m1"]),
            LessonExample(caption: B("Indicador verde → dora vermelho", "Indicator green → dora red"), tiles: ["dG", "dR"]),
        ],
        quiz: LessonQuiz(
            question: B("O indicador é o Norte. Qual é a dora?", "The indicator is North. What is the dora?"),
            options: [(nil, ["wW"]), (nil, ["wE"]), (nil, ["wN"]), (nil, ["dW"])],
            answer: 1,
            explanation: B("Os ventos dão a volta: depois do Norte vem o Este.", "Winds wrap around: after North comes East.")
        )
    ),
    Lesson(
        id: "scoring",
        title: B("Han, fu e pontos", "Han, fu and points"),
        paragraphs: [
            B("Han: soma dos yaku e da dora. Fu: parte da forma da mão. Base 20; +10 por Ron com a mão fechada; +2 por Tsumo; trincas 2 a 8 (quadras 8 a 32); par de dragão ou vento próprio +2; espera kanchan, penchan ou tanki +2. Arredonda-se para cima à dezena (mínimo 30).",
              "Han: the sum of yaku and dora. Fu: from the hand's shape. Base 20; +10 for a closed Ron; +2 for Tsumo; triplets 2 to 8 (quads 8 to 32); dragon or own-wind pair +2; kanchan, penchan or tanki wait +2. Round up to the next 10 (minimum 30)."),
            B("Exceções: Pinfu vale sempre 30 fu por Ron e 20 por Tsumo; sete pares valem 25.",
              "Exceptions: Pinfu is always 30 fu on Ron and 20 on Tsumo; seven pairs is 25."),
            B("Pontos base = fu × 2^(han + 2). Ron: quem descartou paga base × 4 (base × 6 se ganhar o dealer). Com 5 han é Mangan (8000), 6–7 Haneman, 8–10 Baiman, 11–12 Sanbaiman, 13+ Yakuman.",
              "Base points = fu × 2^(han + 2). Ron: the discarder pays base × 4 (base × 6 if the dealer wins). 5 han is Mangan (8000), 6–7 Haneman, 8–10 Baiman, 11–12 Sanbaiman, 13+ Yakuman."),
        ],
        examples: [],
        quiz: LessonQuiz(
            question: B("3 han, 30 fu, Ron, não és dealer. Quanto recebes?", "3 han, 30 fu, Ron, you are not dealer. How much do you get?"),
            options: [(B("2000", "2000"), []), (B("3900", "3900"), []), (B("5800", "5800"), []), (B("7700", "7700"), [])],
            answer: 1,
            explanation: B("30 × 2^5 = 960 de base; × 4 = 3840, arredondado à centena = 3900.",
                           "30 × 2^5 = 960 base; × 4 = 3840, rounded up to the hundred = 3900.")
        )
    ),
]

/// One-line explanations shown when a hand is won, keyed by the engine's yaku name.
let YAKU_EXPLANATIONS: [String: Bilingual] = [
    "Riichi": B("Declaraste Riichi com a mão fechada.", "You declared Riichi with a closed hand."),
    "Double Riichi": B("Riichi no primeiro descarte, sem chamadas antes.", "Riichi on your first discard, before any call."),
    "Ippatsu": B("Ganhaste antes da tua vez seguinte ao Riichi.", "You won before your next turn after Riichi."),
    "Menzen Tsumo": B("Compraste a ficha vencedora com a mão fechada.", "You drew the winning tile with a closed hand."),
    "Haitei Raoyue": B("Ganhaste com a última ficha da muralha.", "You won on the last tile of the wall."),
    "Houtei Raoyui": B("Ganhaste com o último descarte.", "You won on the very last discard."),
    "Rinshan Kaihou": B("Ganhaste com a ficha extra de um Kan.", "You won on the replacement tile of a Kan."),
    "Tanyao": B("Só simples: nenhum 1, 9 ou honra.", "Simples only: no 1s, 9s or honors."),
    "Honroutou": B("Só terminais e honras.", "Only terminals and honors."),
    "Yakuhai": B("Trinca de dragão, do vento da ronda ou do teu vento.", "Triplet of a dragon, the round wind or your seat wind."),
    "Pinfu": B("Só sequências, par sem valor e espera de dois lados.", "All runs, a valueless pair and a two-sided wait."),
    "Iipeiko": B("Duas sequências iguais, mão fechada.", "Two identical runs, closed hand."),
    "Ryanpeikou": B("Dois pares de sequências iguais, mão fechada.", "Two pairs of identical runs, closed hand."),
    "Sanshoku Doujun": B("A mesma sequência nos três naipes.", "The same run in all three suits."),
    "Ittsu": B("1-2-3, 4-5-6 e 7-8-9 do mesmo naipe.", "1-2-3, 4-5-6 and 7-8-9 of one suit."),
    "Sanshoku Doukou": B("A mesma trinca nos três naipes.", "The same triplet in all three suits."),
    "Sankantsu": B("Três quadras.", "Three quads."),
    "Toitoi": B("Só trincas.", "Triplets only."),
    "Sanankou": B("Três trincas escondidas.", "Three concealed triplets."),
    "Junchan": B("Todos os grupos e o par têm um 1 ou um 9, sem honras.", "Every group and the pair hold a 1 or 9, no honors."),
    "Chanta": B("Todos os grupos e o par têm terminal ou honra.", "Every group and the pair hold a terminal or honor."),
    "Honitsu": B("Um só naipe mais honras.", "One suit plus honors."),
    "Chinitsu": B("Um só naipe, sem honras.", "One suit, no honors."),
    "Shousangen": B("Duas trincas de dragão e o par do terceiro.", "Two dragon triplets and a pair of the third."),
    "Chiitoitsu": B("Sete pares diferentes.", "Seven different pairs."),
    "Kokushi Musou": B("Os treze órfãos.", "The thirteen orphans."),
    "Suuankou": B("Quatro trincas escondidas.", "Four concealed triplets."),
    "Tsuuiisou": B("Só honras.", "Honors only."),
    "Chinroutou": B("Só terminais.", "Terminals only."),
    "Ryuuiisou": B("Só fichas verdes.", "Green tiles only."),
    "Daisangen": B("Trincas dos três dragões.", "Triplets of all three dragons."),
    "Suukantsu": B("Quatro quadras.", "Four quads."),
]

/// "Yakuhai (dR)" → "Yakuhai", so the explanation table stays keyed by family.
func yakuExplanationKey(_ name: String) -> String {
    name.hasPrefix("Yakuhai") ? "Yakuhai" : name
}
