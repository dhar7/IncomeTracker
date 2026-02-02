//
//  ManageAccountsView.swift
//  IncomeTracker
//
//  Created by Argha Dhar on 1/2/26.
//


// ManageAccountsView.swift
import SwiftUI

struct ManageAccountsView: View {
    @ObservedObject var store: TransactionsStore
    @Binding var isPresented: Bool
    @Binding var selectedAccountID: UUID?

    var body: some View {
        NavigationView {
            List {
                ForEach(store.accounts) { acct in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(acct.name)
                            Text(acct.type.displayName).font(.caption).foregroundColor(.secondary)
                        }
                        Spacer()
                        Button("Select") { selectedAccountID = acct.id }
                    }
                }
                .onDelete(perform: delete)
            }
            .navigationTitle("Accounts")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { isPresented = false } } }
        }
    }

    private func delete(at offsets: IndexSet) {
        let ids = offsets.compactMap { store.accounts.indices.contains($0) ? store.accounts[$0].id : nil }
        for id in ids { store.deleteAccount(id: id) }
        if let sel = selectedAccountID, !store.accounts.contains(where: { $0.id == sel }) {
            selectedAccountID = store.accounts.first?.id
        }
    }
}
