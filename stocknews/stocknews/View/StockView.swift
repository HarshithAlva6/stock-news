//
//  StockView.swift
//  stocknews
//
//  Created by Harshith Harijeevan on 1/19/26.
//
import SwiftUI

struct StockView: View {
    @ObservedObject private var vm = StockViewModel()
    @State private var tickerInput: String = ""
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    TextField("Enter Ticker (e.g. AAPL):", text: $tickerInput)
                        .textFieldStyle(.roundedBorder)
                        .autocapitalization(.allCharacters)
                        .disableAutocorrection(true)
                    
                    Button {
                        Task {
                            await vm.syncNews(for: tickerInput)
                        }
                    } label: {
                        if vm.isSyncing {
                            ProgressView()
                        } else {
                            Image(systemName: "arrow.clockwise.circle.fill")
                                .font(.title2)
                        }
                    }
                    .disabled(tickerInput.isEmpty || vm.isSyncing)
                }
                .padding(.horizontal)
                
                List(vm.summaries) { item in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(item.ticker)
                            .font(.headline)
                            .foregroundColor(.blue)
                        Text(item.summary)
                            .font(.body)
                        Text(item.created_at, style: .date)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                .listStyle(.plain)
            }
            .navigationTitle("Stock News AI")
            .onAppear {
                if !tickerInput.isEmpty {
                    vm.subscribeToUpdates(for: tickerInput)
                }
            }
        }
    }
}
