//
//  EditAllocationView.swift
//  IncomeTracker
//
//  Created by Argha Dhar on 1/2/26.
//


// EditAllocationView.swift
import SwiftUI

struct EditAllocationView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var store: TransactionsStore
    var category: BudgetCategory
    var monthDate: Date

    @State private var amountText: String = ""

    init(store: TransactionsStore, category: BudgetCategory, monthDate: Date) {
        self.store = store
        self.category = category
        self.monthDate = monthDate
        let key = store.monthKeyFor(date: monthDate)
        if let val = store.budgetFor(categoryID: category.id, monthKey: key) {
            _amountText = State(initialValue: String(format: "%.2f", val))
        } else {
            _amountText = State(initialValue: "")
        }
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Budget for \(category.name) — \(store.monthKeyFor(date: monthDate))")) {
                    TextField("Amount", text: $amountText)
                        .keyboardType(.decimalPad)
                }

                Section {
                    Button(role: .destructive) {
                        // delete allocation for this month (if exists)
                        if let alloc = store.allocations.first(where: { $0.categoryID == category.id && $0.monthKey == store.monthKeyFor(date: monthDate) }) {
                            store.deleteAllocation(id: alloc.id)
                        }
                        dismiss()
                    } label: {
                        Text("Remove allocation for this month")
                    }
                }
            }
            .navigationTitle("Set Budget")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let amt = Double(amountText) ?? 0
                        store.setBudget(for: category.id, monthKey: store.monthKeyFor(date: monthDate), amount: amt)
                        dismiss()
                    }.disabled(amountText.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
