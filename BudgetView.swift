// BudgetView.swift
// Complete file — Budget page now displays month names (e.g. "February 2026") instead of a specific date

import SwiftUI

struct BudgetView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var store: TransactionsStore

    @State private var selectedMonth = Date()
    @State private var showAddCategory = false
    @State private var editingCategory: BudgetCategory? = nil
    @State private var showConfirmDeleteCategory: Bool = false
    @State private var categoryToDelete: BudgetCategory? = nil

    init(store: TransactionsStore) {
        self.store = store
        _selectedMonth = State(initialValue: Date())
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 12) {
                header
                if store.categories.isEmpty {
                    emptyState
                } else {
                    listView
                }
            }
            .navigationTitle("Budget")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
            }
            .sheet(isPresented: $showAddCategory) {
                AddCategoryView { name, amount, monthDate in
                    let cat = store.addCategory(name: name)
                    let key = store.monthKeyFor(date: monthDate)
                    if amount > 0 { store.setBudget(for: cat.id, monthKey: key, amount: amount) }
                    showAddCategory = false
                }
            }
            .sheet(item: $editingCategory) { cat in
                EditCategoryView(store: store, category: cat, initialMonth: selectedMonth) { _ in
                    editingCategory = nil
                }
            }
            .alert("Delete category?", isPresented: $showConfirmDeleteCategory, presenting: categoryToDelete) { cat in
                Button("Delete", role: .destructive) {
                    store.deleteCategory(id: cat.id)
                    categoryToDelete = nil
                }
                Button("Cancel", role: .cancel) {
                    categoryToDelete = nil
                }
            } message: { _ in
                Text("Deleting the category will remove its budgets and clear the category on existing transactions.")
            }
            .padding(.horizontal, 8)
        }
    }

    // MARK: - Header
    private var header: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("Budgets").font(.title2).bold()
                Text(monthDisplay(for: selectedMonth)) // show "February 2026"
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Keep a DatePicker for selecting month; show it compactly
            DatePicker("", selection: $selectedMonth, displayedComponents: .date)
                .labelsHidden()
                .frame(maxWidth: 140)

            Button(action: { showAddCategory = true }) {
                Image(systemName: "plus")
                    .imageScale(.large)
                    .padding(8)
            }
            .buttonStyle(.bordered)
        }
        .padding(.top, 8)
    }

    // MARK: - Empty state
    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Text("No categories yet")
                .font(.headline)
            Text("Tap + to add a category and set a monthly budget. Budgets show spent and remaining for the selected month.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            Spacer()
        }
    }

    // MARK: - List view (cards)
    private var listView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(store.categories) { cat in
                    CategoryCardView(store: store, category: cat, monthDate: selectedMonth, onEdit: {
                        editingCategory = cat
                    }, onDelete: {
                        categoryToDelete = cat
                        showConfirmDeleteCategory = true
                    })
                }
                .padding(.vertical, 6)
            }
        }
    }

    // MARK: - Helpers
    private func monthDisplay(for date: Date) -> String {
        let df = DateFormatter()
        df.dateFormat = "LLLL yyyy" // full month name + year, e.g., "February 2026"
        return df.string(from: date)
    }
}


/// A single, tidy card row for a category's budget + spent + remaining
private struct CategoryCardView: View {
    @ObservedObject var store: TransactionsStore
    var category: BudgetCategory
    var monthDate: Date
    var onEdit: () -> Void
    var onDelete: () -> Void

    private var monthKey: String { store.monthKeyFor(date: monthDate) }
    private var monthLabel: String {
        let df = DateFormatter()
        df.dateFormat = "LLLL yyyy"
        return df.string(from: monthDate)
    }

    var body: some View {
        let budgetOpt = store.budgetFor(categoryID: category.id, monthKey: monthKey)
        let spent = store.spentForCategoryMonth(categoryID: category.id, monthKey: monthKey)
        let remainingOpt = budgetOpt.map { $0 - spent }

        return HStack(spacing: 12) {
            // Left: category name & month
            VStack(alignment: .leading, spacing: 6) {
                Text(category.name)
                    .font(.headline)
                Text(monthLabel)
                    .font(.caption)
                    .foregroundColor(.secondary)
                if let budget = budgetOpt {
                    // small progress bar
                    ProgressView(value: progressFraction(budget: budget, spent: spent))
                        .progressViewStyle(LinearProgressViewStyle(tint: progressColor(budget: budget, spent: spent)))
                        .frame(height: 6)
                        .cornerRadius(3)
                } else {
                    Text("No budget set for this month")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Right: Remaining large, then Budget & Spent small
            VStack(alignment: .trailing, spacing: 6) {
                if let rem = remainingOpt {
                    Text(rem, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
                        .font(.title3).bold()
                        .foregroundColor(rem < 0 ? .red : .green) // positive -> green, negative -> red
                } else {
                    Text("—")
                        .font(.title3).bold()
                        .foregroundColor(.secondary)
                }

                HStack(spacing: 12) {
                    if let b = budgetOpt {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Budget").font(.caption).foregroundColor(.secondary)
                            Text(b, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
                                .font(.subheadline)
                        }
                    }

                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Spent").font(.caption).foregroundColor(.secondary)
                        Text(spent, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
                            .font(.subheadline)
                    }
                }
            }

            // Edit / Delete buttons
            VStack {
                Button(action: onEdit) { Image(systemName: "pencil") }
                Button(role: .destructive, action: onDelete) { Image(systemName: "trash") }
            }
            .buttonStyle(.borderless)
            .frame(width: 44)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(UIColor.systemBackground)).shadow(color: Color.black.opacity(0.03), radius: 3, x: 0, y: 2))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(UIColor.separator).opacity(0.6), lineWidth: 0.3))
        .padding(.horizontal, 2)
    }

    private func progressFraction(budget: Double, spent: Double) -> Double {
        guard budget > 0 else { return 0.0 }
        return min(max(spent / budget, 0.0), 1.0)
    }

    private func progressColor(budget: Double, spent: Double) -> Color {
        let frac = progressFraction(budget: budget, spent: spent)
        if frac >= 1.0 { return .red }
        if frac > 0.6 { return .orange }
        return .accentColor
    }
}


/// EditCategoryView unchanged (keeps full functionality).
struct EditCategoryView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var store: TransactionsStore
    var category: BudgetCategory
    @State private var name: String
    @State private var amountText: String
    @State private var monthDate: Date
    @State private var showConfirmDelete: Bool = false

    var onComplete: ((Void) -> Void)?

    init(store: TransactionsStore, category: BudgetCategory, initialMonth: Date, onComplete: ((Void) -> Void)? = nil) {
        self.store = store
        self.category = category
        _name = State(initialValue: category.name)
        _monthDate = State(initialValue: initialMonth)
        let key = store.monthKeyFor(date: initialMonth)
        if let amt = store.budgetFor(categoryID: category.id, monthKey: key) {
            _amountText = State(initialValue: String(format: "%.2f", amt))
        } else {
            _amountText = State(initialValue: "")
        }
        self.onComplete = onComplete
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Category")) {
                    TextField("Name", text: $name)
                }

                Section(header: Text("Budget for month")) {
                    TextField("Amount", text: $amountText).keyboardType(.decimalPad)
                    DatePicker("Month", selection: $monthDate, displayedComponents: .date).labelsHidden()
                }

                Section {
                    Button(role: .destructive) {
                        showConfirmDelete = true
                    } label: {
                        Text("Delete Category")
                    }
                }
            }
            .navigationTitle("Edit Category")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        let newName = trimmed.isEmpty ? category.name : trimmed
                        let updated = BudgetCategory(id: category.id, name: newName)
                        store.updateCategory(updated)

                        let key = store.monthKeyFor(date: monthDate)
                        let amt = Double(amountText) ?? 0
                        store.setBudget(for: category.id, monthKey: key, amount: amt)

                        dismiss()
                        onComplete?(())
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .confirmationDialog("Are you sure?", isPresented: $showConfirmDelete, titleVisibility: .visible) {
                Button("Delete Category", role: .destructive) {
                    store.deleteCategory(id: category.id)
                    showConfirmDelete = false
                    dismiss()
                }
                Button("Cancel", role: .cancel) { showConfirmDelete = false }
            } message: {
                Text("Deleting the category will remove its budget allocations and clear the category on existing transactions.")
            }
        }
    }
}
