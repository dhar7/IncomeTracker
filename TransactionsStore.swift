// TransactionsStore.swift
// Complete, self-contained TransactionsStore implementation

import Foundation
import Combine

@MainActor
final class TransactionsStore: ObservableObject {
    @Published private(set) var items: [Transaction] = []
    @Published private(set) var accounts: [Account] = []
    @Published private(set) var categories: [BudgetCategory] = []
    @Published private(set) var allocations: [BudgetAllocation] = []

    private let fileName = "appdata_v1.json"
    private var fileURL: URL {
        let fm = FileManager.default
        #if targetEnvironment(simulator)
        return fm.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(fileName)
        #else
        let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        if !fm.fileExists(atPath: appSupport.path) {
            try? fm.createDirectory(at: appSupport, withIntermediateDirectories: true)
        }
        return appSupport.appendingPathComponent(fileName)
        #endif
    }

    init() {
        Task { await load() }
    }

    private struct AppData: Codable {
        var accounts: [Account]
        var items: [Transaction]
        var categories: [BudgetCategory]
        var allocations: [BudgetAllocation]
    }

    // MARK: - Account helpers

    func checkingAccounts() -> [Account] {
        accounts.filter { $0.type == .checking }
    }

    func creditAccounts() -> [Account] {
        accounts.filter { $0.type == .credit }
    }

    // MARK: - Categories & allocations CRUD

    func addCategory(name: String) -> BudgetCategory {
        let c = BudgetCategory(name: name)
        categories.append(c)
        saveInBackground()
        return c
    }

    func updateCategory(_ c: BudgetCategory) {
        if let idx = categories.firstIndex(where: { $0.id == c.id }) {
            categories[idx] = c
            saveInBackground()
        }
    }

    func deleteCategory(id: UUID) {
        // remove allocations for that category and clear categoryID from transactions
        allocations.removeAll { $0.categoryID == id }
        for i in items.indices {
            if items[i].categoryID == id { items[i].categoryID = nil }
        }
        categories.removeAll { $0.id == id }
        saveInBackground()
    }

    func setBudget(for categoryID: UUID, monthKey: String, amount: Double) {
        if let idx = allocations.firstIndex(where: { $0.categoryID == categoryID && $0.monthKey == monthKey }) {
            allocations[idx].amount = amount
        } else {
            allocations.append(BudgetAllocation(categoryID: categoryID, monthKey: monthKey, amount: amount))
        }
        saveInBackground()
    }

    func budgetFor(categoryID: UUID, monthKey: String) -> Double? {
        allocations.first(where: { $0.categoryID == categoryID && $0.monthKey == monthKey })?.amount
    }

    func deleteAllocation(id: UUID) {
        allocations.removeAll { $0.id == id }
        saveInBackground()
    }

    // MARK: - Accounts CRUD

    func addAccount(name: String, type: AccountType) -> Account {
        let a = Account(name: name, type: type)
        accounts.append(a)
        saveInBackground()
        return a
    }

    func updateAccount(_ account: Account) {
        if let idx = accounts.firstIndex(where: { $0.id == account.id }) {
            accounts[idx] = account
            saveInBackground()
        }
    }

    func deleteAccount(id: UUID) {
        accounts.removeAll { $0.id == id }
        // remove transactions that targeted the deleted account
        items.removeAll { $0.accountID == id }
        saveInBackground()
    }

    // MARK: - Transactions CRUD

    func add(_ t: Transaction) {
        items.append(t)
        sortItems()
        saveInBackground()
    }

    func addMultiple(_ txs: [Transaction]) {
        items.append(contentsOf: txs)
        sortItems()
        saveInBackground()
    }

    func update(_ t: Transaction) {
        if let idx = items.firstIndex(where: { $0.id == t.id }) {
            items[idx] = t
            sortItems()
            saveInBackground()
        }
    }

    /// DELETE by id: if this transaction belongs to a paybackGroupID, remove the whole group.
    func delete(id: UUID) {
        guard let tx = items.first(where: { $0.id == id }) else { return }

        if let group = tx.paybackGroupID {
            // remove all transactions in the same group
            items.removeAll { $0.paybackGroupID == group }
        } else {
            // normal single transaction - remove only it
            items.removeAll { $0.id == id }
        }

        saveInBackground()
    }

    func delete(atOffsets offsets: IndexSet) {
        let sortedOffsets = offsets.sorted(by: >)
        for index in sortedOffsets {
            guard items.indices.contains(index) else { continue }
            let id = items[index].id
            delete(id: id)
        }
    }

    private func sortItems() {
        items.sort { $0.date > $1.date }
    }

    // MARK: - Budget helpers

    /// month key "YYYY-MM" from a Date (unique name to avoid shadowing)
    func monthKeyFor(date: Date) -> String {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM"
        return df.string(from: date)
    }

    /// total spent for category in a month (only expenses included)
    func spentForCategoryMonth(categoryID: UUID, monthKey: String) -> Double {
        items.filter { $0.categoryID == categoryID && monthKeyFor(date: $0.date) == monthKey && $0.type == .expense }
            .map { $0.amount }
            .reduce(0, +)
    }

    /// remaining = budget - spent. If no budget set, returns nil
    func remainingForCategoryMonth(categoryID: UUID, monthKey: String) -> Double? {
        guard let budget = budgetFor(categoryID: categoryID, monthKey: monthKey) else { return nil }
        let spent = spentForCategoryMonth(categoryID: categoryID, monthKey: monthKey)
        return budget - spent
    }

    /// whether category is over budget (spent > budget)
    func isCategoryOverBudget(categoryID: UUID, monthKey: String) -> Bool {
        guard let budget = budgetFor(categoryID: categoryID, monthKey: monthKey) else { return false }
        let spent = spentForCategoryMonth(categoryID: categoryID, monthKey: monthKey)
        return spent > budget
    }

    // MARK: - Totals & legacy helpers

    /// Balance for a single account (income - expense)
    func balanceForAccount(_ accountID: UUID) -> Double {
        items.filter { $0.accountID == accountID }.reduce(0) { acc, t in
            acc + (t.type == .income ? t.amount : -t.amount)
        }
    }

    /// Sum of balances across all accounts of given type (checking or credit)
    func totalForAccountType(_ type: AccountType) -> Double {
        let ids = accounts.filter { $0.type == type }.map { $0.id }
        return ids.reduce(0) { acc, id in
            acc + balanceForAccount(id)
        }
    }

    /// Due amount for a specific credit account = total expenses on that credit account minus total payments (incomes) recorded on that credit account.
    func dueAmountForCreditAccount(_ accountID: UUID) -> Double {
        let expenses = items.filter { $0.accountID == accountID && $0.type == .expense }.map { $0.amount }.reduce(0, +)
        let payments = items.filter { $0.accountID == accountID && $0.type == .income }.map { $0.amount }.reduce(0, +)
        return max(0, expenses - payments)
    }

    /// TOTAL OWE: sum of due amounts across all credit accounts
    func totalOweBalance() -> Double {
        let creditIDs = accounts.filter { $0.type == .credit }.map { $0.id }
        return creditIDs.reduce(0.0) { acc, id in
            acc + dueAmountForCreditAccount(id)
        }
    }

    // overall totals (all accounts)
    var totalIncome: Double {
        items.filter { $0.type == .income }.map { $0.amount }.reduce(0, +)
    }

    var totalExpense: Double {
        items.filter { $0.type == .expense }.map { $0.amount }.reduce(0, +)
    }

    var balance: Double {
        totalIncome - totalExpense
    }

    // MARK: - Payback (creates two transactions linked by paybackGroupID)
    func recordPayback(amount: Double, fromCheckingID: UUID, toCreditID: UUID, note: String? = nil, date: Date = Date()) {
        let groupID = UUID()
        // Expense on the checking account
        let expense = Transaction(
            id: UUID(),
            amount: amount,
            purpose: "Payback to \(accountName(for: toCreditID) ?? "Credit")",
            note: note ?? "",
            type: .expense,
            accountID: fromCheckingID,
            date: date,
            categoryID: nil,
            paybackGroupID: groupID
        )

        // Income on the credit account (reduces due)
        let income = Transaction(
            id: UUID(),
            amount: amount,
            purpose: "Payment from \(accountName(for: fromCheckingID) ?? "Checking")",
            note: note ?? "",
            type: .income,
            accountID: toCreditID,
            date: date,
            categoryID: nil,
            paybackGroupID: groupID
        )

        addMultiple([expense, income])
    }

    // MARK: - Persistence

    func load() async {
        let fm = FileManager.default
        if fm.fileExists(atPath: fileURL.path) {
            do {
                let data = try Data(contentsOf: fileURL)
                let decoded = try JSONDecoder().decode(AppData.self, from: data)
                accounts = decoded.accounts
                items = decoded.items
                categories = decoded.categories
                allocations = decoded.allocations
                sortItems()
            } catch {
                print("Load error:", error)
                accounts = []
                items = []
                categories = []
                allocations = []
            }
        } else {
            // fresh start
            accounts = []
            items = []
            categories = []
            allocations = []
        }
    }

    func save() async {
        do {
            let data = try JSONEncoder().encode(AppData(accounts: accounts, items: items, categories: categories, allocations: allocations))
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            print("Save error:", error)
        }
    }

    private func saveInBackground() {
        Task { await save() }
    }

    // MARK: - CSV Export

    func exportCSV() -> String {
        var rows = ["id,date,type,amount,purpose,note,account,category,paybackGroupID"]
        var accountLookup: [UUID: String] = [:]
        for a in accounts {
            accountLookup[a.id] = a.name
        }

        for tx in items {
            let acctName = tx.accountID.flatMap { accountLookup[$0] }
            rows.append(tx.csvRow(accountName: acctName))
        }
        return rows.joined(separator: "\n")
    }

    func writeCSVFile() -> URL? {
        let csv = exportCSV()
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("transactions_export_\(Int(Date().timeIntervalSince1970)).csv")
        do {
            try csv.data(using: .utf8)?.write(to: tmp)
            return tmp
        } catch {
            print("CSV write error:", error)
            return nil
        }
    }

    // Helper: find account by id
    func accountName(for id: UUID?) -> String? {
        guard let id = id else { return nil }
        return accounts.first(where: { $0.id == id })?.name
    }

    // Helper: find category name
    func categoryName(for id: UUID?) -> String? {
        guard let id = id else { return nil }
        return categories.first(where: { $0.id == id })?.name
    }
}
