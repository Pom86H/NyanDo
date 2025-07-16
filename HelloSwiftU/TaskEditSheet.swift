//
//  TaskEditSheet.swift
//  HelloSwiftU
//
//  Created by 今井悠翔 on 2025/07/16.
//

import Foundation
import SwiftUI

struct TaskEditSheet: View {
    @Binding var item: ShoppingItem
    let onSave: (ShoppingItem) -> Void
    @Environment(\.dismiss) var dismiss

    @State private var editedName: String
    @State private var editedNote: String
    @State private var editedDueDate: Date?
    @State private var enableDueDate: Bool

    init(item: Binding<ShoppingItem>, onSave: @escaping (ShoppingItem) -> Void) {
        self._item = item
        self.onSave = onSave
        _editedName = State(initialValue: item.wrappedValue.name)
        _editedNote = State(initialValue: item.wrappedValue.note ?? "")
        _editedDueDate = State(initialValue: item.wrappedValue.dueDate)
        _enableDueDate = State(initialValue: item.wrappedValue.dueDate != nil)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("タスク名")) {
                    TextField("タスク名", text: $editedName)
                }

                Section(header: Text("メモ")) {
                    TextEditor(text: $editedNote)
                        .frame(height: 100)
                }

                Section {
                    Toggle("期限を設定する", isOn: $enableDueDate)
                    if enableDueDate {
                        DatePicker("期限", selection: Binding(
                            get: { editedDueDate ?? Date() },
                            set: { editedDueDate = $0 }
                        ), displayedComponents: [.date, .hourAndMinute])
                        .environment(\.locale, Locale(identifier: "ja_JP"))
                    }
                }
            }
            .navigationTitle("タスクを編集")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        item.name = editedName
                        item.note = editedNote.isEmpty ? nil : editedNote
                        item.dueDate = enableDueDate ? editedDueDate : nil
                        onSave(item)
                        dismiss()
                    }
                    .disabled(editedName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
