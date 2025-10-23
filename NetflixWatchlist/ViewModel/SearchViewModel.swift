//
//  SearchViewModel.swift
//  NetflixWatchlist
//
//  Created by Kyle Mooney on 1/30/25.
//

import Foundation
import CoreData

class SearchViewModel: ObservableObject {
    @Published var apiCallCount: Int = 0
    @Published var searchResults: [CatalogItem] = []
    @Published var errorMessage: String?
    @Published var selectedAvailability: [CountryAvailability] = []
    @Published var savedItems: [SavedCatalogItem] = []

    private let service = UnogsService()
    private let coreDataManager = CoreDataManager.shared

    init() {
        fetchSavedItems()
        apiCallCount = service.remainingApiCalls()
    }

    func searchCatalog(title: String) {
        DispatchQueue.main.async {
            self.searchResults = []
        }

        service.searchCatalogItems(title: title) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let items):
                    self.searchResults = items
                    self.errorMessage = nil
                case .failure(let error):
                    switch error {
                    case .invalidURL:
                        self.errorMessage = "Invalid URL"
                    case .networkError(let message):
                        self.errorMessage = "Network error: \(message)"
                    case .emptyResults:
                        self.errorMessage = "No results found for \"\(title)\"."
                    case .decodingError(let message):
                        self.errorMessage = "Failed to process data: \(message)"
                    }
//                    self.searchResults = []
                }
            }
        }
        apiCallCount = service.remainingApiCalls()
    }

    func fetchAvailability(for catalogItem: CatalogItem) {
        service.fetchCatalogItemAvailability(itemId: catalogItem.itemId) { [weak self] availability in
            DispatchQueue.main.async {
                self?.selectedAvailability = availability
            }
        }
        apiCallCount = service.remainingApiCalls()
    }

    func saveToWatchlist(item: CatalogItem) {
        print("🌍 Fetching country availability before saving \(item.title)")

        service.fetchCatalogItemAvailability(itemId: item.itemId) { [weak self] availability in
            DispatchQueue.main.async {
                print("✅ Retrieved \(availability.count) country availability records for \(item.title)")
                
                self?.coreDataManager.saveCatalogItem(item: item, availability: availability) // ✅ Save movie + country data
                self?.fetchSavedItems() // ✅ Refresh saved items after saving
            }
        }
    }



    func fetchSavedItems() {
        savedItems = coreDataManager.fetchSavedItems()

//        // ✅ Print to console for debugging
//        print("🎥 Saved Movies in Core Data:")
        for item in savedItems {
            print("🎬 Title: \(item.title ?? "Unknown") | Netflix ID: \(item.itemId ?? "N/A")")
            if let countrySet = item.countryAvailability as? Set<SavedCountryAvailability> {
                for country in countrySet {
                    print("🌍 Available in: \(country.country ?? "Unknown") (\(country.countryCode ?? ""))")
                }
            }
        }
    }
}
