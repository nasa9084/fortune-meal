import AppIntents
import SwiftUI
import WidgetKit

// MARK: - くじを引く（ウィジェットのボタンから実行される）

struct DrawIntent: AppIntent {
    static var title: LocalizedStringResource = "くじを引く"
    static var isDiscoverable = false

    @Parameter(title: "プリセット")
    var presetID: String

    init() {}

    init(presetID: String) {
        self.presetID = presetID
    }

    func perform() async throws -> some IntentResult {
        let meals = SharedStore.loadMeals() ?? []
        let candidates: [Meal]
        let source: String

        if presetID == SharedStore.currentSelectionID {
            candidates = meals.filter(\.isSelected)
            source = "今の選択"
        } else if let preset = SharedStore.loadPresets()?.first(where: { $0.id.uuidString == presetID }) {
            candidates = meals.filter { preset.mealIDs.contains($0.id) }
            source = preset.name
        } else {
            return .result()
        }

        if let pick = candidates.randomElement() {
            SharedStore.setLastResult(pick.name, source: source)
        }
        return .result()
    }
}

// MARK: - タイムライン

struct DrawButton: Hashable {
    let id: String
    let title: String
}

struct FortuneEntry: TimelineEntry {
    let date: Date
    let result: String?
    let source: String?
    let buttons: [DrawButton]
}

struct FortuneProvider: TimelineProvider {
    func placeholder(in context: Context) -> FortuneEntry {
        FortuneEntry(
            date: .now,
            result: "カレー",
            source: "こってり",
            buttons: [
                DrawButton(id: "current", title: "今の選択"),
                DrawButton(id: "a", title: "こってり"),
                DrawButton(id: "b", title: "さっぱり"),
            ]
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (FortuneEntry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<FortuneEntry>) -> Void) {
        // 内容が変わるのはボタンを押したときかアプリで編集したときだけなので、自動更新はしない
        completion(Timeline(entries: [currentEntry()], policy: .never))
    }

    private func currentEntry() -> FortuneEntry {
        let presets = SharedStore.loadPresets() ?? []
        return FortuneEntry(
            date: .now,
            result: SharedStore.lastResult,
            source: SharedStore.lastSource,
            buttons: [DrawButton(id: SharedStore.currentSelectionID, title: "今の選択")]
                + presets.map { DrawButton(id: $0.id.uuidString, title: $0.name) }
        )
    }
}

// MARK: - 見た目

struct FortuneWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: FortuneEntry

    private var maxButtons: Int {
        switch family {
        case .systemSmall: 2
        case .systemMedium: 4
        default: 8
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.source.map { "\($0)から" } ?? "今日のごはんは")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(entry.result ?? "？")
                    .font(.title2.bold())
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .contentTransition(.opacity)
            }

            Spacer(minLength: 0)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                ForEach(Array(entry.buttons.prefix(maxButtons)), id: \.self) { button in
                    Button(intent: DrawIntent(presetID: button.id)) {
                        Text(button.title)
                            .font(.caption.bold())
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.orange)
                }
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

struct FortuneWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "FortuneWidget", provider: FortuneProvider()) { entry in
            FortuneWidgetView(entry: entry)
        }
        .configurationDisplayName("ごはんくじ")
        .description("プリセットを選んでくじを引けます")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

@main
struct FortuneWidgetBundle: WidgetBundle {
    var body: some Widget {
        FortuneWidget()
    }
}
