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
    @Published var watchlistMessage: String?
    @Published private(set) var pendingWatchlistItemIDs: Set<String> = []

    private let service = UnogsService()
    private let coreDataManager = CoreDataManager.shared

    var apiLimit: Int {
        service.maxApiCallsPerDay
    }

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
                    case .missingCredentials:
                        self.errorMessage = "Missing API credentials. Check API_KEY and API_HOST."
                    case .networkError(let message):
                        self.errorMessage = "Network error: \(message)"
                    case .emptyResults:
                        self.errorMessage = "No results found for \"\(title)\"."
                    case .decodingError(let message):
                        self.errorMessage = "Failed to process data: \(message)"
                    }
//                    self.searchResults = []
                }
                self.apiCallCount = self.service.remainingApiCalls()
            }
        }
        DispatchQueue.main.async {
            self.apiCallCount = self.service.remainingApiCalls()
        }
    }

    func fetchAvailability(for catalogItem: CatalogItem) {
        service.fetchCatalogItemAvailability(itemId: catalogItem.itemId) { [weak self] availability in
            DispatchQueue.main.async {
                self?.selectedAvailability = availability
                self?.apiCallCount = self?.service.remainingApiCalls() ?? 0
            }
        }
        DispatchQueue.main.async {
            self.apiCallCount = self.service.remainingApiCalls()
        }
    }

    func saveToWatchlist(item: CatalogItem) {
        print("🌍 Fetching country availability before saving \(item.title)")

        guard !isItemSaved(item) else {
            watchlistMessage = "Already on watchlist"
            return
        }

        pendingWatchlistItemIDs.insert(item.itemId)

        service.fetchCatalogItemAvailability(itemId: item.itemId) { [weak self] availability in
            DispatchQueue.main.async {
                print("✅ Retrieved \(availability.count) country availability records for \(item.title)")

                self?.coreDataManager.saveCatalogItem(item: item, availability: availability) // ✅ Save movie + country data
                self?.fetchSavedItems() // ✅ Refresh saved items after saving
                self?.pendingWatchlistItemIDs.remove(item.itemId)
                self?.watchlistMessage = "Added to watchlist"
            }
        }
    }



    func fetchSavedItems() {
        savedItems = coreDataManager.fetchSavedItems()
        let savedIDs = Set(savedItems.compactMap { $0.itemId })
        pendingWatchlistItemIDs.subtract(savedIDs)

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

    func removeFromWatchlist(item: CatalogItem) {
        coreDataManager.deleteSavedItem(itemId: item.itemId)
        fetchSavedItems()
        pendingWatchlistItemIDs.remove(item.itemId)
        watchlistMessage = "Removed from watchlist"
    }

    func isItemSaved(_ item: CatalogItem) -> Bool {
        savedItems.contains(where: { $0.itemId == item.itemId }) || pendingWatchlistItemIDs.contains(item.itemId)
    }
}
