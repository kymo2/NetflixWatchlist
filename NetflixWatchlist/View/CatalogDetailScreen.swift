//
//  CatalogDetailScreen.swift
//  NetflixWatchlist
//
//  Created by Kyle Mooney on 1/31/25.
//

import SwiftUI

struct CatalogDetailScreen: View {
    let catalogItem: CatalogItem
    @EnvironmentObject var viewModel: SearchViewModel

    var body: some View {
        VStack {
            Text("\(viewModel.apiCallCount)")
                .font(.title)
                .fontWeight(.bold)
            
            AsyncImage(url: URL(string: catalogItem.img))
                .frame(width: 150, height: 225)
                .cornerRadius(8)
            
            Text(catalogItem.title)
                .font(.title)
                .fontWeight(.bold)
            
            Text(catalogItem.synopsis)
                .font(.subheadline)
                .padding()

            Button(action: {
                viewModel.saveToWatchlist(item: catalogItem)
            }) {
                Text("Add to Watchlist")
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding()
            
            List(viewModel.selectedAvailability, id: \.countryCode) { country in
                HStack {
                    Text("\(country.country) (\(country.countryCode))")
                    Spacer()
                    Text("🎬 Audio: \(country.audio)")
                }
            }
        }
        .navigationTitle("Movie Details")
        .onAppear {
            viewModel.fetchAvailability(for: catalogItem)
        }
    }
}
