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
    // 現在のウィジェットファミリー（サイズ）を取得
    @Environment(\.widgetFamily) var family

    var body: some View {
        // VStack全体に背景、角丸、影は適用せず、ToDoWidget内で適用する
        VStack(spacing: 0) {
            // ヘッダー部分
            HStack {
                Text("To Do 🐈‍⬛") // ヘッダータイトル
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                Spacer() // 左寄せのため
            }
            .frame(maxWidth: .infinity)
            .background(Color(hex: "#5F7F67")) // ヘッダーの背景色

            // ToDoリスト表示部分
            // ウィジェットファミリーに応じてレイアウトを調整
            Group { // Use Group to apply common modifiers to different cases
                switch family {
                case .systemSmall:
                    // 小サイズウィジェットの場合
                    LazyVGrid(
                        columns: [GridItem(.flexible())], // 1列表示
                        spacing: 4
                    ) {
                        ForEach(entry.tasks.prefix(3), id: \.self) { task in // 表示タスク数を減らす
                            HStack {
                                Image(systemName: "checkmark.square.fill")
                                    .foregroundColor(Color(hex: "#2D2A29"))
                                    .font(.system(size: 12)) // フォントサイズを調整
                                Text("・\(task)")
                                    .font(.system(size: 10)) // フォントサイズを調整
                                    .foregroundColor(.black)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .lineLimit(1)
                            }
                            .padding(.horizontal, 8) // パディングを調整
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }

                case .systemMedium:
                    // 中サイズウィジェットの場合 (既存の2列表示)
                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(), spacing: 8),
                            GridItem(.flexible(), spacing: 8)
                        ],
                        spacing: 4
                    ) {
                        ForEach(entry.tasks.prefix(8), id: \.self) { task in // 表示タスク数を8つに変更
                            HStack {
                                Image(systemName: "checkmark.square.fill")
                                    .foregroundColor(Color(hex: "#2D2A29"))
                                    .font(.system(size: 14))
                                Text("・\(task)")
                                    .font(.system(size: 12))
                                    .foregroundColor(.black)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .lineLimit(1)
                            }
                            .padding(.horizontal, 12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }

                case .systemLarge:
                    // 大サイズウィジェットの場合
                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(), spacing: 8),
                            GridItem(.flexible(), spacing: 8)
                        ],
                        spacing: 4
                    ) {
                        ForEach(entry.tasks.prefix(10), id: \.self) { task in // 表示タスク数を調整
                            HStack {
                                Image(systemName: "checkmark.square.fill")
                                    .foregroundColor(Color(hex: "#2D2A29"))
                                    .font(.system(size: 14))
                                Text("・\(task)")
                                    .font(.system(size: 12))
                                    .foregroundColor(.black)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .lineLimit(1)
                            }
                            .padding(.horizontal, 12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }

                @unknown default:
                    // 未知のウィジェットファミリーの場合のフォールバック
                    Text("Unsupported Widget Size")
            }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity) // グリッドを可能な限り広げる
            .background(Color(hex: "#FDFDFD")) // リスト部分の背景色
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity) // VStackが利用可能なスペースを全て埋める
        // ここにあった背景、角丸、影、clipped、padding(-1)はToDoWidgetに移動
    }
}

// ウィジェット本体
struct ToDoWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "ToDoWidget", provider: Provider()) { entry in
            ToDoWidgetEntryView(entry: entry)
                // ここでウィジェット全体の背景色、角丸、影、クリップを適用
                .background(Color(hex: "#FDFDFD")) // ウィジェット全体の背景色
                .cornerRadius(18) // ウィジェット全体の角丸
                .shadow(color: Color.black.opacity(0.2), radius: 3, x: 0, y: 2) // ウィジェット全体の影
                .clipped() // 角丸の外側を確実にクリップする（重要）
                .containerBackground(.clear, for: .widget) // ウィジェットのシステム背景をクリアにする
        }
        // supportedFamiliesを追加して、サポートするウィジェットサイズを宣言
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
