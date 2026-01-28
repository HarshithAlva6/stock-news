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
            self.summaries = try await client.database
                .from("ticker_news")
                .select()
                .eq("ticker", value: ticker)
                .order("created_at", ascending: false)
                .execute()
                .value
        } catch {
            print("Fetch Error \(error)")
        }
    }
    
    //2. Real-time subscription
    func subscribeToUpdates(for ticker: String) {
            let channel = client.realtime.channel("news-updates-\(ticker)")
            
            channel.onPostgresChange(
                AnyAction.self,
                schema: "public",
                table: "ticker_news",
                filter: "ticker=eq.\(ticker.uppercased())"
            ) { [weak self] (action: AnyAction) in
                switch action {
                case .insert(let insertAction):
                    do {
                        let newNews = try insertAction.decodeRecord(as: StockNews.self, decoder: JSONDecoder())
                        
                        DispatchQueue.main.async {
                            guard let self = self else { return }
                            if !self.summaries.contains(where: { $0.id == newNews.id }) {
                                self.summaries.insert(newNews, at: 0)
                            }
                        }
                    } catch {
                        print("Realtime Decoding Error: \(error)")
                    }
                default:
                    break
                }
            }
            
            // Final Step: Actually connect to the server
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
                options: FunctionInvokeOptions(body: ["ticker": ticker.uppercased()])
            )
            await fetchSummaries(for: ticker)
        } catch {
            print("Sync Error: \(error)")
        }
    }
}




