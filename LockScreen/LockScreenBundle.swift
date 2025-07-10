//
//  LockScreenBundle.swift
//  LockScreen
//
//  Created by 今井悠翔 on 2025/07/10.
//

import WidgetKit
import SwiftUI

@main
struct LockScreenBundle: WidgetBundle {
    var body: some Widget {
        LockScreen()
        LockScreenControl()
        LockScreenLiveActivity()
    }
}
