import SwiftUI

struct Meal: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var isSelected: Bool = true
}

struct ContentView: View {
    // 候補リストを端末に保存する（アプリを閉じても残る）
    @AppStorage("meals") private var mealsData: Data = Data()

    @State private var meals: [Meal] = []
    @State private var newMealName = ""
    @State private var result: String?
    @State private var isRolling = false
    @State private var hapticTrigger = 0

    private let defaultMeals = ["カレー", "ラーメン", "寿司", "パスタ", "牛丼", "定食", "ハンバーガー", "そば"]

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
        .sensoryFeedback(.success, trigger: hapticTrigger) // 決まった瞬間に振動
    }

    // MARK: - 部品

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
            isRolling = false
            hapticTrigger += 1
        }
    }

    private func addMeal() {
        guard !trimmedName.isEmpty else { return }
        meals.append(Meal(name: trimmedName))
        newMealName = ""
    }

    private func setAll(_ selected: Bool) {
        for i in meals.indices { meals[i].isSelected = selected }
    }

    private func load() {
        if let saved = try? JSONDecoder().decode([Meal].self, from: mealsData), !saved.isEmpty {
            meals = saved
        } else {
            meals = defaultMeals.map { Meal(name: $0) }
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(meals) {
            mealsData = data
        }
    }
}

#Preview {
    ContentView()
}
