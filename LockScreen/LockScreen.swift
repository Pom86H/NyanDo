import WidgetKit
import SwiftUI

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), tasks: ["タスクA", "タスクB"])
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let entry = SimpleEntry(date: Date(), tasks: ["タスクA", "タスクB", "タスクC"])
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let currentDate = Date()
        let entry = SimpleEntry(date: currentDate, tasks: ["タスクA", "タスクB", "タスクC", "タスクD"])
        let timeline = Timeline(entries: [entry], policy: .atEnd)
        completion(timeline)
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let tasks: [String]
}

struct LockScreenEntryView: View {
    var entry: Provider.Entry

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(entry.tasks.prefix(4), id: \.self) { task in
                Text(task)
                    .font(.system(size: 12))
                    .lineLimit(1)
            }
        }
    }
}

struct LockScreen: Widget {
    let kind: String = "LockScreen"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            LockScreenEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("ロック画面タスクリスト")
        .description("ロック画面にタスクを表示します")
        .supportedFamilies([.accessoryRectangular])
    }
}

#Preview(as: .accessoryRectangular) {
    LockScreen()
} timeline: {
    SimpleEntry(date: .now, tasks: ["プレビュータスク1", "プレビュータスク2", "プレビュータスク3", "プレビュータスク4"])
}
