// MARK: - プリンっとするカスタムボタンスタイル
struct PuddingButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 1.2 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.5), value: configuration.isPressed)
    }
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
            .transaction { $0.animation = nil }
    }
}
import UserNotifications
import SwiftUI
import WidgetKit

struct ContentView: View {
    // MARK: - State
    @State private var newItem: String = "" // 新規アイテム名
    enum AddMode {
        case item
        case category
    }
    @State private var showUnifiedAddSheet: Bool = false
    @State private var showTitle = false
    @State private var titleOffset: CGFloat = 20 // 下からスライド
    @State private var selectedCategory: String = "食品" // 選択中カテゴリ
    @State private var shoppingList: [String: [ShoppingItem]] = [:] // 買い物リスト
    @State private var categories: [String] = ["食品", "日用品", "その他"] // カテゴリ一覧
    @State private var newCategory: String = "" // 新規カテゴリ名
    @State private var showAddTaskSheet = false // 未使用
    @State private var showCategoryEditSheet = false // カテゴリ編集シート表示
    @State private var isExpanded: Bool = false // プラスボタン展開
    @State private var showAddItemSheet = false // アイテム追加シート表示
    @State private var showAddCategorySheet = false // カテゴリ追加シート表示
    @State private var isAddingNewCategory: Bool = false // 新規カテゴリ追加UI表示
    @State private var deletedItems: [DeletedItem] = [] // 削除履歴
    @State private var showDeletedItemsSheet = false // 削除履歴シート表示
    @State private var categoryToDelete: String? = nil // 削除対象カテゴリ
    @State private var showDeleteCategoryConfirmation = false // カテゴリ削除確認
    @State private var selectedCategoryForColorChange: String? = nil // 色変更対象カテゴリ
    @State private var showShortcuts = false
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

                // タイトルをナビゲーションバーから外し、赤丸の位置に配置
                VStack {
                    HStack {
                        Text("NyanDo 🐈‍⬛")
                            .font(.system(size: 28, weight: .bold, design: .serif))
                            .foregroundColor(.black)
                            .opacity(1)
                            .offset(y: 0)
                            .padding(.leading, 16)
                        Spacer()
                    }
                    .padding(.top, 5) // ステータスバーからの余白調整

                    Spacer()
                }

                contentView
                plusButton
                // 削除履歴ボタン（左下フローティング）
                VStack {
                    Spacer()
                    HStack {
                        Button {
                            let impact = UIImpactFeedbackGenerator(style: .medium)
                            impact.impactOccurred()
                            showDeletedItemsSheet = true
                        } label: {
                            Image(systemName: "clock.arrow.circlepath")
                                .foregroundColor(.white)
                                .font(.system(size: 20))
                                .frame(width: 48, height: 48)
                                .background(Color.gray)
                                .clipShape(Circle())
                                .shadow(radius: 4)
                        }
                        .buttonStyle(PuddingButtonStyle())
                        .padding(.leading, 16)
                        .padding(.bottom, 16)

                        Spacer()
                    }
                }
            }
            .toolbar {
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
                showTitle = true
                titleOffset = 0
            }
            .overlay(unifiedAddOverlay)
        }
    }
    
    
    // MARK: - ボタン
    private var trailingButtons: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Button {
                withAnimation {
                    showCategoryEditSheet = true
                }
            } label: {
                Image(systemName: "folder")
                    .foregroundColor(.white)
                    .font(.system(size: 20, weight: .medium))
                    .frame(width: 44, height: 44)
                    .background(Color(hex: "#5F7F67"))
                    .clipShape(Circle())
                    .shadow(radius: 3)
            }
            .buttonStyle(PlainButtonStyle())
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
    

    // MARK: - 統合追加オーバーレイ
    private var unifiedAddOverlay: some View {
        Group {
            if showAddItemSheet || showAddCategorySheet {
                ZStack(alignment: .bottom) {
                    // 背景の半透明レイヤー
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation {
                                showAddItemSheet = false
                                showAddCategorySheet = false
                            }
                        }

                    VStack(spacing: 16) {
                        itemAddForm
                    }
                    .padding(.bottom, 32)
                    .transition(.move(edge: .bottom))
                }
            }
        }
        // --- カテゴリ編集シート ---
        .sheet(isPresented: $showCategoryEditSheet) {
            NavigationView {
                List {
                    ForEach(categories, id: \.self) { category in
                        HStack {
                            Text(category)
                            Spacer()
                            if canDeleteCategory(category) {
                                Button(role: .destructive) {
                                    deleteCategory(category)
                                } label: {
                                    Image(systemName: "trash")
                                        .foregroundColor(.red)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .navigationTitle("カテゴリの編集")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("閉じる") {
                            showCategoryEditSheet = false
                        }
                    }
                }
            }
        }
    }

    private var itemAddForm: some View {
        VStack(alignment: .leading, spacing: 16) {
            TextField("例：キャットフード", text: $newItem)
                .focused($isNewItemFieldFocused)
                .padding()
                .background(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.5), lineWidth: 1))

            Toggle("期限を設定する", isOn: $addDueDate)
                .padding(.top, 8)

            if addDueDate {
                DatePicker(
                    "期限",
                    selection: Binding(
                        get: {
                            let calendar = Calendar.current
                            if let date = newDueDate {
                                return date
                            } else {
                                let now = Date()
                                return calendar.date(bySettingHour: 0, minute: 0, second: 0, of: now) ?? now
                            }
                        },
                        set: { newDueDate = $0 }
                    ),
                    displayedComponents: [.date, .hourAndMinute]
                )
                .datePickerStyle(.compact)
                .environment(\.locale, Locale(identifier: "ja_JP"))
                .padding()
                .background(.ultraThinMaterial)
                .cornerRadius(12)
            }

            // --- カテゴリ選択/追加UI ---
            VStack(alignment: .leading, spacing: 8) {
                Text("カテゴリを選択").font(.subheadline).fontWeight(.medium)

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
                        // 新しいカテゴリを追加ボタン
                        Button(action: {
                            isAddingNewCategory = true
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "plus.circle")
                                Text("カテゴリ追加")
                            }
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.gray.opacity(0.2))
                            .foregroundColor(.white)
                            .cornerRadius(16)
                        }
                    }
                    .padding(.horizontal, 4)
                }

                // 新しいカテゴリ入力欄（表示条件付き）
                if isAddingNewCategory {
                    VStack(spacing: 8) {
                        TextField("新しいカテゴリ名", text: $newCategory)
                            .textFieldStyle(.roundedBorder)

                        // 色を選択するUIを追加
                        Text("色を選択").font(.subheadline).fontWeight(.medium)
                        HStack {
                            let presetColors: [Color] = [.red, .orange, .yellow, .green, .blue, .purple, .gray]
                            ForEach(presetColors, id: \.self) { color in
                                Circle()
                                    .fill(color)
                                    .frame(width: 28, height: 28)
                                    .shadow(radius: 2)
                                    .overlay(
                                        Circle().stroke(Color.white, lineWidth: categoryColors[newCategory] == color ? 3 : 1)
                                    )
                                    .onTapGesture {
                                        categoryColors[newCategory] = color
                                    }
                            }
                        }

                        Button("カテゴリを作成") {
                            addCategory()
                            selectedCategory = newCategory
                            newCategory = ""
                            isAddingNewCategory = false
                        }
                        .disabled(newCategory.trimmingCharacters(in: .whitespaces).isEmpty)
                        .buttonStyle(ModernButtonStyle())
                    }
                    .padding(.top, 4)
                }
            }

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

    private var categoryAddForm: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("新しいカテゴリ")
                .font(.headline)
                .padding(.bottom, 4)

            TextField("新しいカテゴリー名", text: $newCategory)
                .focused($isNewItemFieldFocused)
                .padding()
                .background(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.5), lineWidth: 1))
                .font(.subheadline)

            Text("色を選択").font(.subheadline).fontWeight(.medium)
            HStack {
                let presetColors: [Color] = [.red, .orange, .yellow, .green, .blue, .purple, .gray]
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
                Spacer().frame(height: 40) // タイトル分の余白
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
                            }
                        } label: {
                            VStack {
                                Image(systemName: "list.bullet")
                                    .font(.system(size: 20))
                                Text("リスト")
                                    .font(.caption2)
                            }
                            .foregroundColor(.white)
                            .frame(width: 56, height: 56)
                            .background(Color(hex: "#5F7F67"))
                            .clipShape(Circle())
                            .shadow(radius: 4)
                        }
                        .scaleEffect(showShortcuts ? 1 : 0)
                        .opacity(showShortcuts ? 1 : 0)
                        .offset(
                            x: showShortcuts ? -20 : 0,
                            y: showShortcuts ? -80 : 0
                        )
                        .animation(.spring(response: 0.4, dampingFraction: 0.6), value: showShortcuts)

                        // カテゴリ追加ショートカット
                        Button {
                            withAnimation {
                                showAddCategorySheet = true
                                isExpanded = false
                            }
                        } label: {
                            VStack {
                                Image(systemName: "folder.badge.plus")
                                    .font(.system(size: 20))
                                Text("カテゴリ")
                                    .font(.caption2)
                            }
                            .foregroundColor(.white)
                            .frame(width: 56, height: 56)
                            .background(Color(hex: "#5F7F67"))
                            .clipShape(Circle())
                            .shadow(radius: 4)
                        }
                        .scaleEffect(showShortcuts ? 1 : 0)
                        .opacity(showShortcuts ? 1 : 0)
                        .offset(
                            x: showShortcuts ? -85 : 0,
                            y: showShortcuts ? -20 : 0
                        )
                        .animation(.spring(response: 0.5, dampingFraction: 0.6), value: showShortcuts)
                    }
                    .onAppear { showShortcuts = true }
                    .onDisappear {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                            showShortcuts = false
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(16)
                }
            }
        )
    }
    
    // MARK: - セクション表示
    private func categorySection(for category: String, idx: Int) -> some View {
        Group {
            if let items = shoppingList[category], !items.isEmpty {
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white)
                        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)

                    VStack(alignment: .leading, spacing: 0) {
                        headerView(for: category)
                            .padding(.horizontal)
                            .padding(.top, 8)

                        ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                            itemRow(for: item, in: category, isLast: index == items.count - 1)
                                .padding(.horizontal)
                        }
                        .onMove(perform: editMode?.wrappedValue == .active ? { indices, newOffset in
                            moveItems(in: category, indices: indices, newOffset: newOffset)
                        } : nil)
                        .moveDisabled(editMode?.wrappedValue != .active)

                        Spacer(minLength: 8)
                    }
                    .padding(.bottom, 8)
                }
                .padding(.vertical, 6)
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
                    .foregroundColor(.black)
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
                    VStack(alignment: .leading, spacing: 16) {
                        Text("削除履歴：\(deletedItems.count)件")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(Color(hex: "#AA4D53"))
                            .padding(.horizontal)
                            .padding(.top, 16)

                        if deletedItems.isEmpty {
                            Text("削除履歴はありません")
                                .foregroundColor(.gray)
                                .padding()
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .background(Color(hex: "#444949"))
                        } else {
                            List {
                                ForEach(deletedItems, id: \.self) { item in
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(item.name)
                                                .font(.body)
                                                .fontWeight(.medium)
                                                .foregroundColor(.white)
                                            Text("カテゴリ: \(item.category)")
                                                .font(.caption)
                                                .foregroundColor(.white)
                                            if let due = item.dueDate {
                                                Text("期限: \(dateFormatter.string(from: due))")
                                                    .font(.caption2)
                                                    .foregroundColor(.white)
                                            }
                                        }
                                        Spacer()
                                        Text("左にスワイプで復元")
                                            .font(.caption2)
                                            .foregroundColor(.gray)
                                    }
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button {
                                            restoreDeletedItem(item)
                                        } label: {
                                            Label("復元", systemImage: "arrow.uturn.backward")
                                        }
                                        .tint(Color(hex: "#5F7F67"))
                                    }
                                    .listRowBackground(Color(hex: "#555555"))
                                }
                            }
                            .listStyle(.plain)
                        }
                    }
                    .background(Color(hex: "#444949"))
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button {
                                showDeletedItemsSheet = false
                            } label: {
                                Image(systemName: "xmark")
                            }
                            .foregroundColor(Color(hex: "#AA4D53"))
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
    private func itemRow(for item: ShoppingItem, in category: String, isLast: Bool) -> some View {
        VStack {
            HStack(alignment: .center, spacing: 12) {
                Button {
                    let impact = UIImpactFeedbackGenerator(style: .light)
                    impact.impactOccurred()
                    deleteItem(item, from: category)
                } label: {
                    Circle()
                        .stroke(categoryColors[category] ?? .gray, lineWidth: 2)
                        .frame(width: 18, height: 18)
                }
                .buttonStyle(.plain)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.name)
                        .font(.subheadline)
                        .foregroundColor(.black)

                    if let due = item.dueDate {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                                .font(.caption2)
                                .foregroundColor(.gray)
                            Text(dateFormatter.string(from: due))
                                .font(.caption)
                                .foregroundColor(due <= Date() ? .red : .gray)
                        }
                    }
                }

                Spacer()
            }
            .padding(.vertical, 4)

            if !isLast {
                Divider()
                    .padding(.leading, 36)
            }
        }
    }
    // MARK: - プラスボタン
    private var plusButton: some View {
        Button {
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred()
            withAnimation {
                isExpanded.toggle()
            }
        } label: {
            Image(systemName: "plus")
                .rotationEffect(.degrees(isExpanded ? 45 : 0))
                .foregroundColor(isExpanded ? Color(hex: "#E7674C") : .white)
                .font(.system(size: 24, weight: .bold))
                .frame(width: 56, height: 56)
                .background(Color(hex: "#5F7F67"))
                .clipShape(Circle())
                .shadow(radius: 4)
                .padding()
        }
        .buttonStyle(PuddingButtonStyle())
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

        // カテゴリが未登録状態でアイテム追加される場合、カテゴリを先に追加
        if !categories.contains(selectedCategory) {
            newCategory = selectedCategory
            addCategory()
        }

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
        saveCategories() // ← カテゴリ一覧を永続化
        saveCategoryColors() // ← 関連するカラーも保存
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
            let sharedDefaults = UserDefaults(suiteName: "group.com.yourname.ToDo")
            sharedDefaults?.set(data, forKey: shoppingListKey)
            sharedDefaults?.synchronize() // 追加: 即時反映を保証する
            WidgetCenter.shared.reloadAllTimelines() // 追加: ウィジェットを強制更新
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

// MARK: - 日付フォーマッター
private var dateFormatter: DateFormatter {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "ja_JP")
    formatter.dateFormat = "yyyy/MM/dd HH:mm"
    return formatter
}

    private func scheduleNotification(for item: ShoppingItem) {
        let content = UNMutableNotificationContent()
        content.title = "期限が近いタスクがあります"
        content.body = "\(item.name) の期限が近づいています。"
        content.sound = .default

        if let dueDate = item.dueDate {
            // 年・月・日・時・分を含めて通知トリガーを作成
            let triggerDate = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: dueDate)
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
