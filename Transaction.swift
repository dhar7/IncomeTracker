// Transaction.swift
import Foundation

enum TransactionType: String, Codable, CaseIterable, Identifiable {
    case expense
    case income

    var id: String { rawValue }
    var displayName: String { self == .income ? "Income" : "Expense" }
}

enum AccountType: String, Codable, CaseIterable, Identifiable {
    case checking
    case credit

    var id: String { rawValue }
    var displayName: String { self == .checking ? "Checking" : "Credit" }
}

struct Account: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String
    var type: AccountType
}

struct BudgetCategory: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String
}

struct BudgetAllocation: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var categoryID: UUID
    var monthKey: String // "YYYY-MM"
    var amount: Double
}

struct Transaction: Identifiable, Codable {
    var id: UUID = UUID()
    var amount: Double
    var purpose: String = ""
    var note: String = ""
    var type: TransactionType
    var accountID: UUID?
    var date: Date
    var categoryID: UUID?
    var paybackGroupID: UUID?

    func csvRow(accountName: String?) -> String {
        let iso = ISO8601DateFormatter().string(from: date)
        func esc(_ s: String) -> String {
            var t = s.replacingOccurrences(of: "\"", with: "\"\"")
            if t.contains(",") || t.contains("\"") || t.contains("\n") {
                t = "\"\(t)\""
            }
            return t
        }
        let acct = accountName ?? ""
        let group = paybackGroupID?.uuidString ?? ""
        let cat = categoryID?.uuidString ?? ""
        return "\(id.uuidString),\(iso),\(type.rawValue),\(amount),\(esc(purpose)),\(esc(note)),\(acct),\(cat),\(group)"
    }
}
