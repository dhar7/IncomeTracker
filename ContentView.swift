// ContentView.swift
// Full file — unchanged behavior except: small PDF column-width adjustment to avoid Date/Time vs Account overlap.

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

    // PDF UI
    @State private var showPDFSheet: Bool = false
    @State private var pdfStart: Date = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    @State private var pdfEnd: Date = Date()
    @State private var isGeneratingPDF: Bool = false

    // Keep names hidden under "All" as you requested earlier
    private let hiddenDefaultNames: Set<String> = ["Main Checking", "Main Credit"]

    // Date/time formatter for display (unchanged behaviour)
    private let dateTimeFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .medium // includes seconds in most locales
        return df
    }()

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                accountPickerBar
                Divider()
                summaryHeader
                Divider()
                transactionList
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

                        // Generate PDF button
                        Button(action: { showPDFSheet = true }) {
                            Image(systemName: "doc.richtext")
                        }
                    }
                }
            }

            // Existing sheets (unchanged)
            .sheet(isPresented: $showAddTx) {
                AddEditTransactionView(store: store, accounts: store.accounts, transactionToEdit: nil, defaultAccountID: selectedAccountID)
            }
            .sheet(isPresented: $showAddAccount) {
                AddAccountView(onCreate: { name, type in
                    let a = store.addAccount(name: name, type: type)
                    selectedAccountID = a.id
                    showAddAccount = false
                })
            }
            .sheet(isPresented: $showManageAccounts) {
                ManageAccountsView(store: store, isPresented: $showManageAccounts, selectedAccountID: $selectedAccountID)
            }
            .sheet(isPresented: $showAddCategory) {
                AddCategoryView(onCreate: { name, amount, monthDate in
                    let cat = store.addCategory(name: name)
                    let key = store.monthKeyFor(date: monthDate)
                    if amount > 0 { store.setBudget(for: cat.id, monthKey: key, amount: amount) }
                    showAddCategory = false
                })
            }
            .sheet(isPresented: $showBudget) {
                BudgetView(store: store)
            }

            // PDF date-range sheet
            .sheet(isPresented: $showPDFSheet) {
                NavigationView {
                    Form {
                        Section(header: Text("Choose date/time range for the report")) {
                            DatePicker("Start", selection: $pdfStart, displayedComponents: [.date, .hourAndMinute])
                            DatePicker("End", selection: $pdfEnd, displayedComponents: [.date, .hourAndMinute])
                        }

                        Section {
                            Button(action: generatePDFButtonTapped) {
                                HStack {
                                    if isGeneratingPDF { ProgressView().scaleEffect(0.9) }
                                    Text("Generate PDF")
                                }
                            }
                            .disabled(isGeneratingPDF)
                        }

                        Section(footer: Text("The PDF will be saved to the app's Documents folder. A share sheet will open so you can Save to Files on your iPhone.")) {
                            EmptyView()
                        }
                    }
                    .navigationTitle("Export PDF")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) { Button("Cancel") { showPDFSheet = false } }
                    }
                }
            }

            .onAppear {
                if selectedAccountID == nil, let first = visibleAccounts().first {
                    selectedAccountID = first.id
                }
            }
        }
    }

    // MARK: - UI pieces (unchanged behaviour, only organized here)

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
                                Text(store.balanceForAccount(acct.id), format: .currency(code: Locale.current.currencyCode ?? "USD"))
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
                Text(store.totalForAccountType(.checking), format: .currency(code: Locale.current.currencyCode ?? "USD"))
                    .font(.title2).bold()
            }
            Spacer()
            VStack(alignment: .trailing) {
                Text("Owe Balance").font(.caption)
                Text(store.totalOweBalance(), format: .currency(code: Locale.current.currencyCode ?? "USD"))
                    .foregroundColor(.red)
            }
        }
        .padding()
    }

    private var transactionList: some View {
        List {
            ForEach(displayedTransactions) { t in
                Button(action: { editingTx = t }) {
                    VStack(alignment: .leading) {
                        HStack {
                            Text(store.categoryName(for: t.categoryID) ?? t.purpose).font(.headline)
                            Spacer()
                            Text(t.type == .income ? "+" : "-")
                                .foregroundColor(t.type == .income ? .green : .red)
                            Text(t.amount, format: .currency(code: Locale.current.currencyCode ?? "USD")).bold()
                        }

                        HStack {
                            if t.paybackGroupID != nil {
                                Text("Payback").font(.caption).padding(4).background(Color.yellow.opacity(0.2)).cornerRadius(6)
                            } else {
                                Text(t.note).font(.subheadline).foregroundColor(.secondary).lineLimit(2)
                            }
                            Spacer()
                            Text(dateTimeFormatter.string(from: t.date)).font(.caption).foregroundColor(.gray)
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

    // MARK: - PDF: actions & generation (minimal and self-contained)

    private func generatePDFButtonTapped() {
        // validate date range then generate
        if pdfStart > pdfEnd {
            // swap so start <= end
            let tmp = pdfStart; pdfStart = pdfEnd; pdfEnd = tmp
        }

        isGeneratingPDF = true

        DispatchQueue.global(qos: .userInitiated).async {
            let (data, url) = createAndSavePDF(start: pdfStart, end: pdfEnd, store: store)
            DispatchQueue.main.async {
                isGeneratingPDF = false
                if let url = url {
                    // present share sheet so user can Save to Files
                    presentShareSheet(url: url)
                } else {
                    // generation failed — print for now (do not alter other behavior)
                    print("PDF generation failed")
                }
                showPDFSheet = false
            }
        }
    }

    /// Creates PDF Data and saves it to the app Documents folder. Returns (Data?, URL?)
    /// This function is intentionally conservative: it only *reads* from store items and accounts.
    private func createAndSavePDF(start: Date, end: Date, store: TransactionsStore) -> (Data?, URL?) {
        // Collect transactions in the requested inclusive range, sorted ascending
        let txsAll = store.items.filter { $0.date >= start && $0.date <= end }.sorted { $0.date < $1.date }

        // Compute running balances: startBalance = balance up to start (inclusive)
        let startBalance = balanceUpTo(date: start, store: store)
        let endBalance = balanceUpTo(date: end, store: store)

        // ---------- Wider page geometry ----------
        let pageWidth: CGFloat = 1000    // wider page
        let pageHeight: CGFloat = 792
        let margin: CGFloat = 40
        let contentWidth = pageWidth - margin * 2
        // --------------------------------------------------

        // Formatters
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .medium

        let currencyFormatter = NumberFormatter()
        currencyFormatter.numberStyle = .currency
        currencyFormatter.currencyCode = Locale.current.currencyCode ?? "USD"

        // Fonts
        let headerFont = UIFont.boldSystemFont(ofSize: 16)
        let bodyFont = UIFont.systemFont(ofSize: 12)
        let monoFont = UIFont.monospacedSystemFont(ofSize: 11, weight: .regular)

        let meta = ["Creator": "IncomeTracker", "Author": "IncomeTracker App"]
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = meta as [String: Any]

        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight), format: format)

        let pdfData = renderer.pdfData { ctx in
            var y = margin

            func startPage() {
                ctx.beginPage()
                y = margin
            }

            func drawText(_ text: String, font: UIFont, x: CGFloat, width: CGFloat, align: NSTextAlignment = .left) -> CGFloat {
                let para = NSMutableParagraphStyle()
                para.alignment = align
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .paragraphStyle: para
                ]
                let rect = CGRect(x: x, y: y, width: width, height: CGFloat.greatestFiniteMagnitude)
                let bounds = NSString(string: text).boundingRect(with: CGSize(width: width, height: CGFloat.greatestFiniteMagnitude),
                                                                 options: [.usesLineFragmentOrigin, .usesFontLeading],
                                                                 attributes: attrs, context: nil)
                NSString(string: text).draw(with: rect, options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: attrs, context: nil)
                return ceil(bounds.height)
            }

            startPage()

            // Header block
            y += drawText("IncomeTracker Report", font: headerFont, x: margin, width: contentWidth) + 8
            let rangeLine = "From: \(dateFormatter.string(from: start))    To: \(dateFormatter.string(from: end))"
            y += drawText(rangeLine, font: bodyFont, x: margin, width: contentWidth) + 6

            let sbStr = currencyFormatter.string(from: NSNumber(value: startBalance)) ?? String(format: "%.2f", startBalance)
            y += drawText("Start date main balance: \(sbStr)", font: bodyFont, x: margin, width: contentWidth) + 4

            let ebStr = currencyFormatter.string(from: NSNumber(value: endBalance)) ?? String(format: "%.2f", endBalance)
            y += drawText("End date main balance: \(ebStr)", font: bodyFont, x: margin, width: contentWidth) + 10

            // Column widths — adjusted to avoid overlap
            let colDate: CGFloat = 180   // increased so timestamp has more room
            let colAccount: CGFloat = 120 // slightly reduced but starts further right overall
            let colType: CGFloat = 60
            let colAmount: CGFloat = 80
            let colCategory: CGFloat = 120

            // Reserve a dedicated running-balance column so notes can wrap safely.
            let colRunning: CGFloat = 120 // space reserved at far-right for running balance

            // Now compute note width by removing running column too.
            let colNote: CGFloat = contentWidth - (colDate + colAccount + colType + colAmount + colCategory + colRunning)

            // Draw header row
            if y + 20 > pageHeight - margin { startPage() }
            let headerAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 12)]
            var x = margin
            NSString(string: "Date/Time").draw(at: CGPoint(x: x, y: y), withAttributes: headerAttrs)
            x += colDate
            NSString(string: "Account").draw(at: CGPoint(x: x, y: y), withAttributes: headerAttrs)
            x += colAccount
            NSString(string: "Type").draw(at: CGPoint(x: x, y: y), withAttributes: headerAttrs)
            x += colType
            NSString(string: "Amount").draw(at: CGPoint(x: x, y: y), withAttributes: headerAttrs)
            x += colAmount
            NSString(string: "Category").draw(at: CGPoint(x: x, y: y), withAttributes: headerAttrs)
            x += colCategory
            NSString(string: "Note").draw(at: CGPoint(x: x, y: y), withAttributes: headerAttrs)
            // running header (right-most)
            NSString(string: "Balance").draw(at: CGPoint(x: margin + contentWidth - colRunning + 6, y: y), withAttributes: headerAttrs)
            y += 20

            // Running balance starts at startBalance
            var running = startBalance

            // Iterate transactions, but skip credit-side payback rows
            for tx in txsAll {
                // Lookup account
                let accountObj = store.accounts.first { $0.id == tx.accountID }
                let accountIsCredit = accountObj?.type == .credit
                let accountIsChecking = accountObj?.type == .checking

                let isPayback = tx.paybackGroupID != nil

                // If this tx is part of a payback and is the credit-side, skip it
                if isPayback && accountIsCredit {
                    continue // do not include credit receiving side of payback
                }

                // Build display fields
                let dt = dateFormatter.string(from: tx.date)
                let accountName = store.accountName(for: tx.accountID) ?? ""
                // Label payback rows explicitly when they're on checking side
                let typeStr: String
                if isPayback && accountIsChecking {
                    typeStr = "Payback"
                } else {
                    typeStr = tx.type == .income ? "Income" : "Expense"
                }
                let amountStr = currencyFormatter.string(from: NSNumber(value: tx.amount)) ?? String(format: "%.2f", tx.amount)
                let categoryName = store.categoryName(for: tx.categoryID) ?? ""
                let note = tx.note.isEmpty ? tx.purpose : tx.note

                // compute note height with wrapping (using reserved colNote width)
                let noteAttrs: [NSAttributedString.Key: Any] = [.font: bodyFont]
                let noteRect = NSString(string: note).boundingRect(with: CGSize(width: max(40, colNote), height: CGFloat.greatestFiniteMagnitude),
                                                                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                                                                    attributes: noteAttrs, context: nil)
                let rowHeight: CGFloat = max(18, noteRect.height)

                // paginate if needed
                if y + rowHeight + 30 > pageHeight - margin {
                    startPage()
                }

                // draw columns
                var txX = margin
                NSString(string: dt).draw(at: CGPoint(x: txX, y: y), withAttributes: [.font: monoFont])
                txX += colDate

                NSString(string: accountName).draw(at: CGPoint(x: txX, y: y), withAttributes: [.font: bodyFont])
                txX += colAccount

                NSString(string: typeStr).draw(at: CGPoint(x: txX, y: y), withAttributes: [.font: bodyFont])
                txX += colType

                // amount right-aligned
                let amtSize = NSString(string: amountStr).size(withAttributes: [.font: bodyFont])
                NSString(string: amountStr).draw(at: CGPoint(x: txX + colAmount - amtSize.width, y: y), withAttributes: [.font: bodyFont])
                txX += colAmount

                NSString(string: categoryName).draw(at: CGPoint(x: txX, y: y), withAttributes: [.font: bodyFont])
                txX += colCategory

                // draw wrapped note within reserved note column
                let noteDrawRect = CGRect(x: txX, y: y, width: max(40, colNote), height: rowHeight)
                NSString(string: note).draw(with: noteDrawRect, options: .usesLineFragmentOrigin, attributes: noteAttrs, context: nil)

                // Update running according to rules:
                // - income => running += amount
                // - expense:
                //    * if part of payback and this is checking side => running -= amount (we included it)
                //    * else if charged to credit (and not a checking-payback) => running unchanged
                //    * else (expense on checking or other non-credit) => running -= amount
                if tx.type == .income {
                    running += tx.amount
                } else {
                    if isPayback && accountIsChecking {
                        running -= tx.amount
                    } else if accountIsCredit {
                        // do nothing for credit-charge
                    } else {
                        running -= tx.amount
                    }
                }

                // draw running balance into the reserved running column (right-most)
                let runningStr = currencyFormatter.string(from: NSNumber(value: running)) ?? String(format: "%.2f", running)
                let runSize = NSString(string: runningStr).size(withAttributes: [.font: bodyFont])
                // place it inside the running column with some right padding
                let runX = margin + contentWidth - runSize.width - 8
                // vertically align to top of row
                NSString(string: runningStr).draw(at: CGPoint(x: runX, y: y), withAttributes: [.font: bodyFont])

                // advance y
                y += rowHeight + 6
            }

            // Footer
            if y + 40 > pageHeight - margin {
                startPage()
            }
            y += 8
            let gen = "Generated: \(Date().description(with: Locale.current))"
            _ = drawSimpleText(gen, font: bodyFont, x: margin, width: contentWidth, context: ctx.cgContext)
        }

        // write file to Documents and return url
        let fm = FileManager.default
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first!
        let filename = "IncomeTracker_Report_\(isoSafeString(from: start))_to_\(isoSafeString(from: end)).pdf"
        let fileURL = docs.appendingPathComponent(filename)

        do {
            try pdfData.write(to: fileURL, options: .atomic)
            return (pdfData, fileURL)
        } catch {
            print("Failed to write PDF:", error)
            return (pdfData, nil)
        }
    }

    // Helper: draw a simple single-line text and return its height
    private func drawSimpleText(_ text: String, font: UIFont, x: CGFloat, width: CGFloat, context: CGContext) -> CGFloat {
        let para = NSMutableParagraphStyle()
        para.alignment = .left
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .paragraphStyle: para]
        let rect = CGRect(x: x, y: 0, width: width, height: CGFloat.greatestFiniteMagnitude)
        let bound = NSString(string: text).boundingRect(with: CGSize(width: width, height: CGFloat.greatestFiniteMagnitude), options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: attrs, context: nil)
        NSString(string: text).draw(with: rect, options: .usesLineFragmentOrigin, attributes: attrs, context: nil)
        return ceil(bound.height)
    }

    // balance up-to-and-including the given date
    private func balanceUpTo(date: Date, store: TransactionsStore) -> Double {
        let filtered = store.items.filter { $0.date <= date }
        return filtered.reduce(0.0) { acc, t in
            acc + (t.type == .income ? t.amount : -t.amount)
        }
    }

    private func isoSafeString(from date: Date) -> String {
        let df = DateFormatter()
        df.dateFormat = "yyyyMMdd_HHmmss"
        return df.string(from: date)
    }

    // Present a share sheet for the generated PDF URL so the user can Save to Files on your iPhone
    private func presentShareSheet(url: URL) {
        DispatchQueue.main.async {
            if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let root = scene.windows.first?.rootViewController {
                let av = UIActivityViewController(activityItems: [url], applicationActivities: nil)
                root.present(av, animated: true, completion: nil)
            } else {
                print("Unable to present share sheet")
            }
        }
    }
}
