//
//  AddCategoryView.swift
//  IncomeTracker
//
//  Created by Argha Dhar on 1/2/26.
//


// AddCategoryView.swift
import SwiftUI

struct AddCategoryView: View {
    @Environment(\.dismiss) var dismiss
    @State private var name = ""
    @State private var amountText = ""
    @State private var monthDate = Date()

    // onCreate: (name, amount, monthDate)
    var onCreate: (String, Double, Date) -> Void

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Category name")) {
                    TextField("e.g. Household", text: $name)
                }
                Section(header: Text("Budget amount for month")) {
                    TextField("Amount", text: $amountText).keyboardType(.decimalPad)
                    DatePicker("Month", selection: $monthDate, displayedComponents: .date)
                        .labelsHidden()
                }
            }
            .navigationTitle("New Category & Budget")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        let amt = Double(amountText) ?? 0
                        onCreate(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Category" : name, amt, monthDate)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
