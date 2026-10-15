//
//  ProductIDs.swift
//  blocking app
//
//  Centralizes StoreKit Product IDs. These must match the products configured in
//  App Store Connect and (during development) the local `Products.storekit` file.
//

import Foundation

enum ProductIDs {
    // Must start with the app's Bundle ID (com.nonetapp) per App Store Connect rules.
    static let monthly = "com.nonetapp.monthly"
    static let yearly = "com.nonetapp.yearly"

    static let all: [String] = [monthly, yearly]
}
