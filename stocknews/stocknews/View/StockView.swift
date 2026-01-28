//
//  StockView.swift
//  stocknews
//
//  Created by Harshith Harijeevan on 1/19/26.
//
import SwiftUI

struct StockView: View {
    @StateObject private var vm = StockViewModel() // Using @StateObject is better for the owner of the VM
    @State private var tickerInput: String = ""
    
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 10) {
                // Input area
                TextField("Enter Ticker (e.g. AAPL):", text: $tickerInput)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.characters)
                    .submitLabel(.search)
                    .padding(.horizontal)
                    .onSubmit {
                        performSearch()
                    }
                
                // The Output Rendering Section
                List(vm.summaries) { news in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(news.ticker)
                                .font(.headline)
                                .foregroundColor(.blue)
                            
                            Spacer()
                            
                            if let price = news.price {
                                Text("$\(String(format: "%.2f", price))")
                                    .font(.headline)
                                
                                if let change = news.price_change, let percent = news.percent_change {
                                    let color: Color = change >= 0 ? .green : .red
                                    let sign = change >= 0 ? "+" : ""
                                    Text("\(sign)\(String(format: "%.2f", change)) (\(String(format: "%.2f", percent))%)")
                                        .font(.subheadline)
                                        .foregroundColor(color)
                                }
                            }
                        }
                        
                        Text(news.summary)
                            .font(.body)
                        
                        Text(news.created_at, style: .date)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                .listStyle(.plain)
                .overlay {
                    if vm.isSyncing {
                        ProgressView("Fetching latest news...")
                    } else if vm.summaries.isEmpty {
                        ContentUnavailableView("No News", systemImage: "newspaper", description: Text("Enter a ticker to see results."))
                    }
                }
            }
            .navigationTitle("Stock News")
        }
    }
    
    // Trigger the sequence of events
    private func performSearch() {
        guard !tickerInput.isEmpty else { return }
        
        Task {
            // 1. Get whatever is already in the database
            await vm.fetchSummaries(for: tickerInput)
            // 2. Start listening for live inserts
            vm.subscribeToUpdates(for: tickerInput)
            // 3. Tell the backend to go find new news
            await vm.syncNews(for: tickerInput)
        }
    }
}
