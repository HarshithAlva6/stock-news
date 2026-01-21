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
            VStack (alignment: .leading, spacing: 10) {
                VStack(spacing: 10) {
                    TextField("Enter Ticker:", text: $tickerInput)
                        .textFieldStyle(.roundedBorder)
                        .submitLabel(.search)
                }
            }
        }
    }
}
