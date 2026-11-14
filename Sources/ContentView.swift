import SwiftUI
import WidgetKit

struct ContentView: View {
    @State private var meals: [Meal] = []
    @AppStorage("sortOrder") private var sortOrder: SortOrder = .name
    @State private var presets: [Preset] = []
    @State private var isSavingPreset = false
    @State private var newPresetName = ""
    @State private var newMealName = ""
    @State private var isAddingMeal = false
    @State private var result: String?
    @State private var resultMealID: UUID?
    @State private var editingMeal: EditTarget?
    @Environment(\.openURL) private var openURL
    @State private var isRolling = false
    @State private var hapticTrigger = 0

    private let defaultMeals = ["カレー", "ラーメン", "寿司", "パスタ", "牛丼", "定食", "ハンバーガー", "そば"]
    private let defaultPresets: [(name: String, meals: [String])] = [
        ("こってり", ["カレー", "ラーメン", "牛丼", "ハンバーガー"]),
        ("さっぱり", ["寿司", "そば", "定食"]),
    ]

    private var selectedMeals: [Meal] { meals.filter(\.isSelected) }
    /// 画面に出す順番。保存順（追加順）はそのままにして、表示だけ並べ替える
    private var displayedMeals: [Meal] {
        switch sortOrder {
        case .added:
            return meals
        case .name:
            return meals.sorted { $0.sortKey.localizedStandardCompare($1.sortKey) == .orderedAscending }
        case .selectedFirst:
            return meals.enumerated()
                .sorted { a, b in
                    if a.element.isSelected != b.element.isSelected { return a.element.isSelected }
                    return a.offset < b.offset
                }
                .map(\.element)
        }
    }

    private func binding(for id: UUID) -> Binding<Meal> {
        Binding(
            get: { meals.first { $0.id == id } ?? Meal(name: "") },
            set: { newValue in
                if let i = meals.firstIndex(where: { $0.id == id }) { meals[i] = newValue }
            }
        )
    }

    private var trimmedName: String { newMealName.trimmingCharacters(in: .whitespaces) }

    var body: some View {
        List {
            Section {
                ForEach(displayedMeals) { item in
                    MealRow(meal: binding(for: item.id)) {
                        editingMeal = EditTarget(id: item.id)
                    }
                }
                .onDelete { offsets in
                    let ids = Set(offsets.map { displayedMeals[$0].id })
                    meals.removeAll { ids.contains($0.id) }
                }
            } header: {
                HStack {
                    Text("候補（\(selectedMeals.count) / \(meals.count) 件を選択中）")
                    Spacer()
                    Button {
                        newMealName = ""
                        isAddingMeal = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .padding(.trailing, 8)
                    Menu {
                        Picker("並び順", selection: $sortOrder) {
                            ForEach(SortOrder.allCases, id: \.self) { order in
                                Text(order.title).tag(order)
                            }
                        }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down")
                    }
                    .padding(.trailing, 8)
                    Menu {
                        Button("すべて選択") { setAll(true) }
                        Button("すべて解除") { setAll(false) }
                    } label: {
                        Image(systemName: "checklist")
                    }
                }
            }
        }
        // プリセットは画面上端に固定する。
        // List の行の中に置くと、行内の contextMenu が先頭の1つしか効かないため
        .safeAreaInset(edge: .top, spacing: 0) {
            presetBar
        }
        // 結果とボタンは画面下端に固定し、リストだけがスクロールする
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 12) {
                // 結果はくじを引いたあとだけ表示する
                if isRolling || result != nil {
                    resultView
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                drawButton
            }
            .animation(.snappy, value: result == nil)
            .padding()
            .background(.bar)
        }
        .onAppear(perform: load)
        .onChange(of: meals) { save() }
        .onChange(of: presets) { savePresets() }
        .alert("候補を追加", isPresented: $isAddingMeal) {
            TextField("食事の名前（例: 焼き鳥）", text: $newMealName)
            Button("追加", action: addMeal)
            Button("キャンセル", role: .cancel) {}
        }
        .alert("プリセットを保存", isPresented: $isSavingPreset) {
            TextField("名前（例: こってり）", text: $newPresetName)
            Button("保存", action: addPreset)
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("今選んでいる\(selectedMeals.count)件を保存します")
        }
        .sheet(item: $editingMeal) { target in
            if let i = meals.firstIndex(where: { $0.id == target.id }) {
                MealEditView(meal: $meals[i])
            }
        }
        .sensoryFeedback(.success, trigger: hapticTrigger) // 決まった瞬間に振動
    }

    // MARK: - 部品

    private var presetBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(presets) { preset in
                    Button {
                        apply(preset)
                    } label: {
                        chip(preset.name, isActive: isActive(preset))
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button("今の選択で上書き", systemImage: "square.and.arrow.down") {
                            overwrite(preset)
                        }
                        Button("削除", systemImage: "trash", role: .destructive) {
                            presets.removeAll { $0.id == preset.id }
                        }
                    }
                }

                Button {
                    newPresetName = ""
                    isSavingPreset = true
                } label: {
                    chip("＋ 保存", isActive: false)
                }
                .buttonStyle(.plain)
                .disabled(selectedMeals.isEmpty)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(.bar)
    }

    private func chip(_ title: String, isActive: Bool) -> some View {
        Text(title)
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .foregroundStyle(isActive ? Color.white : Color.primary)
            .background(isActive ? Color.accentColor : Color(.secondarySystemFill), in: Capsule())
    }

    private var resultView: some View {
        VStack(spacing: 4) {
            Text(isRolling ? "抽選中…" : "今日のごはんは")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(result ?? " ")
                .font(.system(size: 40, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.5)

            if !isRolling, let meal = meals.first(where: { $0.id == resultMealID }) {
                if let memo = meal.memo, !memo.isEmpty {
                    Text(memo)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                if let url = meal.mapsURL {
                    Button {
                        openURL(url)
                    } label: {
                        Label(meal.placeIsLink ? "Google Mapsで開く" : "道案内", systemImage: "map")
                    }
                    .buttonStyle(.bordered)
                    .padding(.top, 4)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var drawButton: some View {
        Button(action: draw) {
            Text(isRolling ? "抽選中…" : "くじを引く")
                .font(.title3.bold())
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
        }
        .buttonStyle(.borderedProminent)
        .disabled(selectedMeals.isEmpty || isRolling)
    }

    // MARK: - 処理

    private func draw() {
        guard !selectedMeals.isEmpty, !isRolling else { return }
        isRolling = true
        Task {
            // 候補をパラパラ切り替えて、だんだん遅くする演出
            for i in 0..<14 {
                result = selectedMeals.randomElement()?.name
                try? await Task.sleep(for: .milliseconds(40 + i * 15))
            }
            let pick = selectedMeals.randomElement()
            result = pick?.name
            resultMealID = pick?.id
            if let result {
                SharedStore.setLastResult(result, source: "アプリ")
                WidgetCenter.shared.reloadAllTimelines()
            }
            isRolling = false
            hapticTrigger += 1
        }
    }

    private func addMeal() {
        guard !trimmedName.isEmpty else { return }
        meals.append(Meal(name: trimmedName))
        newMealName = ""
    }

    private var existingMealIDs: Set<UUID> { Set(meals.map(\.id)) }

    /// 今の選択がプリセットの内容とぴったり同じなら、そのプリセットを強調表示する
    private func isActive(_ preset: Preset) -> Bool {
        let ids = preset.mealIDs.intersection(existingMealIDs)
        return !ids.isEmpty && ids == Set(selectedMeals.map(\.id))
    }

    private func apply(_ preset: Preset) {
        for i in meals.indices {
            meals[i].isSelected = preset.mealIDs.contains(meals[i].id)
        }
    }

    private func addPreset() {
        let name = newPresetName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        presets.append(Preset(name: name, mealIDs: Set(selectedMeals.map(\.id))))
    }

    private func overwrite(_ preset: Preset) {
        guard let i = presets.firstIndex(where: { $0.id == preset.id }) else { return }
        presets[i].mealIDs = Set(selectedMeals.map(\.id))
    }

    private func setAll(_ selected: Bool) {
        for i in meals.indices { meals[i].isSelected = selected }
    }

    private func load() {
        SharedStore.migrateFromStandardDefaults()

        if let saved = SharedStore.loadMeals(), !saved.isEmpty {
            meals = saved
        } else {
            meals = defaultMeals.map { Meal(name: $0) }
        }

        if let saved = SharedStore.loadPresets() {
            presets = saved
        } else {
            // 初回だけ、名前が一致する候補でデフォルトのプリセットを作る
            presets = defaultPresets.compactMap { def in
                let ids = Set(meals.filter { def.meals.contains($0.name) }.map(\.id))
                return ids.isEmpty ? nil : Preset(name: def.name, mealIDs: ids)
            }
        }
    }

    private func save() {
        SharedStore.saveMeals(meals)
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func savePresets() {
        SharedStore.savePresets(presets)
        WidgetCenter.shared.reloadAllTimelines()
    }
}

enum SortOrder: String, CaseIterable {
    case name, added, selectedFirst

    var title: String {
        switch self {
        case .name: "名前順"
        case .added: "追加順"
        case .selectedFirst: "選択中を上に"
        }
    }
}

extension Meal {
    /// 名前順に並べるためのキー。漢字も読み（ひらがな）に直して五十音順にする
    var sortKey: String {
        let text = name as NSString
        let tokenizer = CFStringTokenizerCreate(
            nil, text, CFRange(location: 0, length: text.length),
            kCFStringTokenizerUnitWordBoundary, Locale(identifier: "ja") as CFLocale
        )
        var reading = ""
        var lastEnd = 0
        while CFStringTokenizerAdvanceToNextToken(tokenizer) != [] {
            let range = CFStringTokenizerGetCurrentTokenRange(tokenizer)
            if range.location > lastEnd {
                reading += text.substring(with: NSRange(location: lastEnd, length: range.location - lastEnd))
            }
            let token = text.substring(with: NSRange(location: range.location, length: range.length))
            if let latin = CFStringTokenizerCopyCurrentTokenAttribute(tokenizer, kCFStringTokenizerAttributeLatinTranscription) as? String,
               token.unicodeScalars.contains(where: { (0x4E00...0x9FFF).contains($0.value) }) {
                // 漢字を含む語だけ、ローマ字の読みをひらがなに戻して使う
                reading += latin.applyingTransform(.latinToHiragana, reverse: false) ?? token
            } else {
                reading += token
            }
            lastEnd = range.location + range.length
        }
        if lastEnd < text.length {
            reading += text.substring(from: lastEnd)
        }
        // カタカナもひらがなにそろえる
        return reading.applyingTransform(.hiraganaToKatakana, reverse: true) ?? reading
    }
}

/// 候補リストの1行
struct MealRow: View {
    @Binding var meal: Meal
    var onEdit: () -> Void

    var body: some View {
        // 1行に2つボタンを置くので borderless にする（行全体が1つのボタンにならないように）
        HStack {
            Button {
                meal.isSelected.toggle()
            } label: {
                HStack {
                    Image(systemName: meal.isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(meal.isSelected ? Color.accentColor : .secondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(meal.name)
                            .foregroundStyle(.primary)
                        // お店が登録されていれば、名前の下に灰色で小さく出す
                        if meal.mapsURL != nil {
                            Label(
                                meal.placeIsLink ? "Google Mapsのお店" : (meal.place ?? ""),
                                systemImage: "map"
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        }
                    }
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)

            Button(action: onEdit) {
                Image(systemName: "info.circle")
            }
            .buttonStyle(.borderless)
        }
    }
}

struct EditTarget: Identifiable {
    let id: UUID
}

/// 候補の名前・お店・メモを編集する画面
struct MealEditView: View {
    @Binding var meal: Meal
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("名前") {
                    TextField("名前", text: $meal.name)
                }

                Section {
                    TextField("リンク、住所、または店名", text: $meal.place.orEmpty, axis: .vertical)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    if let url = meal.mapsURL {
                        Link(destination: url) {
                            Label(meal.placeIsLink ? "Google Mapsで開いて確認" : "道案内を試す", systemImage: "map")
                        }
                    }
                } header: {
                    Text("お店（Google Maps）")
                } footer: {
                    Text("Google Mapsの「共有」→「リンクをコピー」で取ったリンクを貼るとお店のページが、住所や店名を書くとそこへの道案内が開きます。")
                }

                Section("メモ") {
                    TextField("営業時間、おすすめメニューなど", text: $meal.memo.orEmpty, axis: .vertical)
                }
            }
            .navigationTitle("候補を編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") { dismiss() }
                }
            }
        }
    }
}

private extension Binding where Value == String? {
    /// 空文字は nil として保存する
    var orEmpty: Binding<String> {
        Binding<String>(
            get: { wrappedValue ?? "" },
            set: { wrappedValue = $0.isEmpty ? nil : $0 }
        )
    }
}

#Preview {
    ContentView()
}
