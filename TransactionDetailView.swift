// TransactionDetailView.swift
// Read-only transaction viewer — shows all fields but no editing.
// Safe handling of optional UUIDs and IDs by accepting UUID? in helpers.

import SwiftUI

struct TransactionDetailView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var store: TransactionsStore
    var transaction: Transaction

    // formatters
    private let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .medium // includes hour/min/sec
        return df
    }()

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Amount")) {
                    HStack {
                        Text(transaction.amount, format: .currency(code: Locale.current.currencyCode ?? "USD"))
                            .font(.title2)
                            .bold()
                        Spacer()
                        Text(typeLabel())
                            .foregroundColor(typeColor())
                            .font(.subheadline)
                            .padding(6)
                            .background(Color(UIColor.systemGray6))
                            .cornerRadius(6)
                    }
                }

                Section(header: Text("Account")) {
                    HStack {
                        Text(accountName(for: transaction.accountID) ?? "Unassigned")
                        Spacer()
                        Text(accountTypeDisplay(for: transaction.accountID))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                if let catName = categoryName(for: transaction.categoryID) {
                    Section(header: Text("Category")) {
                        Text(catName)
                    }
                }

                Section(header: Text("Date / Time")) {
                    Text(dateFormatter.string(from: transaction.date))
                }

                Section(header: Text("Note / Purpose")) {
                    if transaction.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(transaction.purpose).foregroundColor(.secondary)
                    } else {
                        Text(transaction.note)
                            .fixedSize(horizontal: false, vertical: true) // allow multi-line
                    }
                }

                // Payback info (only shown when transaction.paybackGroupID exists)
                if let pg = transaction.paybackGroupID {
                    Section(header: Text("Payback info")) {
                        Text("Payback Group ID:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(pg.uuidString)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)

                        // Find related transactions (same payback group) excluding this one
                        // Use the unwrapped pg (UUID) in the comparison
                        let related = store.items.filter { ($0.paybackGroupID == pg) && ($0.id != transaction.id) }

                        if related.isEmpty {
                            Text("No related transactions found in this group.").font(.caption).foregroundColor(.secondary)
                        } else {
                            ForEach(related) { rtx in
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(accountName(for: rtx.accountID) ?? "(Unknown account)")
                                            .font(.subheadline)
                                        Text(dateFormatter.string(from: rtx.date))
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Text(rtx.amount, format: .currency(code: Locale.current.currencyCode ?? "USD"))
                                        .font(.subheadline)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }

                Section(header: Text("Meta")) {
                    HStack {
                        Text("Transaction ID")
                        Spacer()
                        Text(transaction.id.uuidString)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }

                    if let catID = transaction.categoryID {
                        HStack {
                            Text("Category ID")
                            Spacer()
                            Text(catID.uuidString)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                    }
                }
            }
            .navigationTitle("Transaction")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    // MARK: - Local helper functions (accept optional UUID? to avoid caller unwrap issues)

    /// Returns the account name for the given optional account ID, or nil if not found / nil.
    private func accountName(for id: UUID?) -> String? {
        guard let id = id else { return nil }
        return store.accounts.first(where: { $0.id == id })?.name
    }

    /// Returns a short display string for the account type for the given optional account ID.
    private func accountTypeDisplay(for id: UUID?) -> String {
        guard let id = id, let a = store.accounts.first(where: { $0.id == id }) else { return "" }
        return a.type.displayName
    }

    /// Returns the category name for the given optional category ID, or nil if not found / nil.
    private func categoryName(for id: UUID?) -> String? {
        guard let id = id else { return nil }
        return store.categories.first(where: { $0.id == id })?.name
    }

    private func typeLabel() -> String {
        if transaction.paybackGroupID != nil { return "Payback" }
        return transaction.type == .income ? "Income" : "Expense"
    }

    private func typeColor() -> Color {
        if transaction.type == .income { return .green }
        if transaction.paybackGroupID != nil { return .orange }
        return .primary
    }
}
