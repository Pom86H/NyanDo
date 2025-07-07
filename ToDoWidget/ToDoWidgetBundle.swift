//
//  ToDoWidgetBundle.swift
//  ToDoWidget
//
//  Created by 今井悠翔 on 2025/07/04.
//

import WidgetKit
import SwiftUI

@main
struct ToDoWidgetBundle: WidgetBundle {
    var body: some Widget {
        ToDoWidget()
        ToDoWidgetControl()
        ToDoWidgetLiveActivity()
    }
}
