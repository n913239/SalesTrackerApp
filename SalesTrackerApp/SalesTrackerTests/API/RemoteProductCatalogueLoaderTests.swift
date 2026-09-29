//
//  RemoteProductCatalogueLoaderTests.swift
//  SalesTrackerTests
//
//  Created by mike on 2026/9/29.
//

import XCTest
import SalesTracker

final class RemoteProductCatalogueLoaderTests: XCTestCase {

    func test_load_requestsTheGivenProductsAndSalesURLs() async throws {
        let client = HTTPClientSpy()
        await client.stub(url: productsURL, with: makeProductsJSON([]))
        await client.stub(url: salesURL, with: makeSalesJSON([]))
        let sut = makeSUT(client: client)

        _ = try await sut.load()

        let requested = await client.requestedURLs
        XCTAssertEqual(Set(requested), [productsURL, salesURL])
    }

    func test_load_deliversACatalogueBuiltFromBothResponses() async throws {
        let id = UUID()
        let client = HTTPClientSpy()
        await client.stub(url: productsURL, with: makeProductsJSON([["id": id.uuidString, "name": "iPhone"]]))
        await client.stub(url: salesURL, with: makeSalesJSON([[
            "currency_code": "USD", "amount": "10.00", "product_id": id.uuidString, "date": "2030-01-02T11:00:00Z"
        ]]))
        let sut = makeSUT(client: client)

        let catalogue = try await sut.load()

        XCTAssertEqual(catalogue.summaries(), [ProductSummary(product: Product(id: id, name: "iPhone"), salesCount: 1)])
    }

    func test_load_onProductsFailure_throws() async {
        let client = HTTPClientSpy()
        await client.stub(url: productsURL, with: Data("invalid json".utf8))
        await client.stub(url: salesURL, with: makeSalesJSON([]))
        let sut = makeSUT(client: client)

        do {
            _ = try await sut.load()
            XCTFail("Expected to throw")
        } catch {
            XCTAssertEqual(error as? RemoteLoader<[Product]>.Error, .invalidData)
        }
    }

    func test_load_onSalesFailure_throws() async {
        let client = HTTPClientSpy()
        await client.stub(url: productsURL, with: makeProductsJSON([]))
        await client.stub(url: salesURL, with: Data("invalid json".utf8))
        let sut = makeSUT(client: client)

        do {
            _ = try await sut.load()
            XCTFail("Expected to throw")
        } catch {
            XCTAssertEqual(error as? RemoteLoader<[Sale]>.Error, .invalidData)
        }
    }

    func test_load_onUnauthorized_rethrowsItByType() async {
        let client = HTTPClientSpy()
        await client.stub(url: productsURL, with: makeProductsJSON([]), statusCode: 401)
        await client.stub(url: salesURL, with: makeSalesJSON([]))
        let sut = makeSUT(client: client)

        do {
            _ = try await sut.load()
            XCTFail("Expected to throw")
        } catch {
            XCTAssertEqual(error as? HTTPClientError, .unauthorized)
        }
    }

    // MARK: - Helpers

    private var productsURL: URL { URL(string: "https://a-backend.com/products")! }
    private var salesURL: URL { URL(string: "https://a-backend.com/sales")! }

    private func makeSUT(client: HTTPClient, file: StaticString = #filePath, line: UInt = #line) -> RemoteProductCatalogueLoader {
        let sut = RemoteProductCatalogueLoader(client: client, productsURL: productsURL, salesURL: salesURL)
        return sut
    }

    private func makeProductsJSON(_ items: [[String: String]]) -> Data {
        try! JSONSerialization.data(withJSONObject: items)
    }

    private func makeSalesJSON(_ items: [[String: String]]) -> Data {
        try! JSONSerialization.data(withJSONObject: items)
    }
}

private actor HTTPClientSpy: HTTPClient {
    private struct Stub {
        let data: Data
        let statusCode: Int
    }

    private(set) var requestedURLs: [URL] = []
    private var stubs: [URL: Stub] = [:]

    func stub(url: URL, with data: Data, statusCode: Int = 200) {
        stubs[url] = Stub(data: data, statusCode: statusCode)
    }

    func get(from url: URL, headers: [String: String]) async throws -> (Data, HTTPURLResponse) {
        requestedURLs.append(url)
        guard let stub = stubs[url] else { throw NSError(domain: "no stub for \(url)", code: 0) }
        if stub.statusCode == 401 { throw HTTPClientError.unauthorized }
        return (stub.data, HTTPURLResponse(url: url, statusCode: stub.statusCode, httpVersion: nil, headerFields: nil)!)
    }

    func post(to url: URL, body: Data, headers: [String: String]) async throws -> (Data, HTTPURLResponse) {
        throw NSError(domain: "not used", code: 0)
    }
}
