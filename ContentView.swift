// ContentView.swift
import SwiftUI
import UIKit

struct ContentView: View {
    @StateObject private var store = TransactionsStore()

    @State private var selectedAccountID: UUID? = nil
    @State private var showAddTx = false
    @State private var editingTx: Transaction? = nil
    @State private var showAddAccount = false
    @State private var showManageAccounts = false
    @State private var selectedAccountTypeFilter: AccountType? = nil

    // budget UI
    @State private var showAddCategory = false
    @State private var showBudget = false

    private let hiddenDefaultNames: Set<String> = ["Main Checking", "Main Credit"]

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                accountPickerBar
                Divider()
                summaryHeader
                Divider()
                listView
            }
            .navigationTitle("Tracker")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    HStack {
                        Button(action: { showManageAccounts = true }) { Image(systemName: "person.3") }
                        Button(action: { showBudget = true }) { Image(systemName: "chart.pie") }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        Button(action: exportCSV) { Image(systemName: "square.and.arrow.up") }
                        Button(action: { showAddTx = true }) { Image(systemName: "plus") }
                    }
                }
            }
            // Add Transaction sheet
            .sheet(isPresented: $showAddTx) {
                AddEditTransactionView(store: store, accounts: store.accounts, transactionToEdit: nil, defaultAccountID: selectedAccountID)
            }
            // Add Account sheet
            .sheet(isPresented: $showAddAccount) {
                AddAccountView(onCreate: { name, type in
                    let a = store.addAccount(name: name, type: type)
                    selectedAccountID = a.id
                    showAddAccount = false
                })
            }
            // Manage Accounts sheet
            .sheet(isPresented: $showManageAccounts) {
                ManageAccountsView(store: store, isPresented: $showManageAccounts, selectedAccountID: $selectedAccountID)
            }
            // Add Category sheet (explicit)
            .sheet(isPresented: $showAddCategory) {
                AddCategoryView(onCreate: { name, amount, monthDate in
                    let cat = store.addCategory(name: name)
                    let key = store.monthKeyFor(date: monthDate)
                    if amount > 0 { store.setBudget(for: cat.id, monthKey: key, amount: amount) }
                    showAddCategory = false
                })
            }
            // Budget window sheet
            .sheet(isPresented: $showBudget) {
                BudgetView(store: store)
            }
            .onAppear {
                if selectedAccountID == nil, let first = visibleAccounts().first {
                    selectedAccountID = first.id
                }
            }
        }
    }

    private func visibleAccounts() -> [Account] {
        store.accounts.filter { !hiddenDefaultNames.contains($0.name) }
    }

    private var displayedTransactions: [Transaction] {
        if let sel = selectedAccountID {
            return store.items.filter { $0.accountID == sel }
        } else {
            return store.items
        }
    }

    private var accountPickerBar: some View {
        VStack(spacing: 8) {
            HStack {
                Picker("Filter", selection: Binding(get: {
                    selectedAccountTypeFilter
                }, set: { newVal in
                    selectedAccountTypeFilter = newVal
                    if let t = newVal {
                        if let first = visibleAccounts().first(where: { $0.type == t }) {
                            selectedAccountID = first.id
                        } else {
                            selectedAccountID = nil
                        }
                    } else {
                        selectedAccountID = nil
                    }
                })) {
                    Text("All").tag(AccountType?.none)
                    ForEach(AccountType.allCases) { t in
                        Text(t.displayName).tag(AccountType?.some(t))
                    }
                }
                .pickerStyle(.segmented)

                Button(action: { showAddAccount = true }) {
                    Image(systemName: "plus.circle")
                }
                .padding(.leading, 8)
            }
            .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(visibleAccounts().filter { selectedAccountTypeFilter == nil ? true : $0.type == selectedAccountTypeFilter! }) { acct in
                        Button(action: { selectedAccountID = acct.id }) {
                            VStack {
                                Text(acct.name).font(.subheadline).lineLimit(1)
                                Text(store.balanceForAccount(acct.id), format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
                                    .font(.caption)
                                    .foregroundColor(acct.type == .credit ? .red : .green)
                            }
                            .padding(8)
                            .background(RoundedRectangle(cornerRadius: 10).stroke(selectedAccountID == acct.id ? Color.accentColor : Color.gray.opacity(0.3), lineWidth: selectedAccountID == acct.id ? 2 : 1))
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 6)
        .background(Color(UIColor.secondarySystemBackground))
    }

    private var summaryHeader: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("Main Balance").font(.caption)
                Text(store.totalForAccountType(.checking), format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
                    .font(.title2).bold()
            }
            Spacer()
            VStack(alignment: .trailing) {
                Text("Owe Balance").font(.caption)
                Text(store.totalOweBalance(), format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
                    .foregroundColor(.red)
            }
        }
        .padding()
    }

    private var listView: some View {
        List {
            ForEach(displayedTransactions) { t in
                Button(action: { editingTx = t }) {
                    VStack(alignment: .leading) {
                        HStack {
                            Text(store.categoryName(for: t.categoryID) ?? t.purpose).font(.headline)
                            Spacer()
                            Text(t.type == .income ? "+" : "-")
                                .foregroundColor(t.type == .income ? .green : .red)
                            Text(t.amount, format: .currency(code: Locale.current.currency?.identifier ?? "USD")).bold()
                        }

                        HStack {
                            if t.paybackGroupID != nil {
                                Text("Payback").font(.caption).padding(4).background(Color.yellow.opacity(0.2)).cornerRadius(6)
                            } else {
                                Text(t.note).font(.subheadline).foregroundColor(.secondary).lineLimit(2)
                            }
                            Spacer()
                            Text(t.date, style: .date).font(.caption).foregroundColor(.gray)
                        }
                        HStack {
                            Spacer()
                            Text(store.accountName(for: t.accountID) ?? "Unassigned").font(.caption).foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 6)
                }.buttonStyle(.plain)
            }
            .onDelete(perform: deleteFromDisplayed)
        }
        .listStyle(.insetGrouped)
    }

    private func deleteFromDisplayed(at offsets: IndexSet) {
        let current = displayedTransactions
        let idsToDelete = offsets.compactMap { idx -> UUID? in
            guard current.indices.contains(idx) else { return nil }
            return current[idx].id
        }
        for id in idsToDelete {
            store.delete(id: id)
        }
        if let sel = selectedAccountID, !store.accounts.contains(where: { $0.id == sel }) {
            selectedAccountID = nil
        }
    }

    private func exportCSV() {
        guard let url = store.writeCSVFile() else { return }
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = scene.windows.first?.rootViewController {
            let av = UIActivityViewController(activityItems: [url], applicationActivities: nil)
            root.present(av, animated: true, completion: nil)
        }
    }
}

