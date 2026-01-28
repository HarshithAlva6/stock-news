//
//  StockViewModel.swift
//  stocknews
//
//  Created by Harshith Harijeevan on 1/19/26.
//

import SwiftUI
import Supabase
import Combine

@MainActor
class StockViewModel: ObservableObject {
    @Published var summaries: [StockNews] = []
    @Published var isSyncing = false
    
    private let client = supabase
    
    func fetchSummaries(for ticker: String) async {
        do {
            self.summaries = try await client                .from("ticker_news")
                .select()
                .eq("ticker", value: ticker.uppercased())
                .order("created_at", ascending: false)
                .execute()
                .value
        } catch {
            print("Fetch Error: \(error)")
        }
    }
    
    // 2. Real-time subscription for RealtimeV2
    func subscribeToUpdates(for ticker: String) {
            // 1. Create the channel using realtimeV2 as requested
            let channel = client.realtimeV2.channel("news-updates-\(ticker)")
            
            _ = channel.onPostgresChange(
                InsertAction.self, // We listen specifically for inserts
                schema: "public",
                table: "ticker_news",
                filter: "ticker=eq.\(ticker.uppercased())"
            ) { @MainActor action in
                // Handle the action directly
                do {
                    let newNews = try action.decodeRecord(as: StockNews.self, decoder: JSONDecoder())
                    
                    if !self.summaries.contains(where: { $0.id == newNews.id }) {
                        self.summaries.insert(newNews, at: 0)
                    }
                } catch {
                    print("Realtime Decoding Error: \(error)")
                }
            }
            
            // 3. Final Step: Subscribe
            Task {
                await channel.subscribe()
            }
        }
    
    func syncNews(for ticker: String) async {
        isSyncing = true
        defer {isSyncing = false }
        do {
            try await client.functions.invoke(
                "stock_sync_news",
                options: FunctionInvokeOptions(body: ["ticker":ticker.uppercased()])
            )
            await fetchSummaries(for: ticker)
        } catch {
            print("Sync Error: \(error)")
        }
    }
}




