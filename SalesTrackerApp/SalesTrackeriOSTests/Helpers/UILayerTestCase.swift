//
//  UILayerTestCase.swift
//  SalesTrackeriOSTests
//
//  Created by mike on 2026/7/18.
//

import XCTest
import SalesTracker

@MainActor
class UILayerTestCase: XCTestCase {

    /// The view controllers load inside a `Task`, so the assertion cannot run on the line after the
    /// one that triggered the load. Yielding hands the main actor to that task; the stubs answer
    /// without touching the network, so it resumes on the next turn of the loop.
    func waitUntil(
        _ isRendered: () -> Bool,
        _ message: @autoclosure () -> String = "Timed out waiting for the view to render",
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        for _ in 0..<200 {
            if isRendered() { return }
            await Task.yield()
        }
        XCTFail(message(), file: file, line: line)
    }

    /// The screens fire more than one request at a time. Once the assertion has what it needs, the
    /// others can still be in flight, holding on to the objects the leak tracker is about to check.
    func drainPendingWork() async {
        for _ in 0..<100 { await Task.yield() }
    }

    // MARK: - Test data

    func makeProduct(name: String = "A product", id: UUID = UUID()) -> Product {
        Product(id: id, name: name)
    }

    func makeSale(
        amount: Decimal = 10,
        currency: String = "USD",
        productId: UUID = UUID(),
        date: Date = Date(timeIntervalSince1970: 1_700_000_000)
    ) -> Sale {
        Sale(currencyCode: currency, amount: amount, productId: productId, date: date)
    }

    func anyNSError() -> NSError {
        NSError(domain: "any", code: 0)
    }
}
