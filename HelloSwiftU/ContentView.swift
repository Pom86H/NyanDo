import UserNotifications
import SwiftUI
import WidgetKit

// MARK: - カスタムボタンスタイル
struct PuddingButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 1.2 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.5), value: configuration.isPressed)
    }
}
enum Tab {
    case top
    case history
    case settings
}
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

struct ContentView: View {
    // MARK: - State Properties
    @State private var newItem: String = "" // 新規アイテム名
    @State private var itemNote: String? = nil // 新規アイテムのメモ
    @State private var showUnifiedAddSheet: Bool = false
    @State private var showTitle = false
    @State private var titleOffset: CGFloat = 20 // 下からスライド
    @State private var selectedCategory: String = "食品" // 選択中カテゴリ
    @State private var shoppingList: [String: [ShoppingItem]] = [:] // 買い物リスト
    @State private var categories: [String] = ["食品", "日用品", "その他"] // カテゴリ一覧
    @State private var newCategory: String = "" // 新規カテゴリ名
    @State private var showCategoryEditSheet = false // カテゴリ編集シート表示
    @State private var showAddItemSheet = false // アイテム追加シート表示
    @State private var showAddCategorySheet = false // カテゴリ追加シート表示
    @State private var isAddingNewCategory: Bool = false // 新規カテゴリ追加UI表示
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
//    @FocusState private var isNewItemFieldFocused: Bool // フォーカス
    @State private var checkedItemIDs: Set<UUID> = []
    @State private var disappearingItemIDs: Set<UUID> = []
    @State private var selectedTab: Tab = .top
    @FocusState private var isNewItemFieldFocused: Bool

    // MARK: - Note Alert State
    @State private var showingNoteAlert: Bool = false
    @State private var selectedNoteText: String = ""
    @State private var editingNoteItem: ShoppingItem? = nil
    @State private var isNoteViewingOnly: Bool = false
    @State private var itemToEdit: ShoppingItem? = nil
    
    // MARK: - Constants
    private let shoppingListKey = "shoppingListKey"
    private let deletedItemsKey = "deletedItemsKey"
    @State private var categoryColors: [String: Color] = [
        "食品": .green,
        "日用品": .blue,
        "その他": .gray
    ]
    
    // MARK: - Body
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                backgroundView

                // タイトル
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
                                .font(.system(size: 24, weight: .bold))
                                .frame(width: 56, height: 56)
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
            .sheet(item: $itemToEdit) { item in
                TaskEditSheet(item: Binding(
                    get: { item },
                    set: { newItem in
                        if let category = findCategory(for: item),
                           var items = shoppingList[category],
                           let index = items.firstIndex(of: item) {
                            items[index] = newItem
                            shoppingList[category] = items
                            saveItems()
                        }
                    }
                )) { updatedItem in
                    // 追加処理があればここに
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
            .sheet(isPresented: $showDeletedItemsSheet) {
                NavigationView {
                    ZStack {
                        // 背景色レイヤー
                        Color(hex: "#444949")
                            .ignoresSafeArea()

                        // UIコンテンツレイヤー（削除履歴テキスト・リストなど）
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
                            } else {
                                VStack(spacing: 0) {
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
                                            .padding(.vertical, 4)
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

                                    Text("🗑️ 削除履歴は15件まで保持されます")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                        .padding(.bottom, 8)
                                        .frame(maxWidth: .infinity, alignment: .center)
                                }
                            }
                        }
                        .zIndex(1)
                    }
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
        }
    }
    
    // MARK: - Find Category for Item
    private func findCategory(for item: ShoppingItem) -> String? {
        for (category, items) in shoppingList {
            if items.contains(item) {
                return category
            }
        }
        return nil
    }
    
    // MARK: - Toolbar Buttons
    private var trailingButtons: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Button {
                let impact = UIImpactFeedbackGenerator(style: .medium)
                impact.impactOccurred()
                withAnimation {
                    showCategoryEditSheet = true
                }
            } label: {
                Image(systemName: "list.bullet")
                    .foregroundColor(.white)
                    .font(.system(size: 20, weight: .medium))
                    .frame(width: 44, height: 44)
                    .background(
                        showAddItemSheet
                        ? Color.gray.opacity(0.3)
                        : (showCategoryEditSheet ? Color.gray.opacity(0.4) : Color(hex: "#5F7F67"))
                    )
                    .clipShape(Circle())
                    .shadow(radius: 3)
            }
            .buttonStyle(PuddingButtonStyle())
        }
    }
    
    // MARK: - Navigation Bar Appearance
    private func setupNavigationBar() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.titleTextAttributes = [
            .font: UIFont(name: "Times New Roman", size: 24)!
        ]
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
    }
    
    // MARK: - Unified Add Overlay
    private var unifiedAddOverlay: some View {
        ZStack(alignment: .bottom) {
            if showAddItemSheet {
                Color.black
                    .opacity(0.3)
                    .blur(radius: showAddItemSheet ? 3 : 0)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation {
                            showAddItemSheet = false
                        }
                    }
                    .transition(.opacity)

                itemAddForm
                    .padding(.bottom, 32)
                    .scaleEffect(showAddItemSheet ? 1.0 : 0.8)
                    .offset(y: showAddItemSheet ? 0 : 150)
                    .opacity(showAddItemSheet ? 1 : 0)
                    .animation(.interpolatingSpring(stiffness: 120, damping: 16), value: showAddItemSheet)
            }
        }
        // --- カテゴリ編集シート ---
        .sheet(isPresented: $showCategoryEditSheet) {
            NavigationView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("カテゴリの整理：\(categories.count)件")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.black)
                        .padding(.horizontal)
                        .padding(.top, 16)

                    // ここにスワイプ削除の説明メッセージを追加
                    Text("左にスワイプでカテゴリを削除")
                        .font(.caption2)
                        .foregroundColor(.gray)
                        .padding(.horizontal)

                    if categories.isEmpty {
                        Text("カテゴリは登録されていません")
                            .foregroundColor(.gray)
                            .padding()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        List {
                            ForEach(categories, id: \.self) { category in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(category)
                                        .foregroundColor(.black)
                                    Text("現在の色：\(colorName(for: categoryColors[category] ?? .gray))")
                                        .font(.caption2)
                                        .foregroundColor(.gray)
                                    // カラー選択用のプリセット色
                                    let presetColors: [Color] = [.red, .orange, .yellow, .green, .blue, .purple, .gray]
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack {
                                            ForEach(presetColors, id: \.self) { color in
                                                Circle()
                                                    .fill(color)
                                                    .frame(width: categoryColors[category] == color ? 28 : 22,
                                                           height: categoryColors[category] == color ? 28 : 22)
                                                    .overlay(
                                                        Circle()
                                                            .stroke(Color.white, lineWidth: categoryColors[category] == color ? 3 : 1)
                                                    )
                                                    .shadow(radius: 1)
                                                    .onTapGesture {
                                                        categoryColors[category] = color
                                                        saveCategoryColors()
                                                    }
                                                    .accessibilityLabel(Text("この色に変更：\(colorName(for: color))"))
                                            }
                                        }
                                        .padding(.vertical, 4)
                                    }
                                }
                                .onAppear {
                                    if categoryColors[category] == nil {
                                        categoryColors[category] = .gray // デフォルト色
                                    }
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        if canDeleteCategory(category) {
                                            deleteCategory(category)
                                        }
                                    } label: {
                                        Image(systemName: "trash")
                                    }
                                }
                            }
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                        .background(Color.clear)
                    }
                }
                .background(backgroundView)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            showCategoryEditSheet = false
                        } label: {
                            Image(systemName: "xmark")
                        }
                        .foregroundColor(Color(hex: "#AA4D53"))
                    }
                }
            }
        }
    }

    // MARK: - Item Add Form
    private var itemAddForm: some View {
        VStack(spacing: 12) {
            // 1. Heading at the top

            VStack(alignment: .leading, spacing: 12) {
                TextField("例：キャットフード", text: $newItem)
                    .focused($isNewItemFieldFocused)
                    .padding(.vertical, 6)
                    .padding(.horizontal)
                    .background(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.5), lineWidth: 1))

                TextField("メモ（任意）", text: Binding(
                    get: { itemNote ?? "" },
                    set: { itemNote = $0 }
                ))
                .padding(.vertical, 6)
                .padding(.horizontal)
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
                    .background(Color.white)
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
                                        .background(
                                            selectedCategory == category
                                            ? (categoryColors[category] ?? Color.gray)
                                            : Color.gray.opacity(0.2)
                                        )
                                        .foregroundColor(.white)
                                        .cornerRadius(4)
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
                                .cornerRadius(4)
                            }
                        }
                        .padding(.horizontal, 4)
                    }

                    // 新しいカテゴリ入力欄（表示条件付き）
                    if isAddingNewCategory {
                        VStack(spacing: 8) {
                            TextField("新しいカテゴリ名", text: $newCategory)
                                .padding(.vertical, 6)
                                .padding(.horizontal)
                                .background(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.5), lineWidth: 1))

                            // 色を選択するUIを追加
                            Text("色を選択").font(.subheadline).fontWeight(.medium)
                            HStack {
                                let presetColors: [Color] = [.red, .orange, .yellow, .green, .blue, .purple, .gray]
                                ForEach(presetColors, id: \.self) { color in
                                    Circle()
                                        .fill(color)
                                        .frame(width: categoryColors[newCategory] == color ? 34 : 28,
                                               height: categoryColors[newCategory] == color ? 34 : 28)
                                        .shadow(radius: 2)
                                        .overlay(
                                            Circle().stroke(Color.white, lineWidth: categoryColors[newCategory] == color ? 3 : 1)
                                        )
                                        .scaleEffect(categoryColors[newCategory] == color ? 1.1 : 1.0)
                                        .animation(.easeOut(duration: 0.2), value: categoryColors[newCategory])
                                        .onTapGesture {
                                            categoryColors[newCategory] = color
                                        }
                                }
                            }

                            Button(action: {
                                addCategory()
                                selectedCategory = newCategory
                                newCategory = ""
                                isAddingNewCategory = false
                            }) {
                                Text("カテゴリを作成")
                                    .font(.subheadline)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Color.gray.opacity(0.2))
                                    .foregroundColor(.primary)
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color(hex: "#5F7F67"), lineWidth: 1)
                                    )
                            }
                            .disabled(newCategory.trimmingCharacters(in: .whitespaces).isEmpty)
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
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(radius: 2)
        .padding(.horizontal, 12)
    }

    // MARK: - Category Add Form
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
    
    // MARK: - Background View
    private var backgroundView: some View {
        ZStack {
            Color(red: 0.98, green: 0.97, blue: 0.94) // 薄いクリーム色
                .ignoresSafeArea()

            if selectedTab == .top && shoppingList.values.allSatisfy({ $0.isEmpty }) {
                LottieView(name: "Space-Cat", loopMode: .loop)
                    .ignoresSafeArea()
                    .opacity(0.6)
                    .scaleEffect(1.5)
                    .allowsHitTesting(false)
                    .zIndex(1)
            }

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

            if selectedTab == .top && shoppingList.values.allSatisfy({ $0.isEmpty }) {
                VStack {
                    Spacer()
                    Text("🎉 ミッションコンプリート！")
                        .font(.callout)
                        .fontWeight(.semibold)
                        .foregroundColor(.gray.opacity(0.7))
                        .padding(.bottom, 50)
                    Spacer()
                }
                .zIndex(2)
            }
        }
        .ignoresSafeArea()
    }
    
    // MARK: - Content View
    private var contentView: some View {
        ZStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    Spacer().frame(height: 40)
                    ForEach(Array(categories.enumerated()), id: \.element) { idx, category in
                        categorySection(for: category, idx: idx)
                    }
                }
                .padding(.bottom, 60)
                .padding(.horizontal, 16)
            }
        }
    }
    
    // MARK: - Category Section
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
    
    // MARK: - Header View
    private func headerView(for category: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                // カテゴリ名
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
                // 削除履歴画面
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
                            VStack(spacing: 0) {
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
                                        .padding(.vertical, 4)
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
                                // --- 追加: 削除履歴件数上限メッセージ ---
                                Text("🗑️ 削除履歴は15件まで保持されます")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                    .padding(.bottom, 8)
                                    .frame(maxWidth: .infinity, alignment: .center)
                            }
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
        
    }
    // MARK: - Item Row
    private func itemRow(for item: ShoppingItem, in category: String, isLast: Bool) -> some View {
        VStack {
            HStack(alignment: .center, spacing: 12) {
                Button {
                    let impact = UIImpactFeedbackGenerator(style: .medium)
                    impact.impactOccurred()
                    withAnimation(.easeOut(duration: 0.2)) {
                        checkedItemIDs.insert(item.id)
                    }
                    withAnimation(.easeIn(duration: 0.2).delay(0.05)) {
                        disappearingItemIDs.insert(item.id)
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        deleteItem(item, from: category)
                        checkedItemIDs.remove(item.id)
                        disappearingItemIDs.remove(item.id)
                    }
                } label: {
                    ZStack {
                        Circle()
                            .strokeBorder(categoryColors[category] ?? .gray, lineWidth: 2)
                            .background(
                                Circle()
                                    .fill(checkedItemIDs.contains(item.id) ? categoryColors[category] ?? .gray : .clear)
                            )
                            .frame(width: 18, height: 18)

                        if checkedItemIDs.contains(item.id) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .transition(.scale)
                        }
                    }
                    .frame(width: 32, height: 32) // タップ領域を広くする
                    .contentShape(Rectangle())   // 透明部分もタップ可能に
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 2) {
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

                    if let note = item.note, !note.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "pencil")
                                .font(.caption2)
                                .foregroundColor(.gray)
                            Text("メモあり")
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                    }
                }

                Spacer()
            }
            .padding(.vertical, 1)
            .onTapGesture {
                itemToEdit = item
            }
            .onLongPressGesture {
                if let note = item.note, !note.isEmpty {
                    editingNoteItem = item
                    selectedNoteText = note
                    isNoteViewingOnly = false
                    showingNoteAlert = true
                }
            }
            .alert("📝 メモ", isPresented: $showingNoteAlert, actions: {
                if isNoteViewingOnly {
                    Button("閉じる", role: .cancel) {
                        editingNoteItem = nil
                        isNoteViewingOnly = false
                    }
                } else {
                    TextField("メモ", text: $selectedNoteText)
                    Button("保存") {
                        if let item = editingNoteItem,
                           var items = shoppingList[category],
                           let index = items.firstIndex(of: item) {
                            items[index].note = selectedNoteText
                            shoppingList[category] = items
                            saveItems()
                        }
                        editingNoteItem = nil
                    }
                    Button("キャンセル", role: .cancel) {
                        editingNoteItem = nil
                    }
                }
            }, message: {
                Text(isNoteViewingOnly ? selectedNoteText : "このタスクのメモを編集できます。")
            })

            if !isLast {
                Divider()
                    .padding(.leading, 36)
            }
        }
    }
    // MARK: - Plus Button
    private var plusButton: some View {
        Button {
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred()
            withAnimation {
                showAddItemSheet = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isNewItemFieldFocused = true
            }
        } label: {
            Image(systemName: "plus")
                .foregroundColor(.white)
                .font(.system(size: 24, weight: .bold))
                .frame(width: 56, height: 56)
                .background(Color(hex: "#5F7F67"))
                .clipShape(Circle())
                .shadow(radius: 4)
                .padding()
        }
        .buttonStyle(PuddingButtonStyle())
    }
}

// MARK: - Helper Functions Extension
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
            let item = ShoppingItem(name: trimmedItem, dueDate: addDueDate ? newDueDate : nil, note: itemNote)
            items.append(item)
            shoppingList[selectedCategory] = items
            if let dueDate = item.dueDate {
                scheduleNotification(for: item)
            }
        }

        newItem = ""
        newDueDate = nil
        addDueDate = false
        itemNote = nil
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
    
    /// 削除アイテムを履歴に追加（最大15件）
    private func addDeletedItems(_ items: [(name: String, category: String, dueDate: Date?)]) {
        for item in items {
            deletedItems.removeAll { $0.name == item.name && $0.category == item.category }
            deletedItems.insert(DeletedItem(name: item.name, category: item.category, dueDate: item.dueDate), at: 0)
        }
        if deletedItems.count > 15 {
            deletedItems = Array(deletedItems.prefix(15))
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
    
    // MARK: - Category Color Save/Load
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

    /// 通知をスケジュール
    private func scheduleNotification(for item: ShoppingItem) {
        let content = UNMutableNotificationContent()
        content.title = "即時通知"
        content.body = """
\(item.name)
\(dateFormatter.string(from: item.dueDate ?? Date()))
"""
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

    // MARK: - Color Name Helper
    private func colorName(for color: Color) -> String {
        let namedColors: [(Color, String)] = [
            (.red, "レッド"), (.orange, "オレンジ"), (.yellow, "イエロー"),
            (.green, "グリーン"), (.blue, "ブルー"), (.purple, "パープル"), (.gray, "グレー")
        ]

        guard let target = UIColor(color).cgColor.components else {
            return "未定義の色"
        }

        var closestName = "未定義の色"
        var smallestDistance = CGFloat.greatestFiniteMagnitude

        for (namedColor, name) in namedColors {
            if let components = UIColor(namedColor).cgColor.components {
                let distance = sqrt(
                    pow((target[0] - components[0]), 2) +
                    pow((target[1] - components[1]), 2) +
                    pow((target[2] - components[2]), 2)
                )
                if distance < smallestDistance {
                    smallestDistance = distance
                    closestName = name
                }
            }
        }
        return closestName
    }
}

// MARK: - Date Formatter
private var dateFormatter: DateFormatter {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "ja_JP")
    formatter.dateFormat = "yyyy/MM/dd HH:mm"
    return formatter
}

/*
 注意：このアプリは UserDefaults を用いてリスト内容・履歴を保存しているため、
 アプリを閉じたり端末を再起動してもデータは保持される。
 */


