import Foundation

struct Meal: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var isSelected: Bool = true
}

/// 候補の選び方を名前を付けて保存したもの（「こってり」「さっぱり」など）
struct Preset: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var mealIDs: Set<UUID>
}

/// アプリとウィジェットで共有するデータ（App Group の UserDefaults に保存する）
enum SharedStore {
    static let baseBundleID = "com.nasa9084.gohankuji"
    static let widgetBundleSuffix = ".FortuneWidget"
    /// ウィジェットの「今の選択」ボタンに使う特別なID
    static let currentSelectionID = "current"

    /// SideStore は Bundle ID と App Group ID の末尾に Team ID を付けて署名し直す。
    /// （例: com.nasa9084.gohankuji.ABCDE12345 / group.com.nasa9084.gohankuji.ABCDE12345）
    /// 実行中の Bundle ID から App Group ID を組み立てれば、どちらの環境でも一致する。
    static var appGroupID: String {
        var id = Bundle.main.bundleIdentifier ?? baseBundleID
        if id.hasSuffix(widgetBundleSuffix) {
            id.removeLast(widgetBundleSuffix.count)
        }
        return "group." + id
    }

    static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroupID) ?? .standard
    }

    private enum Key {
        static let meals = "meals"
        static let presets = "presets"
        static let lastResult = "lastResult"
        static let lastSource = "lastSource"
    }

    static func loadMeals() -> [Meal]? { decode([Meal].self, key: Key.meals) }
    static func saveMeals(_ meals: [Meal]) { encode(meals, key: Key.meals) }

    static func loadPresets() -> [Preset]? { decode([Preset].self, key: Key.presets) }
    static func savePresets(_ presets: [Preset]) { encode(presets, key: Key.presets) }

    static var lastResult: String? { defaults.string(forKey: Key.lastResult) }
    static var lastSource: String? { defaults.string(forKey: Key.lastSource) }

    static func setLastResult(_ result: String, source: String) {
        defaults.set(result, forKey: Key.lastResult)
        defaults.set(source, forKey: Key.lastSource)
    }

    /// 以前のバージョンは通常の UserDefaults に保存していたので、初回だけ App Group 側へ移す
    static func migrateFromStandardDefaults() {
        let old = UserDefaults.standard
        let shared = defaults
        guard shared !== old else { return }
        for key in [Key.meals, Key.presets] where shared.data(forKey: key) == nil {
            if let data = old.data(forKey: key) {
                shared.set(data, forKey: key)
            }
        }
    }

    private static func decode<T: Decodable>(_ type: T.Type, key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    private static func encode<T: Encodable>(_ value: T, key: String) {
        if let data = try? JSONEncoder().encode(value) {
            defaults.set(data, forKey: key)
        }
    }
}
