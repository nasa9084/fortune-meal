import SwiftUI
import WidgetKit

struct ContentView: View {
    @State private var meals: [Meal] = []
    @State private var presets: [Preset] = []
    @State private var isSavingPreset = false
    @State private var newPresetName = ""
    @State private var newMealName = ""
    @State private var result: String?
    @State private var isRolling = false
    @State private var hapticTrigger = 0

    private let defaultMeals = ["カレー", "ラーメン", "寿司", "パスタ", "牛丼", "定食", "ハンバーガー", "そば"]
    private let defaultPresets: [(name: String, meals: [String])] = [
        ("こってり", ["カレー", "ラーメン", "牛丼", "ハンバーガー"]),
        ("さっぱり", ["寿司", "そば", "定食"]),
    ]

    private var selectedMeals: [Meal] { meals.filter(\.isSelected) }
    private var trimmedName: String { newMealName.trimmingCharacters(in: .whitespaces) }

    var body: some View {
        List {
            Section {
                ForEach($meals) { $meal in
                    Button {
                        meal.isSelected.toggle()
                    } label: {
                        HStack {
                            Image(systemName: meal.isSelected ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(meal.isSelected ? Color.accentColor : .secondary)
                            Text(meal.name)
                                .foregroundStyle(.primary)
                        }
                    }
                }
                .onDelete { meals.remove(atOffsets: $0) }
            } header: {
                HStack {
                    Text("候補（\(selectedMeals.count) / \(meals.count) 件を選択中）")
                    Spacer()
                    Menu {
                        Button("すべて選択") { setAll(true) }
                        Button("すべて解除") { setAll(false) }
                    } label: {
                        Image(systemName: "checklist")
                    }
                }
            }

            Section {
                HStack {
                    TextField("食事を追加", text: $newMealName)
                        .onSubmit(addMeal)
                    Button("追加", action: addMeal)
                        .disabled(trimmedName.isEmpty)
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
                resultView
                drawButton
            }
            .padding()
            .background(.bar)
        }
        .onAppear(perform: load)
        .onChange(of: meals) { save() }
        .onChange(of: presets) { savePresets() }
        .alert("プリセットを保存", isPresented: $isSavingPreset) {
            TextField("名前（例: こってり）", text: $newPresetName)
            Button("保存", action: addPreset)
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("今選んでいる\(selectedMeals.count)件を保存します")
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
            Text(isRolling ? "抽選中…" : (result == nil ? "今日のごはんは？" : "今日のごはんは"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(result ?? "？")
                .font(.system(size: 40, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
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
            result = selectedMeals.randomElement()?.name
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

#Preview {
    ContentView()
}
