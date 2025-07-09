// MARK: - ショッピングアイテム
struct ShoppingItem: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String
    var dueDate: Date? // 期限なしの場合は nil
    
    // 新規アイテム作成時の初期化メソッド
    init(name: String, dueDate: Date? = nil) {
        self.id = UUID()
        self.name = name
        self.dueDate = dueDate
    }
}
// MARK: - 削除履歴アイテム
struct DeletedItem: Codable, Hashable {
    let name: String
    let category: String
    let dueDate: Date? // アイテムの期限（なければnil）
}


// MARK: - カスタムボタンスタイル
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
import UserNotifications
import SwiftUI
import WidgetKit

struct ContentView: View {
    // MARK: - State
    @State private var newItem: String = "" // 新規アイテム名
    @State private var selectedCategory: String = "食品" // 選択中カテゴリ
    @State private var shoppingList: [String: [ShoppingItem]] = [:] // 買い物リスト
    @State private var categories: [String] = ["食品", "日用品", "その他"] // カテゴリ一覧
    @State private var newCategory: String = "" // 新規カテゴリ名
    @State private var showAddTaskSheet = false // 未使用
    @State private var isExpanded: Bool = false // プラスボタン展開
    @State private var showAddItemSheet = false // アイテム追加シート表示
    @State private var showAddCategorySheet = false // カテゴリ追加シート表示
    @State private var deletedItems: [DeletedItem] = [] // 削除履歴
    @State private var showDeletedItemsSheet = false // 削除履歴シート表示
    @State private var categoryToDelete: String? = nil // 削除対象カテゴリ
    @State private var showDeleteCategoryConfirmation = false // カテゴリ削除確認
    @State private var selectedCategoryForColorChange: String? = nil // 色変更対象カテゴリ
    @Environment(\.editMode) private var editMode // 編集モード
    @State private var editingItem: (category: String, originalItem: String)? = nil // 編集中アイテム
    @State private var editedItemName: String = "" // 編集後アイテム名
    @State private var newDueDate: Date? = nil // 新規/編集期限
    @State private var addDueDate: Bool = false // 期限設定ON/OFF
    @FocusState private var isNewItemFieldFocused: Bool // フォーカス
    
    // MARK: - 定数
    private let shoppingListKey = "shoppingListKey"
    private let deletedItemsKey = "deletedItemsKey"
    @State private var categoryColors: [String: Color] = [
        "食品": .green,
        "日用品": .blue,
        "その他": .gray
    ]
    
    // MARK: - Body（画面全体のレイアウト）
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                backgroundView
                contentView
                plusButton
            }
            .toolbar {
                principalTitle
                trailingButtons
            }
            .environment(\.editMode, editMode)
            .onAppear {
                // 初期化処理
                setupNavigationBar()
                loadItems()
                loadDeletedItems()
                loadCategories()
                loadCategoryColors()
                UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
                    if let error = error {
                        print("通知の許可エラー: \(error.localizedDescription)")
                    } else {
                        print("通知の許可: \(granted)")
                    }
                }
            }
            .overlay(addItemOverlay)
            .overlay(addCategoryOverlay)
        }
    }
    
    // MARK: - ヘッダー
    private var principalTitle: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            Text("To Do 🐈‍⬛")
                .font(.custom("Times New Roman", size: 24))
        }
    }
    
    // MARK: - ボタン
    private var trailingButtons: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            HStack {
                // 削除履歴ボタン
                Button { showDeletedItemsSheet = true } label: {
                    Image(systemName: "clock.arrow.circlepath")
                        .foregroundColor(Color(hex: "#5F7F67"))
                }
                // 編集モード切り替えボタン
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
    
    // MARK: - ナビゲーションバー外観
    private func setupNavigationBar() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.titleTextAttributes = [
            .font: UIFont(name: "Times New Roman", size: 24)!
        ]
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
    }
    
    // MARK: - アイテム追加オーバーレイ
    private var addItemOverlay: some View {
        Group {
            if showAddItemSheet {
                ZStack(alignment: .bottom) {
                    // 背景の半透明レイヤー（タップで閉じる）
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation { showAddItemSheet = false }
                        }
                    VStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 16) {
                            // 新規アイテム名の入力欄
                            TextField("例：キャットフード", text: $newItem)
                                .focused($isNewItemFieldFocused)
                                .padding()
                                .background(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.5), lineWidth: 1))
                            // 期限追加トグル
                            Toggle("期限を設定する", isOn: $addDueDate)
                                .padding(.top, 8)
                            
                            // 期限を設定する場合のDatePicker
                            if addDueDate {
                                VStack {
                                    DatePicker(
                                        "期限",
                                        selection: Binding(
                                            get: { newDueDate ?? Date() },
                                            set: { newDueDate = $0 }
                                        ),
                                        displayedComponents: [.date]
                                    )
                                    .datePickerStyle(.compact)
                                    .environment(\.locale, Locale(identifier: "ja_JP"))
                                }
                                .padding()
                                .background(.ultraThinMaterial)
                                .cornerRadius(12)
                            }
                            
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
    }
    
    // MARK: - カテゴリ追加オーバーレイ
    private var addCategoryOverlay: some View {
        Group {
            if showAddCategorySheet {
                ZStack(alignment: .bottom) {
                    // 背景の半透明レイヤー（タップで閉じる）
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
                            // 新カテゴリ名の入力欄
                            TextField("新しいカテゴリー名", text: $newCategory)
                                .focused($isNewItemFieldFocused)
                                .padding()
                                .background(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.5), lineWidth: 1))
                                .font(.subheadline)
                            // 色選択
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
                            // 追加ボタン（右寄せ）
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
    }
    
    // MARK: - 背景
    private var backgroundView: some View {
        ZStack {
            Color(red: 0.98, green: 0.97, blue: 0.94) // 薄いクリーム色
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
        // ここの３行をONにするとLottieの背景（黒猫）を表示
        // LottieView(filename: "Animation - 1751589879123")
        //     .ignoresSafeArea()
    }
    
    // MARK: - セクション
    private var contentView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 4) {
                // 各カテゴリごとにセクションを表示
                ForEach(Array(categories.enumerated()), id: \.element) { idx, category in
                    categorySection(for: category, idx: idx)
                }
            }
            .padding(.bottom, 60)
            .padding(.horizontal, 16)
        }
        .overlay(
            Group {
                if isExpanded {
                    ZStack(alignment: .bottomTrailing) {
                        // アイテム追加ショートカット
                        Button {
                            withAnimation {
                                showAddItemSheet = true
                                isExpanded = false
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    isNewItemFieldFocused = true
                                }
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
                        .offset(x: -20, y: -80)
                        
                        // カテゴリ追加ショートカット
                        Button {
                            withAnimation {
                                showAddCategorySheet = true
                                isExpanded = false
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    isNewItemFieldFocused = true
                                }
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
                        .offset(x: -85, y: -20)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .allowsHitTesting(true)
                    .padding(16)
                }
            }
        )
    }
    
    // MARK: - セクション表示
    private func categorySection(for category: String, idx: Int) -> some View {
        Group {
            if let items = shoppingList[category], !items.isEmpty {
                dividerIfNeeded(idx: idx)      // 1つ目以外は区切り線
                headerView(for: category)      // カテゴリ名と操作ボタン
                ForEach(items, id: \.id) { item in
                    itemRow(for: item, in: category) // アイテム1行
                }
            }
        }
    }
    
    // MARK: - ヘッダー表示
    private func headerView(for category: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                // カテゴリ名（長押しで色変更）
                Text(category)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .onLongPressGesture {
                        selectedCategoryForColorChange = category
                    }
                Spacer()
                // 編集モード中かつ初期カテゴリ以外のみ削除ボタン表示
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
            // 削除履歴シート（カテゴリヘッダーから開く）
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
                                        Text(item.name)
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
            
            // カテゴリ色変更用のカラーパレット
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
        // 背景やパディングはお好みで調整可能
    }
    // MARK: - アイテム行
    private func itemRow(for item: ShoppingItem, in category: String) -> some View {
        HStack {
            Circle()
                .fill(categoryColors[category] ?? .gray)
                .frame(width: 8, height: 8)

            if editMode?.wrappedValue == .active {
                Image(systemName: "line.3.horizontal").foregroundColor(.gray)
            }

            Button {
                let impact = UIImpactFeedbackGenerator(style: .light)
                impact.impactOccurred()
                deleteItem(item, from: category)
            } label: {
                Image(systemName: "circle")
                    .foregroundColor(categoryColors[category] ?? .gray)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                if editMode?.wrappedValue == .active && editingItem?.originalItem == item.name {
                    TextField("アイテム名", text: $editedItemName, onCommit: {
                        updateItem(originalItem: item, in: category, with: editedItemName)
                        editingItem = nil
                    })
                    DatePicker(
                        "期限",
                        selection: Binding(
                            get: { item.dueDate ?? Date() },
                            set: { newDate in
                                updateItemDueDate(originalItem: item, in: category, with: newDate)
                            }
                        ),
                        displayedComponents: [.date]
                    )
                    .datePickerStyle(.compact)
                    .environment(\.locale, Locale(identifier: "ja_JP"))
                } else {
                    Text(item.name)
                        .font(.caption)
                        .onTapGesture {
                            if editMode?.wrappedValue == .active {
                                editingItem = (category, item.name)
                                editedItemName = item.name
                            }
                        }

                    if let due = item.dueDate {
                        let calendar = Calendar.current
                        let dueDay = calendar.startOfDay(for: due)
                        let today = calendar.startOfDay(for: Date())

                        if dueDay >= today || dueDay == today {
                            Text("期限: \(dateFormatter.string(from: due))")
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                    }
                }
            }
        }
        .padding(4)
        .background(
            ZStack {
                (categoryColors[category] ?? .gray).opacity(0.08)
                    .cornerRadius(6)
                Color.clear.background(.ultraThinMaterial)
            }
        )
        .cornerRadius(6)
        .padding(.horizontal, 2)
    }
    // MARK: - プラスボタン
    private var plusButton: some View {
        Button {
            withAnimation {
                isExpanded.toggle()
            }
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
}

// MARK: - セクション区切り線
private func dividerIfNeeded(idx: Int) -> some View {
    Group {
        if idx != 0 {
            Divider()
                .frame(height: 1)
                .background(Color.gray.opacity(0.3))
        } else {
            EmptyView()
        }
    }
}

// MARK: - 機能メソッド
extension ContentView {
    /// アイテムの期限を更新
    private func updateItemDueDate(originalItem: ShoppingItem, in category: String, with newDueDate: Date) {
        if var items = shoppingList[category],
           let index = items.firstIndex(of: originalItem) {
            items[index].dueDate = newDueDate
            shoppingList[category] = items
            saveItems()
        }
    }
    /// アイテムを追加
    private func addItem() {
        let trimmedItem = newItem.trimmingCharacters(in: .whitespaces)
        guard !trimmedItem.isEmpty else { return }
        
        withAnimation {
            var items = shoppingList[selectedCategory] ?? []
            let item = ShoppingItem(name: trimmedItem, dueDate: addDueDate ? newDueDate : nil)
            items.append(item)
            shoppingList[selectedCategory] = items
            if let dueDate = item.dueDate {
                scheduleNotification(for: item)
            }
        }
        
        newItem = ""
        newDueDate = nil
        addDueDate = false
        saveItems()
    }
    
    /// カテゴリを削除
    private func deleteCategory(_ category: String) {
        withAnimation {
            categories.removeAll { $0 == category }
            shoppingList.removeValue(forKey: category)
        }
        saveItems() // 変更を保存
        // WidgetCenter.shared.reloadAllTimelines() // ← 削除: WidgetCenterの呼び出しはsaveItems()で行う
    }
    
    /// アイテムを削除し履歴に追加
    private func deleteItem(_ item: ShoppingItem, from category: String) {
        guard var items = shoppingList[category] else { return }
        guard let index = items.firstIndex(of: item) else { return }
        
        let removed = items.remove(at: index)
        addDeletedItems([(removed.name, category, removed.dueDate)])
        withAnimation {
            shoppingList[category] = items
        }
        saveItems()
    }
    /// アイテム名を更新
    private func updateItem(originalItem: ShoppingItem, in category: String, with newItemName: String) {
        let trimmedNewItemName = newItemName.trimmingCharacters(in: .whitespaces)
        guard !trimmedNewItemName.isEmpty else { return }
        
        if var items = shoppingList[category],
           let index = items.firstIndex(of: originalItem) {
            items[index].name = trimmedNewItemName
            shoppingList[category] = items
            saveItems()
        }
    }
    
    /// 削除履歴からアイテムを復元
    private func restoreDeletedItem(_ item: DeletedItem) {
        withAnimation {
            var items = shoppingList[item.category] ?? []
            // 同名アイテムが既に存在する場合は追加しない
            if items.contains(where: { $0.name == item.name }) { return }
            items.append(ShoppingItem(name: item.name, dueDate: item.dueDate))
            shoppingList[item.category] = items
            saveItems()
            deletedItems.removeAll { $0 == item }
            saveDeletedItems()
        }
    }
    
    /// カテゴリを追加
    private func addCategory() {
        let trimmedCategory = newCategory.trimmingCharacters(in: .whitespaces)
        guard !trimmedCategory.isEmpty, !categories.contains(trimmedCategory) else { return }
        categories.append(trimmedCategory)
        // 選択した色をカテゴリに紐づける。未選択ならグレー
        if let pickedColor = categoryColors[newCategory] {
            categoryColors[trimmedCategory] = pickedColor
        } else {
            categoryColors[trimmedCategory] = .gray
        }
        saveCategories()
        saveCategoryColors()
        newCategory = ""
    }
    
    /// カテゴリ一覧を保存
    private func saveCategories() {
        UserDefaults.standard.set(categories, forKey: "categoriesKey")
    }
    
    /// カテゴリ一覧を読込
    private func loadCategories() {
        if let saved = UserDefaults.standard.stringArray(forKey: "categoriesKey") {
            categories = saved
        }
    }
    
    /// 買い物リストを読込
    private func loadItems() {
        let sharedDefaults = UserDefaults(suiteName: "group.com.yourname.ToDo") // App Group名
        if let data = sharedDefaults?.data(forKey: shoppingListKey),
           let items = try? JSONDecoder().decode([String: [ShoppingItem]].self, from: data) {
            shoppingList = items
        }
    }
    
    /// 削除履歴を読込
    private func loadDeletedItems() {
        if let data = UserDefaults.standard.data(forKey: deletedItemsKey),
           let items = try? JSONDecoder().decode([DeletedItem].self, from: data) {
            deletedItems = items
        }
    }
    
    /// 買い物リストを保存
    private func saveItems() {
        if let data = try? JSONEncoder().encode(shoppingList) {
            let sharedDefaults = UserDefaults(suiteName: "group.com.yourname.ToDo") // App Group名
            sharedDefaults?.set(data, forKey: shoppingListKey)
            WidgetCenter.shared.reloadAllTimelines() // ウィジェット更新を即トリガー
        }
    }
    
    /// 削除履歴を保存
    private func saveDeletedItems() {
        if let data = try? JSONEncoder().encode(deletedItems) {
            UserDefaults.standard.set(data, forKey: deletedItemsKey)
        }
    }
    
    /// 削除アイテムを履歴に追加（最大5件）
    private func addDeletedItems(_ items: [(name: String, category: String, dueDate: Date?)]) {
        for item in items {
            deletedItems.removeAll { $0.name == item.name && $0.category == item.category }
            deletedItems.insert(DeletedItem(name: item.name, category: item.category, dueDate: item.dueDate), at: 0)
        }
        if deletedItems.count > 5 {
            deletedItems = Array(deletedItems.prefix(5))
        }
        saveDeletedItems()
    }
    
    /// アイテムの並び順を変更
    private func moveItems(in category: String, indices: IndexSet, newOffset: Int) {
        guard var items = shoppingList[category] else { return }
        items.move(fromOffsets: indices, toOffset: newOffset)
        shoppingList[category] = items
        saveItems() // 変更を保存
    }
    
    /// カテゴリが削除可能か判定（初期カテゴリ不可）
    private func canDeleteCategory(_ category: String) -> Bool {
        !["食品", "日用品", "その他"].contains(category)
    }
    
    
    // MARK: - カテゴリカラー保存・読込
    /// カテゴリカラーを保存
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
    
    /// カテゴリカラーを読込
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

// MARK: - Color拡張（16進数カラー）

//ToDoWidget.swiftと重複してエラーになるためコメントアウト
//extension Color {
//    /// 16進数文字列からColorを初期化
//    init(hex: String) {
//        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
//        var int: UInt64 = 0
//        Scanner(string: hex).scanHexInt64(&int)
//        let r, g, b: UInt64
//        switch hex.count {
//        case 6: // RGB (24-bit)
//            (r, g, b) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
//        default:
//            (r, g, b) = (1, 1, 0)
//        }
//        self.init(
//            .sRGB,
//            red: Double(r) / 255,
//            green: Double(g) / 255,
//            blue: Double(b) / 255,
//            opacity: 1
//        )
//    }
//}
// MARK: - 日付フォーマッター
private var dateFormatter: DateFormatter {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "ja_JP")
    formatter.dateFormat = "yyyy/MM/dd"
    return formatter
}

    private func scheduleNotification(for item: ShoppingItem) {
        let content = UNMutableNotificationContent()
        content.title = "期限が近いタスクがあります"
        content.body = "\(item.name) の期限が近づいています。"
        content.sound = .default

        if let dueDate = item.dueDate {
            let triggerDate = Calendar.current.dateComponents([.year, .month, .day], from: dueDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)

            let request = UNNotificationRequest(identifier: item.id.uuidString, content: content, trigger: trigger)

            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("通知登録失敗: \(error.localizedDescription)")
                } else {
                    print("通知登録成功: \(item.name)")
                }
            }
        }
    }
