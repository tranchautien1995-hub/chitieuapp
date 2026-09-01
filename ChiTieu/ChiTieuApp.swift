import SwiftUI
import UIKit

// MARK: - Theme

enum AppTheme {
    static let background = Color(red: 0.025, green: 0.055, blue: 0.045)
    static let card = Color(red: 0.055, green: 0.105, blue: 0.085)
    static let cardSecondary = Color(red: 0.075, green: 0.135, blue: 0.110)
    static let green = Color(red: 0.20, green: 0.78, blue: 0.49)
    static let greenSoft = Color(red: 0.46, green: 0.88, blue: 0.66)
    static let textSecondary = Color.white.opacity(0.63)
    static let divider = Color.white.opacity(0.08)
}

// MARK: - Model

enum ExpenseCategory: String, CaseIterable, Codable, Identifiable {
    case food = "Ăn uống"
    case transport = "Đi lại"
    case shopping = "Mua sắm"
    case entertainment = "Giải trí"
    case bills = "Hóa đơn"
    case health = "Sức khỏe"
    case other = "Khác"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .food: return "fork.knife"
        case .transport: return "car.fill"
        case .shopping: return "bag.fill"
        case .entertainment: return "gamecontroller.fill"
        case .bills: return "doc.text.fill"
        case .health: return "heart.fill"
        case .other: return "square.grid.2x2.fill"
        }
    }
}

struct Expense: Identifiable, Codable, Equatable {
    var id: UUID
    var amount: Double
    var note: String
    var category: ExpenseCategory
    var date: Date

    init(id: UUID = UUID(), amount: Double, note: String, category: ExpenseCategory, date: Date = Date()) {
        self.id = id
        self.amount = amount
        self.note = note
        self.category = category
        self.date = date
    }
}

// MARK: - Store

final class ExpenseStore: ObservableObject {
    @Published private(set) var expenses: [Expense] = []

    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init() {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        fileURL = documents.appendingPathComponent("expenses.json")

        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        load()
    }

    func add(amount: Double, note: String, category: ExpenseCategory, date: Date) {
        let cleanNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let expense = Expense(amount: amount, note: cleanNote.isEmpty ? category.rawValue : cleanNote, category: category, date: date)
        expenses.append(expense)
        sortAndSave()
    }

    func update(_ expense: Expense) {
        guard let index = expenses.firstIndex(where: { $0.id == expense.id }) else { return }
        expenses[index] = expense
        sortAndSave()
    }

    func delete(_ expense: Expense) {
        expenses.removeAll { $0.id == expense.id }
        save()
    }

    func delete(at offsets: IndexSet, from list: [Expense]) {
        let ids = offsets.map { list[$0].id }
        expenses.removeAll { ids.contains($0.id) }
        save()
    }

    var todayTotal: Double {
        let calendar = Calendar.current
        return expenses
            .filter { calendar.isDateInToday($0.date) }
            .reduce(0) { $0 + $1.amount }
    }

    var monthTotal: Double {
        let calendar = Calendar.current
        let now = Date()
        return expenses
            .filter {
                calendar.component(.month, from: $0.date) == calendar.component(.month, from: now) &&
                calendar.component(.year, from: $0.date) == calendar.component(.year, from: now)
            }
            .reduce(0) { $0 + $1.amount }
    }

    var currentMonthExpenses: [Expense] {
        let calendar = Calendar.current
        let now = Date()
        return expenses.filter {
            calendar.component(.month, from: $0.date) == calendar.component(.month, from: now) &&
            calendar.component(.year, from: $0.date) == calendar.component(.year, from: now)
        }
    }

    func total(for category: ExpenseCategory) -> Double {
        currentMonthExpenses
            .filter { $0.category == category }
            .reduce(0) { $0 + $1.amount }
    }

    func exportCSV() -> URL? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "vi_VN")
        formatter.dateFormat = "yyyy-MM-dd HH:mm"

        var csv = "Ngày giờ,Danh mục,Nội dung,Số tiền (VND)\n"
        for item in expenses.sorted(by: { $0.date > $1.date }) {
            let safeNote = item.note.replacingOccurrences(of: "\"", with: "\"\"")
            csv += "\(formatter.string(from: item.date)),\(item.category.rawValue),\"\(safeNote)\",\(Int(item.amount))\n"
        }

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("ChiTieu-export.csv")
        do {
            try csv.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            return nil
        }
    }

    private func sortAndSave() {
        expenses.sort { $0.date > $1.date }
        save()
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            expenses = []
            return
        }
        do {
            let data = try Data(contentsOf: fileURL)
            expenses = try decoder.decode([Expense].self, from: data).sorted { $0.date > $1.date }
        } catch {
            expenses = []
        }
    }

    private func save() {
        do {
            let data = try encoder.encode(expenses)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("Không thể lưu dữ liệu: \(error)")
        }
    }
}

// MARK: - Formatting

enum Formatters {
    static let currency: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "VND"
        formatter.currencySymbol = "₫"
        formatter.maximumFractionDigits = 0
        formatter.minimumFractionDigits = 0
        formatter.locale = Locale(identifier: "vi_VN")
        return formatter
    }()

    static let day: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "vi_VN")
        formatter.dateFormat = "EEEE, dd/MM/yyyy"
        return formatter
    }()

    static let shortDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "vi_VN")
        formatter.dateFormat = "dd/MM/yyyy"
        return formatter
    }()

    static let time: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "vi_VN")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    static let monthTitle: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "vi_VN")
        formatter.dateFormat = "'Tháng' M, yyyy"
        return formatter
    }()

    static func money(_ value: Double) -> String {
        currency.string(from: NSNumber(value: value)) ?? "\(Int(value)) ₫"
    }
}

// MARK: - App

@main
struct ChiTieuApp: App {
    @StateObject private var store = ExpenseStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .preferredColorScheme(.dark)
        }
    }
}

struct RootView: View {
    @State private var showAdd = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            TabView {
                HomeView(showAdd: $showAdd)
                    .tabItem {
                        Image(systemName: "house.fill")
                        Text("Tổng quan")
                    }

                HistoryView()
                    .tabItem {
                        Image(systemName: "list.bullet.rectangle.fill")
                        Text("Lịch sử")
                    }

                StatisticsView()
                    .tabItem {
                        Image(systemName: "chart.bar.fill")
                        Text("Thống kê")
                    }
            }
            .accentColor(AppTheme.green)

            Button(action: { showAdd = true }) {
                Image(systemName: "plus")
                    .font(.system(size: 23, weight: .bold))
                    .foregroundColor(AppTheme.background)
                    .frame(width: 58, height: 58)
                    .background(AppTheme.green)
                    .clipShape(Circle())
                    .shadow(radius: 8)
            }
            .padding(.trailing, 20)
            .padding(.bottom, 68)
            .accessibilityLabel("Thêm chi tiêu")
        }
        .sheet(isPresented: $showAdd) {
            AddExpenseView()
        }
    }
}

// MARK: - Home

struct HomeView: View {
    @EnvironmentObject private var store: ExpenseStore
    @Binding var showAdd: Bool

    var body: some View {
        NavigationView {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(Formatters.monthTitle.string(from: Date()).uppercased())
                                .font(.caption.weight(.semibold))
                                .foregroundColor(AppTheme.greenSoft)

                            Text(Formatters.money(store.monthTotal))
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .minimumScaleFactor(0.7)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(20)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [AppTheme.cardSecondary, AppTheme.card]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .cornerRadius(22)

                        HStack(spacing: 12) {
                            MiniTotalCard(title: "Hôm nay", value: store.todayTotal, icon: "sun.max.fill")
                            MiniTotalCard(title: "Số khoản", valueText: "\(store.currentMonthExpenses.count)", icon: "number")
                        }

                        Button(action: { showAdd = true }) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("Thêm chi tiêu")
                                    .fontWeight(.semibold)
                                Spacer()
                                Image(systemName: "chevron.right")
                            }
                            .foregroundColor(AppTheme.background)
                            .padding(17)
                            .background(AppTheme.green)
                            .cornerRadius(16)
                        }

                        HStack {
                            Text("Gần đây")
                                .font(.title3.bold())
                            Spacer()
                            Text("\(store.expenses.count) khoản")
                                .font(.subheadline)
                                .foregroundColor(AppTheme.textSecondary)
                        }

                        if store.expenses.isEmpty {
                            EmptyStateView()
                        } else {
                            VStack(spacing: 0) {
                                ForEach(Array(store.expenses.prefix(6).enumerated()), id: \.element.id) { index, expense in
                                    ExpenseRow(expense: expense)
                                    if index < min(store.expenses.count, 6) - 1 {
                                        Divider().background(AppTheme.divider).padding(.leading, 54)
                                    }
                                }
                            }
                            .padding(.horizontal, 14)
                            .background(AppTheme.card)
                            .cornerRadius(18)
                        }
                    }
                    .padding(16)
                    .padding(.bottom, 88)
                }
            }
            .navigationTitle("Chi tiêu")
            .navigationBarTitleDisplayMode(.inline)
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

struct MiniTotalCard: View {
    let title: String
    var value: Double? = nil
    var valueText: String? = nil
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(AppTheme.green)
            Text(title)
                .font(.caption)
                .foregroundColor(AppTheme.textSecondary)
            Text(valueText ?? Formatters.money(value ?? 0))
                .font(.headline.weight(.semibold))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(AppTheme.card)
        .cornerRadius(18)
    }
}

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "leaf.fill")
                .font(.system(size: 34))
                .foregroundColor(AppTheme.green)
            Text("Chưa có khoản chi nào")
                .font(.headline)
            Text("Bấm dấu + để ghi lại khoản chi đầu tiên.")
                .font(.subheadline)
                .foregroundColor(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 42)
        .background(AppTheme.card)
        .cornerRadius(18)
    }
}

// MARK: - Add / Edit

struct AddExpenseView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: ExpenseStore

    @State private var amountText = ""
    @State private var note = ""
    @State private var category: ExpenseCategory = .food
    @State private var date = Date()
    @FocusState private var amountFocused: Bool

    var parsedAmount: Double {
        let digits = amountText.filter { $0.isNumber }
        return Double(digits) ?? 0
    }

    var body: some View {
        NavigationView {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        VStack(spacing: 4) {
                            TextField("0", text: $amountText)
                                .keyboardType(.numberPad)
                                .focused($amountFocused)
                                .multilineTextAlignment(.center)
                                .font(.system(size: 48, weight: .bold, design: .rounded))
                                .foregroundColor(.white)

                            Text("₫")
                                .font(.title3.bold())
                                .foregroundColor(AppTheme.green)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 26)
                        .background(AppTheme.card)
                        .cornerRadius(22)

                        VStack(alignment: .leading, spacing: 9) {
                            Text("Bạn đã mua gì?")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(AppTheme.textSecondary)
                            TextField("Ví dụ: Ăn tối, cà phê...", text: $note)
                                .padding(14)
                                .background(AppTheme.card)
                                .cornerRadius(14)
                        }

                        VStack(alignment: .leading, spacing: 9) {
                            Text("Danh mục")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(AppTheme.textSecondary)

                            Picker("Danh mục", selection: $category) {
                                ForEach(ExpenseCategory.allCases) { item in
                                    Label(item.rawValue, systemImage: item.icon).tag(item)
                                }
                            }
                            .pickerStyle(MenuPickerStyle())
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(AppTheme.card)
                            .cornerRadius(14)
                        }

                        VStack(alignment: .leading, spacing: 9) {
                            Text("Ngày giờ")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(AppTheme.textSecondary)
                            DatePicker("Ngày giờ", selection: $date)
                                .datePickerStyle(CompactDatePickerStyle())
                                .padding(12)
                                .background(AppTheme.card)
                                .cornerRadius(14)
                        }

                        Button(action: save) {
                            HStack {
                                Spacer()
                                Image(systemName: "checkmark.circle.fill")
                                Text("Thêm chi tiêu")
                                    .fontWeight(.bold)
                                Spacer()
                            }
                            .padding(17)
                            .foregroundColor(AppTheme.background)
                            .background(parsedAmount > 0 ? AppTheme.green : Color.gray.opacity(0.35))
                            .cornerRadius(16)
                        }
                        .disabled(parsedAmount <= 0)
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Thêm khoản chi")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Đóng") { dismiss() }
                        .foregroundColor(AppTheme.green)
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    amountFocused = true
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    private func save() {
        guard parsedAmount > 0 else { return }
        store.add(amount: parsedAmount, note: note, category: category, date: date)
        dismiss()
    }
}

struct EditExpenseView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: ExpenseStore

    @State private var expense: Expense
    @State private var amountText: String
    @State private var showDeleteConfirm = false

    init(expense: Expense) {
        _expense = State(initialValue: expense)
        _amountText = State(initialValue: String(Int(expense.amount)))
    }

    private var parsedAmount: Double {
        Double(amountText.filter { $0.isNumber }) ?? 0
    }

    var body: some View {
        NavigationView {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                Form {
                    Section(header: Text("Số tiền")) {
                        HStack {
                            TextField("0", text: $amountText)
                                .keyboardType(.numberPad)
                            Text("₫").foregroundColor(AppTheme.green)
                        }
                    }

                    Section(header: Text("Chi tiết")) {
                        TextField("Nội dung", text: $expense.note)
                        Picker("Danh mục", selection: $expense.category) {
                            ForEach(ExpenseCategory.allCases) { category in
                                Label(category.rawValue, systemImage: category.icon).tag(category)
                            }
                        }
                        DatePicker("Ngày giờ", selection: $expense.date)
                    }

                    Section {
                        Button("Xóa khoản chi", role: .destructive) {
                            showDeleteConfirm = true
                        }
                    }
                }
                .background(AppTheme.background)
            }
            .navigationTitle("Sửa khoản chi")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Hủy") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Lưu") {
                        expense.amount = parsedAmount
                        store.update(expense)
                        dismiss()
                    }
                    .disabled(parsedAmount <= 0)
                }
            }
            .confirmationDialog("Xóa khoản chi này?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                Button("Xóa", role: .destructive) {
                    store.delete(expense)
                    dismiss()
                }
                Button("Hủy", role: .cancel) { }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

// MARK: - History

struct HistoryView: View {
    @EnvironmentObject private var store: ExpenseStore
    @State private var searchText = ""
    @State private var selectedExpense: Expense?
    @State private var shareURL: URL?

    private var filtered: [Expense] {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return store.expenses
        }
        return store.expenses.filter {
            $0.note.localizedCaseInsensitiveContains(searchText) ||
            $0.category.rawValue.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var grouped: [(Date, [Expense])] {
        let calendar = Calendar.current
        let dict = Dictionary(grouping: filtered) { calendar.startOfDay(for: $0.date) }
        return dict.keys.sorted(by: >).map { ($0, dict[$0]!.sorted { $0.date > $1.date }) }
    }

    var body: some View {
        NavigationView {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                if filtered.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 34))
                            .foregroundColor(AppTheme.green)
                        Text(store.expenses.isEmpty ? "Chưa có lịch sử" : "Không tìm thấy khoản chi")
                            .font(.headline)
                        Text(store.expenses.isEmpty ? "Các khoản bạn thêm sẽ xuất hiện tại đây." : "Thử tìm bằng tên món hoặc danh mục.")
                            .font(.subheadline)
                            .foregroundColor(AppTheme.textSecondary)
                    }
                    .padding()
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 18) {
                            ForEach(grouped, id: \.0) { day, items in
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text(Formatters.day.string(from: day).capitalized)
                                            .font(.subheadline.bold())
                                            .foregroundColor(AppTheme.textSecondary)
                                        Spacer()
                                        Text(Formatters.money(items.reduce(0) { $0 + $1.amount }))
                                            .font(.subheadline.bold())
                                            .foregroundColor(AppTheme.greenSoft)
                                    }

                                    VStack(spacing: 0) {
                                        ForEach(Array(items.enumerated()), id: \.element.id) { index, expense in
                                            Button(action: { selectedExpense = expense }) {
                                                ExpenseRow(expense: expense)
                                            }
                                            .buttonStyle(PlainButtonStyle())

                                            if index < items.count - 1 {
                                                Divider().background(AppTheme.divider).padding(.leading, 54)
                                            }
                                        }
                                    }
                                    .padding(.horizontal, 14)
                                    .background(AppTheme.card)
                                    .cornerRadius(18)
                                }
                            }
                        }
                        .padding(16)
                        .padding(.bottom, 80)
                    }
                }
            }
            .navigationTitle("Lịch sử")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Tìm món đã mua...")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: export) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .disabled(store.expenses.isEmpty)
                    .foregroundColor(AppTheme.green)
                }
            }
            .sheet(item: $selectedExpense) { expense in
                EditExpenseView(expense: expense)
            }
            .sheet(isPresented: Binding(
                get: { shareURL != nil },
                set: { if !$0 { shareURL = nil } }
            )) {
                if let url = shareURL {
                    ActivityView(items: [url])
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    private func export() {
        shareURL = store.exportCSV()
    }
}

struct ExpenseRow: View {
    let expense: Expense

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: expense.category.icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(AppTheme.green)
                .frame(width: 38, height: 38)
                .background(AppTheme.green.opacity(0.12))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(expense.note)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(expense.category.rawValue)
                    Text("•")
                    Text(Formatters.time.string(from: expense.date))
                }
                .font(.caption)
                .foregroundColor(AppTheme.textSecondary)
            }

            Spacer(minLength: 8)

            Text(Formatters.money(expense.amount))
                .font(.subheadline.bold())
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.vertical, 12)
    }
}

// MARK: - Statistics

struct StatisticsView: View {
    @EnvironmentObject private var store: ExpenseStore

    private var maxCategoryTotal: Double {
        ExpenseCategory.allCases.map { store.total(for: $0) }.max() ?? 0
    }

    var body: some View {
        NavigationView {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        VStack(alignment: .leading, spacing: 7) {
                            Text("TỔNG THÁNG NÀY")
                                .font(.caption.bold())
                                .foregroundColor(AppTheme.greenSoft)
                            Text(Formatters.money(store.monthTotal))
                                .font(.system(size: 34, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            Text("\(store.currentMonthExpenses.count) khoản chi")
                                .font(.subheadline)
                                .foregroundColor(AppTheme.textSecondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(20)
                        .background(AppTheme.card)
                        .cornerRadius(20)

                        Text("Theo danh mục")
                            .font(.title3.bold())

                        VStack(spacing: 18) {
                            ForEach(ExpenseCategory.allCases) { category in
                                CategoryStatRow(
                                    category: category,
                                    amount: store.total(for: category),
                                    total: store.monthTotal,
                                    maxAmount: maxCategoryTotal
                                )
                            }
                        }
                        .padding(17)
                        .background(AppTheme.card)
                        .cornerRadius(20)

                        Text("Dữ liệu được lưu trực tiếp trên iPhone của bạn. Không có tài khoản và không gửi dữ liệu lên máy chủ.")
                            .font(.footnote)
                            .foregroundColor(AppTheme.textSecondary)
                            .padding(.horizontal, 4)
                    }
                    .padding(16)
                    .padding(.bottom, 80)
                }
            }
            .navigationTitle("Thống kê")
            .navigationBarTitleDisplayMode(.inline)
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

struct CategoryStatRow: View {
    let category: ExpenseCategory
    let amount: Double
    let total: Double
    let maxAmount: Double

    private var ratio: CGFloat {
        guard maxAmount > 0 else { return 0 }
        return CGFloat(amount / maxAmount)
    }

    private var percentText: String {
        guard total > 0 else { return "0%" }
        return "\(Int((amount / total) * 100))%"
    }

    var body: some View {
        VStack(spacing: 9) {
            HStack {
                Label(category.rawValue, systemImage: category.icon)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(percentText)
                    .font(.caption.bold())
                    .foregroundColor(AppTheme.greenSoft)
                Text(Formatters.money(amount))
                    .font(.subheadline.bold())
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.07))
                    Capsule()
                        .fill(AppTheme.green)
                        .frame(width: max(0, geo.size.width * ratio))
                }
            }
            .frame(height: 7)
        }
    }
}

// MARK: - Share Sheet

struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) { }
}
