// AddAccountView.swift
import SwiftUI

struct AddAccountView: View {
    @Environment(\.dismiss) var dismiss
    @State private var name = ""
    @State private var type: AccountType = .checking
    var onCreate: (String, AccountType) -> Void

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Account name")) { TextField("e.g. My Checking", text: $name) }
                Section {
                    Picker("Type", selection: $type) {
                        ForEach(AccountType.allCases) { t in Text(t.displayName).tag(t) }
                    }.pickerStyle(.segmented)
                }
            }
            .navigationTitle("New Account")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        onCreate(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Account" : name, type)
                    }
                }
            }
        }
    }
}
