import Foundation

struct Meal: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var isSelected: Bool = true
    /// Google Maps の共有リンク、または住所・店名
    var place: String?
    var memo: String?
}

extension Meal {
    private var trimmedPlace: String? {
        guard let place = place?.trimmingCharacters(in: .whitespacesAndNewlines), !place.isEmpty else { return nil }
        return place
    }

    /// place がリンクならそのまま開く（お店のページ）。住所・店名なら Google Maps の経路案内を開く
    var placeIsLink: Bool {
        guard let place = trimmedPlace, let url = URL(string: place) else { return false }
        return url.scheme == "https" || url.scheme == "http"
    }

    var mapsURL: URL? {
        guard let place = trimmedPlace else { return nil }
        if placeIsLink { return URL(string: place) }
        var components = URLComponents(string: "https://www.google.com/maps/dir/")!
        components.queryItems = [
            URLQueryItem(name: "api", value: "1"),
            URLQueryItem(name: "destination", value: place),
        ]
        return components.url
    }
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
