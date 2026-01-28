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
                        // Using available fields from StockNews
                        Text(news.ticker)
                            .font(.headline)
                        
                        Text(news.summary)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(3)
                        
                        Text(news.created_at, style: .date)
                            .font(.caption)
                            .foregroundColor(.blue)
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
