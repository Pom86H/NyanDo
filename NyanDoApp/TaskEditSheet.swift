//  Created by haruka on 2025/07/16.

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

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy/MM/dd HH:mm"
        return formatter
    }

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
            ZStack {
                // 背景色を画面全体に
                Color(red: 0.988, green: 0.976, blue: 0.961)
                    .ignoresSafeArea()
                VStack(spacing: 16) {
                    HStack {
                        Button(action: {
                            dismiss()
                        }) {
                            Text("キャンセル")
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.gray.opacity(0.15))
                                .foregroundColor(.gray)
                                .clipShape(Capsule())
                        }

                        Spacer()

                        Button {
                            item.name = editedName
                            item.note = editedNote.isEmpty ? nil : editedNote
                            item.dueDate = enableDueDate ? editedDueDate : nil
                            onSave(item)
                            dismiss()
                        } label: {
                            Text("保存")
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color(red: 0.373, green: 0.498, blue: 0.404))
                                .foregroundColor(.white)
                                .clipShape(Capsule())
                        }
                        .disabled(editedName.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    .padding(.horizontal)
                    .padding(.top)

                    HStack {
                        Text("タスクを編集")
                            .font(.system(size: 28, weight: .bold))
                        Spacer()
                    }
                    .padding(.horizontal)

                    // タスク名フィールド
                    VStack(alignment: .leading, spacing: 8) {
                        Text("タスク名")
                            .font(.footnote)
                            .foregroundColor(.gray)
                        TextField("タスク名", text: $editedName)
                            .padding(12)
                            .background(Color.white)
                            .cornerRadius(12)
                    }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(16)
                    .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
                    .padding(.horizontal)

                    // メモエリア
                    VStack(alignment: .leading, spacing: 8) {
                        Text("メモ")
                            .font(.footnote)
                            .foregroundColor(.gray)
                        TextEditor(text: $editedNote)
                            .frame(height: 100)
                            .padding(8)
                            .background(Color.white)
                            .cornerRadius(12)
                    }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(16)
                    .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
                    .padding(.horizontal)

                    // 期限設定
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("期限を設定する", isOn: $enableDueDate)
                            .toggleStyle(SwitchToggleStyle(tint: .accentColor))
                        if enableDueDate {
                            VStack(alignment: .leading, spacing: 8) {
                                DatePicker("", selection: Binding(
                                    get: { editedDueDate ?? Date() },
                                    set: { editedDueDate = $0 }
                                ), displayedComponents: [.date, .hourAndMinute])
                                .labelsHidden()
                                .environment(\.locale, Locale(identifier: "ja_JP"))
                                .environment(\.calendar, Calendar(identifier: .gregorian))
                            }
                            .padding()
                            .background(Color.white)
                            .cornerRadius(16)
                            .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
                        }
                    }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(16)
                    .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
                    .padding(.horizontal)

                    Spacer()
                }
            }
            .background(Color(red: 0.988, green: 0.976, blue: 0.961).ignoresSafeArea())
        }
    }
}
