// AddEditTransactionView.swift
// Full file — updated to show remaining budget in red inside the category dropdown (menu-style picker)

import SwiftUI

struct AddEditTransactionView: View {
    @Environment(\.dismiss) var dismiss

    @ObservedObject var store: TransactionsStore
    var accounts: [Account]
    var transactionToEdit: Transaction?
    var defaultAccountID: UUID?

    // Note: we persist directly into store to ensure budgets update immediately.

    @State private var amountText: String = ""
    @State private var note: String = ""
    @State private var type: TransactionType = .expense
    @State private var date: Date = Date()
    @State private var selectedAccountID: UUID?
    @State private var isPayback: Bool = false

    @State private var selectedCategoryID: UUID? = nil

    // payback
    @State private var selectedPaymentAccountID: UUID? = nil
    @State private var selectedCreditAccountID: UUID? = nil

    init(store: TransactionsStore, accounts: [Account], transactionToEdit: Transaction? = nil, defaultAccountID: UUID? = nil) {
        self.store = store
        self.accounts = accounts
        self.transactionToEdit = transactionToEdit
        self.defaultAccountID = defaultAccountID

        _amountText = State(initialValue: transactionToEdit != nil ? String(format: "%.2f", transactionToEdit!.amount) : "")
        _note = State(initialValue: transactionToEdit?.note ?? "")
        _type = State(initialValue: transactionToEdit?.type ?? .expense)
        _date = State(initialValue: transactionToEdit?.date ?? Date())
        _selectedAccountID = State(initialValue: transactionToEdit?.accountID ?? defaultAccountID ?? accounts.first?.id)
        _selectedCategoryID = State(initialValue: transactionToEdit?.categoryID ?? nil)
    }

    private func monthKeyForDate(_ d: Date) -> String { store.monthKeyFor(date: d) }

    var body: some View {
        NavigationView {
            Form {
                Section { Toggle("Payback", isOn: $isPayback.animation()) }

                if isPayback {
                    // Payback UI
                    Section(header: Text("Amount")) {
                        TextField("Amount", text: $amountText).keyboardType(.decimalPad)
                    }

                    Section(header: Text("Pay to (Credit)")) {
                        if store.creditAccounts().isEmpty {
                            Text("No credit accounts available.")
                        } else {
                            Picker("Pay to", selection: Binding(get: { selectedCreditAccountID ?? store.creditAccounts().first!.id }, set: { selectedCreditAccountID = $0 })) {
                                ForEach(store.creditAccounts()) { a in
                                    HStack {
                                        Text(a.name)
                                        Spacer()
                                        Text(store.dueAmountForCreditAccount(a.id), format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
                                    }
                                    .tag(a.id)
                                }
                            }
                            .pickerStyle(.menu)
                        }
                    }

                    Section(header: Text("Pay from (Checking)")) {
                        if store.checkingAccounts().isEmpty {
                            Text("No checking accounts available.")
                        } else {
                            Picker("Pay from", selection: Binding(get: { selectedPaymentAccountID ?? store.checkingAccounts().first!.id }, set: { selectedPaymentAccountID = $0 })) {
                                ForEach(store.checkingAccounts()) { a in
                                    HStack {
                                        Text(a.name)
                                        Spacer()
                                        Text(store.balanceForAccount(a.id), format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
                                    }
                                    .tag(a.id)
                                }
                            }
                            .pickerStyle(.menu)
                        }
                    }

                    Section(header: Text("Note / Date")) {
                        TextField("Note", text: $note)
                        DatePicker("When", selection: $date, displayedComponents: [.date, .hourAndMinute])
                    }
                } else {
                    // Regular transaction UI
                    Section(header: Text("Amount")) {
                        TextField("Amount", text: $amountText).keyboardType(.decimalPad)
                    }

                    Section(header: Text("Category")) {
                        if store.categories.isEmpty {
                            Text("No categories. Create one in Budget window first.")
                        } else {
                            // stable default ID for the binding
                            let defaultCatID = store.categories.first!.id
                            Picker(selection: Binding(get: { selectedCategoryID ?? defaultCatID }, set: { selectedCategoryID = $0 }), label: HStack {
                                // show currently selected category name + remaining on the label itself
                                if let sel = selectedCategoryID ?? store.categories.first?.id, let cat = store.categories.first(where: { $0.id == sel }) {
                                    Text(cat.name)
                                    Spacer()
                                    let key = monthKeyForDate(date)
                                    if let rem = store.remainingForCategoryMonth(categoryID: cat.id, monthKey: key) {
                                        Text(rem, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
                                            .foregroundColor(rem < 0 ? .red : .secondary)
                                    } else {
                                        Text("No budget").foregroundColor(.secondary)
                                    }
                                } else {
                                    Text("Category")
                                }
                            }) {
                                ForEach(store.categories) { c in
                                    // compute remaining for this category month
                                    let key = monthKeyForDate(date)
                                    let remOpt = store.remainingForCategoryMonth(categoryID: c.id, monthKey: key)

                                    // each menu row: category name (left) and remaining (right)
                                    HStack {
                                        Text(c.name)
                                        Spacer()
                                        if let rem = remOpt {
                                            Text(rem, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
                                                .foregroundColor(rem < 0 ? .red : .secondary)
                                        } else {
                                            Text("No budget").foregroundColor(.secondary)
                                        }
                                    }
                                    .tag(c.id)
                                }
                            }
                            .pickerStyle(.menu)
                        }
                    }

                    Section(header: Text("Details")) {
                        TextField("Note", text: $note)
                    }

                    Section {
                        Picker("Type", selection: $type) {
                            ForEach(TransactionType.allCases) { v in Text(v.displayName).tag(v) }
                        }
                        .pickerStyle(.segmented)
                    }

                    Section(header: Text("Account")) {
                        if accounts.isEmpty {
                            Text("No accounts available. Create one first.")
                        } else {
                            let defaultAccount = accounts.first!.id
                            Picker("Account", selection: Binding(get: { selectedAccountID ?? defaultAccount }, set: { selectedAccountID = $0 })) {
                                ForEach(accounts) { a in
                                    HStack {
                                        Text(a.name)
                                        Spacer()
                                        Text(a.type.displayName).font(.caption).foregroundColor(.secondary)
                                    }
                                    .tag(a.id)
                                }
                            }
                            .pickerStyle(.menu)
                        }
                    }

                    Section(header: Text("Date")) {
                        DatePicker("When", selection: $date, displayedComponents: [.date, .hourAndMinute])
                    }
                }
            }
            .navigationTitle(isPayback ? "Payback" : (transactionToEdit == nil ? "New Transaction" : "Edit Transaction"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if isPayback {
                            guard let m = Double(amountText), m > 0,
                                  let from = selectedPaymentAccountID,
                                  let to = selectedCreditAccountID else { return }
                            let due = store.dueAmountForCreditAccount(to)
                            let avail = max(0, store.balanceForAccount(from))
                            guard m <= due && m <= avail else { return }
                            store.recordPayback(amount: m, fromCheckingID: from, toCreditID: to, note: note, date: date)
                            dismiss()
                        } else {
                            let categoryToSave = selectedCategoryID ?? store.categories.first?.id
                            let amt = Double(amountText) ?? 0
                            let tx = Transaction(id: transactionToEdit?.id ?? UUID(), amount: amt, purpose: "", note: note, type: type, accountID: selectedAccountID ?? accounts.first?.id, date: date, categoryID: categoryToSave, paybackGroupID: nil)
                            store.add(tx)
                            dismiss()
                        }
                    }
                    .disabled({
                        guard !amountText.trimmingCharacters(in: .whitespaces).isEmpty else { return true }
                        if Double(amountText) ?? 0 <= 0 { return true }
                        return (selectedAccountID == nil)
                    }())
                }
            }
            .onAppear {
                if isPayback {
                    if selectedCreditAccountID == nil { selectedCreditAccountID = store.creditAccounts().first?.id }
                    if selectedPaymentAccountID == nil { selectedPaymentAccountID = store.checkingAccounts().first?.id }
                } else {
                    if selectedCategoryID == nil { selectedCategoryID = transactionToEdit?.categoryID ?? store.categories.first?.id }
                    if selectedAccountID == nil { selectedAccountID = transactionToEdit?.accountID ?? defaultAccountID ?? accounts.first?.id }
                }
            }
        }
    }
}
