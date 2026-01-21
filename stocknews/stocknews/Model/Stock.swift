//
//  Stock.swift
//  stocknews
//
//  Created by Harshith Harijeevan on 1/19/26.
//
import Foundation

struct StockNews: Identifiable, Codable {
    var id: Int
    let ticker: String
    let summary: String
    let created_at: Date
}
