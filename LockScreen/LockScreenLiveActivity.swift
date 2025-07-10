//
//  LockScreenLiveActivity.swift
//  LockScreen
//
//  Created by 今井悠翔 on 2025/07/10.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct LockScreenAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct LockScreenLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LockScreenAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension LockScreenAttributes {
    fileprivate static var preview: LockScreenAttributes {
        LockScreenAttributes(name: "World")
    }
}

extension LockScreenAttributes.ContentState {
    fileprivate static var smiley: LockScreenAttributes.ContentState {
        LockScreenAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: LockScreenAttributes.ContentState {
         LockScreenAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: LockScreenAttributes.preview) {
   LockScreenLiveActivity()
} contentStates: {
    LockScreenAttributes.ContentState.smiley
    LockScreenAttributes.ContentState.starEyes
}
