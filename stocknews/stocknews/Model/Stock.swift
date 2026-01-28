//
//  Stock.swift
//  stocknews
//
//  Created by Harshith Harijeevan on 1/19/26.
//
import Foundation

struct StockNews: Identifiable, Codable {
    var id: String
    let ticker: String
    let summary: String
    let price: Double?
    let price_change: Double?
    let percent_change: Double?
    let created_at: Date
}
