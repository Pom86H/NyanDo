// MARK: - ModernButtonStyle
struct ModernButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(Color(hex: "#FDFDFD"))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(hex: "#5F7F67"))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 2)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.2), value: configuration.isPressed)
    }
}
import SwiftUI
import WidgetKit

struct ContentView: View {
    // MARK: - State Variables
    @State private var newItem: String = "" // 新しいアイテムの入力用
    @State private var selectedCategory: String = "食品" // アイテム追加時に選択されるカテゴリ
    @State private var shoppingList: [String: [String]] = [:] // 買い物リストのデータ (カテゴリごとのアイテムの辞書)
    @State private var categories: [String] = ["食品", "日用品", "その他"] // カテゴリの一覧
    @State private var newCategory: String = "" // 新しいカテゴリの入力用
    @State private var showAddTaskSheet = false
    @State private var isExpanded: Bool = false
    @State private var showAddItemSheet = false
    @State private var showAddCategorySheet = false

    @State private var deletedItems: [String] = [] // 削除されたアイテムの履歴
    @State private var showDeletedItemsSheet = false

    @State private var categoryToDelete: String? = nil // 削除確認ダイアログで選択されたカテゴリ
    @State private var showDeleteCategoryConfirmation = false // カテゴリ削除確認ダイアログの表示/非表示

    @State private var selectedCategoryForColorChange: String? = nil

    @Environment(\.editMode) private var editMode // SwiftUIの編集モード環境変数

    // 編集中のアイテムを追跡するためのState変数
    // (category: 編集中のアイテムのカテゴリ, originalItem: 編集前のアイテム名)
    @State private var editingItem: (category: String, originalItem: String)? = nil
    @State private var editedItemName: String = "" // 編集中のアイテムの新しい名前

    // MARK: - Constants
    private let shoppingListKey = "shoppingListKey" // UserDefaultsに買い物リストを保存するためのキー
    private let deletedItemsKey = "deletedItemsKey" // UserDefaultsに削除履歴を保存するためのキー

    // カテゴリごとの色を定義 (視覚的な区別のため) - カスタマイズ可能
    @State private var categoryColors: [String: Color] = [
        "食品": .green,
        "日用品": .blue,
        "その他": .gray
    ]

    // MARK: - Body
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                // --- 紙風の質感背景 ---
                ZStack {
                    Color(red: 0.98, green: 0.97, blue: 0.94)
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.white.opacity(0.5),
                            Color.white.opacity(0.0)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .blendMode(.overlay)
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.black.opacity(0.02),
                            Color.clear
                        ]),
                        startPoint: .bottomTrailing,
                        endPoint: .topLeading
                    )
                    .blendMode(.multiply)
                }
                .ignoresSafeArea()
                
//                ここの３行をONにするとLottieの背景（黒猫）を表示
//                LottieView(filename: "Animation - 1751589879123")
//                    .ignoresSafeArea()

                VStack(spacing: 10) {
                    List {
                        ForEach(categories, id: \.self) { category in
                            if let items = shoppingList[category], !items.isEmpty {
                                Section(header: headerView(for: category)) {
                                    ForEach(Array(items.enumerated()), id: \.element) { index, item in
                                        itemRow(for: item, in: category)
                                            .listRowBackground(Color.clear)
                                    }
                                    .onMove { indices, newOffset in
                                        moveItems(in: category, indices: indices, newOffset: newOffset)
                                    }
                                }
                            }
                        }
                    }
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .listStyle(.plain)
                    // REMOVE any .background(Color.white) or .background(.ultraThinMaterial) from List or VStack here
                }
                .padding(.bottom, 60)

                // --- リスト追加・カテゴリ追加ボタン (isExpanded時のみ表示) ---
                if isExpanded {
                    ZStack {
                        // 左斜め上のリスト追加
                        Button {
                            withAnimation {
                                showAddItemSheet = true
                                isExpanded = false
                            }
                        } label: {
                            VStack {
                                Image(systemName: "list.bullet")
                                    .font(.system(size: 20, weight: .regular))
                                Text("リスト")
                                    .font(.caption2)
                            }
                            .foregroundColor(.white)
                            .frame(width: 56, height: 56)
                            .background(
                                Color(hex: "#5F7F67")
                                    .overlay(.ultraThinMaterial)
                            )
                            .clipShape(Circle())
                            .shadow(radius: 4)
                        }
                        .offset(x: -50, y: -100)

                        // 左のカテゴリ追加
                        Button {
                            withAnimation {
                                showAddCategorySheet = true
                                isExpanded = false
                            }
                        } label: {
                            VStack {
                                Image(systemName: "folder.badge.plus")
                                    .font(.system(size: 20, weight: .regular))
                                Text("カテゴリ")
                                    .font(.caption2)
                            }
                            .foregroundColor(.white)
                            .frame(width: 56, height: 56)
                            .background(
                                Color(hex: "#5F7F67")
                                    .overlay(.ultraThinMaterial)
                            )
                            .clipShape(Circle())
                            .shadow(radius: 4)
                        }
                        .offset(x: -95, y: -30)
                    }
                }
                // --- end リスト追加・カテゴリ追加ボタン ---

                plusButton
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("To Do 🐈‍⬛")
                        .font(.custom("Times New Roman", size: 24))
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        Button {
                            showDeletedItemsSheet = true
                        } label: {
                            Image(systemName: "clock.arrow.circlepath")
                                .foregroundColor(Color(hex: "#5F7F67"))
                        }

                        Button {
                            withAnimation {
                                editMode?.wrappedValue = editMode?.wrappedValue == .active ? .inactive : .active
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: editMode?.wrappedValue == .active ? "checkmark" : "square.and.pencil")
                                    .foregroundColor(.white)
                                Text(editMode?.wrappedValue == .active ? "完了" : "編集")
                                    .foregroundColor(.white)
                            }
                            .font(.caption)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color(hex: "#5F7F67"))
                            .cornerRadius(12)
                        }
                    }
                }
            }
            .environment(\.editMode, editMode)
            .onAppear {
                let appearance = UINavigationBarAppearance()
                appearance.configureWithTransparentBackground()
                appearance.titleTextAttributes = [
                    .font: UIFont(name: "Times New Roman", size: 24)!
                ]
                UINavigationBar.appearance().standardAppearance = appearance
                UINavigationBar.appearance().scrollEdgeAppearance = appearance

                loadItems()
                loadDeletedItems()
                loadCategories()
                loadCategoryColors()
            }
        }
        // --- シート群はbodyの末尾に配置 ---
        .overlay(
            Group {
                if showAddItemSheet {
                    ZStack(alignment: .bottom) {
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()
                            .onTapGesture {
                                withAnimation { showAddItemSheet = false }
                            }
                        VStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 16) {
                                // 入力欄
                                TextField("例：キャットフード", text: $newItem)
                                    .padding()
                                    .background(.ultraThinMaterial)
                                    .cornerRadius(12)

                                // カテゴリ選択: 横スクロールのタブ式タグボタン
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(categories, id: \.self) { category in
                                            Button(action: {
                                                selectedCategory = category
                                            }) {
                                                Text(category)
                                                    .font(.caption)
                                                    .padding(.horizontal, 12)
                                                    .padding(.vertical, 6)
                                                    .background(selectedCategory == category ? Color(hex: "#5F7F67") : Color.gray.opacity(0.2))
                                                    .foregroundColor(.white)
                                                    .cornerRadius(16)
                                            }
                                        }
                                    }
                                    .padding(.horizontal, 4)
                                }
                                .padding(.vertical, 2)

//                ここは追々実装する
//                                // 説明欄
//                                Text("説明")
//                                    .font(.caption)
//                                    .foregroundColor(.gray)
//                                TextField("メモを追加", text: .constant(""))
//                                    .padding()
//                                    .background(.ultraThinMaterial)
//                                    .cornerRadius(12)
//
//                                // オプション（ダミー）
//                                HStack {
//                                    Button("今日") {}
//                                        .padding(.horizontal)
//                                        .padding(.vertical, 8)
//                                        .background(.thinMaterial)
//                                        .cornerRadius(20)
//
//                                    Button("優先度") {}
//                                        .padding(.horizontal)
//                                        .padding(.vertical, 8)
//                                        .background(.thinMaterial)
//                                        .cornerRadius(20)
//
//                                    Button("リマインダー") {}
//                                        .padding(.horizontal)
//                                        .padding(.vertical, 8)
//                                        .background(.thinMaterial)
//                                        .cornerRadius(20)
//                                }

                                // 保存ボタン（右寄せ）
                                HStack {
                                    Spacer()
                                    Button {
                                        addItem()
                                        showAddItemSheet = false
                                    } label: {
                                        HStack {
                                            Image(systemName: "plus")
                                            Text("追加").fontWeight(.bold)
                                        }
                                    }
                                    .buttonStyle(ModernButtonStyle())
                                    .disabled(newItem.isEmpty)
                                }
                            }
                            .padding()
                            .background(.ultraThinMaterial)
                            .cornerRadius(20)
                            .padding(.horizontal, 24)

                        }
                        .padding(.bottom, 32)
                        .transition(.move(edge: .bottom))
                    }
                }
            }
        )
        .overlay(
            Group {
                if showAddCategorySheet {
                    ZStack(alignment: .bottom) {
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()
                            .onTapGesture {
                                withAnimation { showAddCategorySheet = false }
                            }
                        VStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 16) {
                                Text("新しいカテゴリ")
                                    .font(.headline)
                                    .padding(.bottom, 4)
                                TextField("新しいカテゴリー名", text: $newCategory)
                                    .padding(8)
                                    .background(.ultraThinMaterial)
                                    .cornerRadius(8)
                                    .font(.subheadline)
                                Text("色を選択").font(.subheadline).fontWeight(.medium)
                                HStack {
                                    let presetColors: [Color] = [
                                        .red, .orange, .yellow, .green, .blue, .purple, .gray
                                    ]
                                    ForEach(presetColors, id: \.self) { color in
                                        Circle()
                                            .fill(color)
                                            .frame(width: 32, height: 32)
                                            .shadow(radius: 2)
                                            .overlay(
                                                Circle().stroke(Color.white, lineWidth: categoryColors[newCategory] == color ? 3 : 1)
                                            )
                                            .onTapGesture {
                                                categoryColors[newCategory] = color
                                            }
                                    }
                                }
                                HStack {
                                    Spacer()
                                    Button {
                                        addCategory()
                                        newCategory = ""
                                        showAddCategorySheet = false
                                    } label: {
                                        HStack {
                                            Image(systemName: "plus")
                                            Text("追加").fontWeight(.bold)
                                        }
                                    }
                                    .buttonStyle(ModernButtonStyle())
                                    .disabled(newCategory.trimmingCharacters(in: .whitespaces).isEmpty)
                                }
                            }
                            .padding()
                            .background(.ultraThinMaterial)
                            .cornerRadius(20)
                            .padding(.horizontal, 24)
                        }
                        .padding(.bottom, 32)
                        .transition(.move(edge: .bottom))
                    }
                }
            }
        )
    }
    // 履歴シートはNavigationStackチェーン内に配置

private func headerView(for category: String) -> some View {
    VStack(alignment: .leading, spacing: 4) {
        HStack {
            Text(category)
                .font(.subheadline)
                .fontWeight(.semibold)
                .onLongPressGesture {
                    selectedCategoryForColorChange = category
                }
            Spacer()
            if editMode?.wrappedValue == .active && canDeleteCategory(category) {
                Button {
                    categoryToDelete = category
                    showDeleteCategoryConfirmation = true
                } label: {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
                .confirmationDialog("カテゴリを削除しますか？", isPresented: $showDeleteCategoryConfirmation) {
                    if let category = categoryToDelete {
                        Button("削除", role: .destructive) { deleteCategory(category) }
                        Button("キャンセル", role: .cancel) { categoryToDelete = nil }
                    }
                }
            }
        }
        .sheet(isPresented: $showDeletedItemsSheet) {
            NavigationView {
                VStack(alignment: .leading) {
                    if deletedItems.isEmpty {
                        Text("削除履歴はありません")
                            .foregroundColor(.gray)
                            .padding()
                    } else {
                        List {
                            ForEach(deletedItems, id: \.self) { item in
                                HStack {
                                    Text(item)
                                    Spacer()
                                    Button("復元") {
                                        restoreDeletedItem(item)
                                    }
                                    .buttonStyle(ModernButtonStyle())
                                }
                            }
                        }
                        .listStyle(.plain)
                    }
                }
                .navigationTitle("削除履歴")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("閉じる") {
                            showDeletedItemsSheet = false
                        }
                    }
                }
            }
        }

        if selectedCategoryForColorChange == category {
            let presetColors: [Color] = [
                .red, .orange, .yellow, .green, .blue, .purple, .gray
            ]
            HStack {
                ForEach(presetColors, id: \.self) { color in
                    Circle()
                        .fill(color)
                        .frame(width: 32, height: 32)
                        .shadow(radius: 2)
                        .overlay(Circle().stroke(Color.white, lineWidth: 1))
                        .onTapGesture {
                            categoryColors[category] = color
                            saveCategoryColors()
                            selectedCategoryForColorChange = nil
                        }
                }
            }
        }
    }
    // Optionally: You could add a subtle background, but do NOT use solid white.
    //.background(.ultraThinMaterial) // Use if you want a light blur, otherwise leave transparent.
}

private func itemRow(for item: String, in category: String) -> some View {
    HStack {
        // カテゴリカラー付きの小さな丸
        Circle()
            .fill(categoryColors[category] ?? .gray)
            .frame(width: 8, height: 8)

        if editMode?.wrappedValue == .active {
            Image(systemName: "line.3.horizontal").foregroundColor(.gray)
        }
        Button {
            deleteItem(item, from: category)
        } label: {
            Image(systemName: "circle")
                .foregroundColor(categoryColors[category] ?? .gray)
        }
        .buttonStyle(.plain)

        if editMode?.wrappedValue == .active && editingItem?.originalItem == item {
            TextField("アイテム名", text: $editedItemName, onCommit: {
                updateItem(originalItem: item, in: category, with: editedItemName)
                editingItem = nil
            })
        } else {
            Text(item)
                .font(.caption)
                .onTapGesture {
                    if editMode?.wrappedValue == .active {
                        editingItem = (category, item)
                        editedItemName = item
                    }
                }
        }
    }
    .padding(4)
    .background(
        ZStack {
            (categoryColors[category] ?? .gray).opacity(0.08)
                .cornerRadius(6)
            // Only use .ultraThinMaterial as a background, not solid white
            Color.clear.background(.ultraThinMaterial)
        }
    )
    .cornerRadius(6)
    .padding(.horizontal, 2)
}


private var plusButton: some View {
    Button {
        showAddTaskSheet.toggle()
        isExpanded.toggle()
    } label: {
        Image(systemName: "plus")
            .rotationEffect(.degrees(isExpanded ? 45 : 0))
            .foregroundColor(.white)
            .font(.system(size: 24, weight: .bold))
            .frame(width: 56, height: 56)
            .background(Color(hex: "#5F7F67"))
            .clipShape(Circle())
            .shadow(radius: 4)
            .padding()
    }
    .animation(.spring(), value: isExpanded)
}


// MARK: - 機能メソッドの追加 (Extension)
}

extension ContentView {
    /// 新しいアイテムをリストに追加します。
    private func addItem() {
        let trimmedItem = newItem.trimmingCharacters(in: .whitespaces)
        guard !trimmedItem.isEmpty else { return }

        withAnimation {
            var items = shoppingList[selectedCategory] ?? []
            items.append(trimmedItem)
            shoppingList[selectedCategory] = items
        }

        newItem = ""
        saveItems() // 変更を保存
    }

    /// 指定されたカテゴリを削除します。
    private func deleteCategory(_ category: String) {
        withAnimation {
            categories.removeAll { $0 == category }
            shoppingList.removeValue(forKey: category)
        }
        saveItems() // 変更を保存
        // WidgetCenter.shared.reloadAllTimelines() // ← 削除: WidgetCenterの呼び出しはsaveItems()で行う
    }

    /// 指定されたカテゴリからアイテムを削除し、削除履歴に追加します。
    private func deleteItem(_ item: String, from category: String) {
        guard var items = shoppingList[category] else { return }
        guard let index = items.firstIndex(of: item) else { return }

        let removed = items.remove(at: index)
        addDeletedItems([removed]) // 削除履歴に追加
        withAnimation {
            shoppingList[category] = items
        }
        saveItems() // 変更を保存
    }

    /// 削除履歴からアイテムを復元し、現在の選択カテゴリに追加します。
    private func restoreDeletedItem(_ item: String) {
        withAnimation {
            var items = shoppingList[selectedCategory] ?? []
            if !items.contains(item) { // 重複を避ける
                items.append(item)
                shoppingList[selectedCategory] = items
                saveItems() // 変更を保存
            }
            deletedItems.removeAll { $0 == item } // 履歴から削除
            saveDeletedItems() // 変更を保存
        }
    }

    /// 新しいカテゴリを追加します。
    private func addCategory() {
        let trimmedCategory = newCategory.trimmingCharacters(in: .whitespaces)
        guard !trimmedCategory.isEmpty, !categories.contains(trimmedCategory) else { return }
        categories.append(trimmedCategory)
        if let pickedColor = categoryColors[newCategory] {
            categoryColors[trimmedCategory] = pickedColor
        } else {
            categoryColors[trimmedCategory] = .gray
        }
        saveCategories()
        saveCategoryColors()
        newCategory = ""
    }

    /// カテゴリのデータをUserDefaultsに保存します。
    private func saveCategories() {
        UserDefaults.standard.set(categories, forKey: "categoriesKey")
    }

    /// UserDefaultsからカテゴリデータを読み込みます。
    private func loadCategories() {
        if let saved = UserDefaults.standard.stringArray(forKey: "categoriesKey") {
            categories = saved
        }
    }

    /// App Group から買い物リストのデータを読み込みます。
    private func loadItems() {
        let sharedDefaults = UserDefaults(suiteName: "group.com.yourname.ToDo") // App Group名は適宜変更
        if let data = sharedDefaults?.data(forKey: shoppingListKey),
           let items = try? JSONDecoder().decode([String: [String]].self, from: data) {
            shoppingList = items
        }
    }

    /// UserDefaultsから削除履歴のデータを読み込みます。
    private func loadDeletedItems() {
        if let data = UserDefaults.standard.data(forKey: deletedItemsKey),
           let items = try? JSONDecoder().decode([String].self, from: data) {
            deletedItems = items
        }
    }

    /// 買い物リストのデータをApp Groupに保存します。
    private func saveItems() {
        if let data = try? JSONEncoder().encode(shoppingList) {
            let sharedDefaults = UserDefaults(suiteName: "group.com.yourname.ToDo") // App Group名は適宜変更
            sharedDefaults?.set(data, forKey: shoppingListKey)
            WidgetCenter.shared.reloadAllTimelines() // ウィジェット更新を即トリガー
        }
    }

    /// 削除履歴のデータをUserDefaultsに保存します。
    private func saveDeletedItems() {
        if let data = try? JSONEncoder().encode(deletedItems) {
            UserDefaults.standard.set(data, forKey: deletedItemsKey)
        }
    }

    /// 削除されたアイテムを履歴に追加します（最新5件を保持）。
    private func addDeletedItems(_ items: [String]) {
        for item in items {
            deletedItems.removeAll { $0 == item } // 既に存在する場合は削除して再追加
            deletedItems.insert(item, at: 0) // 先頭に追加
        }
        if deletedItems.count > 5 {
            deletedItems = Array(deletedItems.prefix(5)) // 最新5件に制限
        }
        saveDeletedItems() // 変更を保存
    }

    /// 指定されたカテゴリ内でアイテムの並び順を変更します。
    private func moveItems(in category: String, indices: IndexSet, newOffset: Int) {
        guard var items = shoppingList[category] else { return }
        items.move(fromOffsets: indices, toOffset: newOffset)
        shoppingList[category] = items
        saveItems() // 変更を保存
    }

    /// 指定されたカテゴリが削除可能かどうかを判定します（初期カテゴリは不可）。
    private func canDeleteCategory(_ category: String) -> Bool {
        !["食品", "日用品", "その他"].contains(category)
    }

    /// アイテム名を更新します。
    /// - Parameters:
    ///   - originalItem: 変更前のアイテム名
    ///   - category: アイテムが存在するカテゴリ
    ///   - newItemName: 新しいアイテム名
    private func updateItem(originalItem: String, in category: String, with newItemName: String) {
        let trimmedNewItemName = newItemName.trimmingCharacters(in: .whitespaces)
        guard !trimmedNewItemName.isEmpty else { return } // 空の場合は更新しない

        if var items = shoppingList[category], let index = items.firstIndex(of: originalItem) {
            items[index] = trimmedNewItemName
            shoppingList[category] = items
            saveItems() // 変更を保存
        }
    }

    // MARK: - カテゴリカラーの保存・読込
    private func saveCategoryColors() {
        let rgbData = categoryColors.mapValues { color in
            let uiColor = UIColor(color)
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
            return [Double(r), Double(g), Double(b), Double(a)]
        }
        if let data = try? JSONEncoder().encode(rgbData) {
            UserDefaults.standard.set(data, forKey: "categoryColorsKey")
        }
    }

    private func loadCategoryColors() {
        if let data = UserDefaults.standard.data(forKey: "categoryColorsKey"),
           let raw = try? JSONDecoder().decode([String: [Double]].self, from: data) {
            categoryColors = raw.compactMapValues { arr in
                if arr.count == 4 {
                    return Color(red: arr[0], green: arr[1], blue: arr[2], opacity: arr[3])
                }
                return nil
            }
        }
    }
}

/*
    注意：このアプリは UserDefaults を用いてリスト内容・履歴を保存しているため、
    アプリを閉じたり端末を再起動してもデータは保持されます。
*/

// MARK: - Color Extension for Hex Initialization
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        switch hex.count {
        case 6: // RGB (24-bit)
            (r, g, b) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (r, g, b) = (1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: 1
        )
    }
}

