//
//  UnogsService.swift
//  NetflixWatchlist
//
//  Created by Kyle Mooney on 1/30/25.
//

import Foundation

class UnogsService {
    private let apiKey: String
    private let apiHost: String
    let maxApiCallsPerDay = 50
    private let userDefaults = UserDefaults.standard
    private let apiCallCountKey = "UnogsAPICallCount"
    private let lastResetDateKey = "UnogsLastResetDate"

    init() {
        apiKey = Bundle.main.object(forInfoDictionaryKey: "API_KEY") as? String ?? ""
        apiHost = Bundle.main.object(forInfoDictionaryKey: "API_HOST") as? String ?? ""
        resetApiCountIfNewDay() // run check every time app runs
    }
    
    func remainingApiCalls() -> Int {
        return userDefaults.integer(forKey: apiCallCountKey)
    }

    private func incrementApiCallCount() {
        let newCount = remainingApiCalls() + 1
        userDefaults.set(newCount, forKey: apiCallCountKey)
    }
    
    private func resetApiCountIfNewDay() {
        let lastResetDate = userDefaults.object(forKey: lastResetDateKey) as? Date ?? Date.distantPast
        if !Calendar.current.isDateInToday(lastResetDate) {
            userDefaults.set(0, forKey: apiCallCountKey)
            userDefaults.set(Date(), forKey: lastResetDateKey)
        }
    }

    func searchCatalogItems(title: String, completion: @escaping (Result<[CatalogItem], SearchError>) -> Void) {
        guard let url = URL(string: "https://unogs-unogs-v1.p.rapidapi.com/search/titles?title=\(title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")") else {
            completion(.failure(SearchError.invalidURL))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(apiKey, forHTTPHeaderField: "x-rapidapi-key")
        request.setValue(apiHost, forHTTPHeaderField: "x-rapidapi-host")

        incrementApiCallCount()

        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                completion(.failure(SearchError.networkError(error?.localizedDescription ?? "Unknown error")))
                return
            }

            do {
                let jsonResponse = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
                if let results = jsonResponse?["results"] as? [[String: Any]] {
                    let catalogItems = results.prefix(5).compactMap { result in
                        let itemId: String
                        if let idString = result["netflix_id"] as? String {
                            itemId = idString
                        } else if let idInt = result["netflix_id"] as? Int {
                            itemId = String(idInt)
                        } else if let fallback = result["id"] as? String, !fallback.isEmpty {
                            itemId = fallback
                        } else {
                            itemId = UUID().uuidString
                        }

                        return CatalogItem(
                            itemId: itemId,
                            title: result["title"] as? String ?? "",
                            img: result["img"] as? String ?? "",
                            synopsis: result["synopsis"] as? String ?? "",
                            availability: nil
                        )
                    }
                    completion(.success(catalogItems))
                } else {
                    completion(.failure(SearchError.emptyResults))
                }
            } catch {
                completion(.failure(SearchError.decodingError(error.localizedDescription)))
            }
        }.resume()
    }

      func fetchCatalogItemAvailability(itemId: String, completion: @escaping ([CountryAvailability]) -> Void) {
        guard let url = URL(string: "https://unogs-unogs-v1.p.rapidapi.com/title/countries?netflix_id=\(itemId)") else {
            completion([])
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(apiKey, forHTTPHeaderField: "x-rapidapi-key")
        request.setValue(apiHost, forHTTPHeaderField: "x-rapidapi-host")

        incrementApiCallCount()

        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                print("Error fetching availability:", error?.localizedDescription ?? "Unknown error")
                completion([])
                return
            }

            do {
                let jsonResponse = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
                if let results = jsonResponse?["results"] as? [[String: Any]] {
                    let availability = results.compactMap { result in
                        CountryAvailability(
                            countryCode: result["country_code"] as? String ?? "",
                            country: result["country"] as? String ?? "",
                            audio: result["audio"] as? String ?? "",
                            subtitle: result["subtitle"] as? String ?? ""
                        )
                    }
                    completion(availability)
                } else {
                    completion([])
                }
            } catch {
                print("Error decoding JSON:", error.localizedDescription)
                completion([])
            }
        }.resume()
    }
}
