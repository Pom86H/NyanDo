import SwiftUI
import WidgetKit

// HEXカラー対応の拡張
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB,
                  red: Double(r) / 255,
                  green: Double(g) / 255,
                  blue: Double(b) / 255,
                  opacity: Double(a) / 255)
    }
}

// Timeline Provider
struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), tasks: ["例: 牛乳を買う"])
    }
    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let entry = SimpleEntry(date: Date(), tasks: ["例: 牛乳を買う"])
        completion(entry)
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        // UserDefaultsのApp Groupからデータを取得する
        let sharedDefaults = UserDefaults(suiteName: "group.com.yourname.ToDo") // App Group IDに合わせる！！
        var tasks: [String] = []

        if let data = sharedDefaults?.data(forKey: "shoppingListKey"),
           let decoded = try? JSONDecoder().decode([String: [String]].self, from: data) {
            // カテゴリのすべてのアイテムを1つの配列にまとめる
            tasks = decoded.flatMap { $0.value }
        }

        let entry = SimpleEntry(date: Date(), tasks: tasks)
        let timeline = Timeline(entries: [entry], policy: .atEnd)
        completion(timeline)
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let tasks: [String]
}

// メインのウィジェットビュー
struct ToDoWidgetEntryView: View {
    var entry: Provider.Entry

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color(hex: "#FDFDFD")
            VStack(spacing: 0) {
                HStack {
                    Text("To Do")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .background(Color(hex: "#3871CA"))

                VStack(alignment: .leading, spacing: 2) {
                    ForEach(entry.tasks.prefix(5).reversed(), id: \.self) { task in
                        Text("・\(task)")
                            .font(.system(size: 14))
                            .foregroundColor(.black)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
            }
        }
    }
}

// ウィジェット本体
struct ToDoWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "ToDoWidget", provider: Provider()) { entry in
            ToDoWidgetEntryView(entry: entry)
                .containerBackground(.clear, for: .widget)
        }
    }
}
