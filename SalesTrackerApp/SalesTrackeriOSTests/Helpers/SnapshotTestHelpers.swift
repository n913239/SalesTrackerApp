//
//  SnapshotTestHelpers.swift
//  SalesTrackeriOSTests
//
//  Created by mike on 2026/9/29.
//

import XCTest
import UIKit

// MARK: - XCTestCase Snapshot Assertions

extension XCTestCase {

    func assert(snapshot: UIImage, named name: String, file: StaticString = #filePath, line: UInt = #line) {
        let snapshotURL = makeSnapshotURL(named: name, file: file)

        guard
            let storedSnapshotData = try? Data(contentsOf: snapshotURL),
            let storedSnapshot = UIImage(data: storedSnapshotData)
        else {
            XCTFail("No reference snapshot found at \(snapshotURL). Use record(snapshot:named:) to store one first.", file: file, line: line)
            return
        }

        guard
            let newSnapshotData = snapshot.pngData(),
            let newSnapshot = UIImage(data: newSnapshotData)
        else {
            XCTFail("Failed to encode the new snapshot as PNG", file: file, line: line)
            return
        }

        guard let difference = newSnapshot.difference(from: storedSnapshot) else {
            XCTFail("Snapshots are not comparable (different sizes or unreadable pixels)", file: file, line: line)
            return
        }

        if !difference.isAcceptable {
            let temporarySnapshotURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
                .appendingPathComponent(snapshotURL.lastPathComponent)
            try? newSnapshotData.write(to: temporarySnapshotURL)

            let newAttachment = XCTAttachment(image: newSnapshot)
            newAttachment.name = "\(name)-new"
            newAttachment.lifetime = .keepAlways
            add(newAttachment)

            let storedAttachment = XCTAttachment(image: storedSnapshot)
            storedAttachment.name = "\(name)-stored"
            storedAttachment.lifetime = .keepAlways
            add(storedAttachment)

            XCTFail(
                "New snapshot does not match stored snapshot: \(difference.debugSummary). New: \(temporarySnapshotURL). Stored: \(snapshotURL).",
                file: file,
                line: line
            )
        }
    }

    func record(snapshot: UIImage, named name: String, file: StaticString = #filePath, line: UInt = #line) {
        let snapshotURL = makeSnapshotURL(named: name, file: file)
        let snapshotData = makeSnapshotData(for: snapshot, file: file, line: line)

        do {
            try FileManager.default.createDirectory(
                at: snapshotURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try snapshotData?.write(to: snapshotURL)
            XCTFail("Record succeeded. Switch to assert(snapshot:named:) to verify from now on.", file: file, line: line)
        } catch {
            XCTFail("Failed to record snapshot with error: \(error)", file: file, line: line)
        }
    }

    private func makeSnapshotURL(named name: String, file: StaticString) -> URL {
        URL(fileURLWithPath: String(describing: file))
            .deletingLastPathComponent()
            .appendingPathComponent("snapshots")
            .appendingPathComponent("\(name).png")
    }

    private func makeSnapshotData(for snapshot: UIImage, file: StaticString, line: UInt) -> Data? {
        guard let data = snapshot.pngData() else {
            XCTFail("Failed to generate PNG data from snapshot", file: file, line: line)
            return nil
        }
        return data
    }
}

// MARK: - SnapshotConfiguration

struct SnapshotConfiguration {
    let size: CGSize
    let safeAreaInsets: UIEdgeInsets
    let layoutMargins: UIEdgeInsets
    let traitCollection: UITraitCollection

    static func iPhone(
        style: UIUserInterfaceStyle,
        contentSize: UIContentSizeCategory = .medium
    ) -> SnapshotConfiguration {
        SnapshotConfiguration(
            size: CGSize(width: 390, height: 844),
            safeAreaInsets: UIEdgeInsets(top: 47, left: 0, bottom: 34, right: 0),
            layoutMargins: UIEdgeInsets(top: 55, left: 8, bottom: 42, right: 8),
            traitCollection: UITraitCollection(mutations: { traits in
                traits.forceTouchCapability = .unavailable
                traits.layoutDirection = .leftToRight
                traits.preferredContentSizeCategory = contentSize
                traits.userInterfaceIdiom = .phone
                traits.horizontalSizeClass = .compact
                traits.verticalSizeClass = .regular
                traits.displayScale = 3
                traits.accessibilityContrast = .normal
                traits.displayGamut = .P3
                traits.userInterfaceStyle = style
            })
        )
    }
}

// MARK: - UIViewController Snapshot

extension UIViewController {
    func snapshot(for configuration: SnapshotConfiguration = .iPhone(style: .light)) -> UIImage {
        let window = SnapshotWindow(configuration: configuration, root: self)
        let image = window.snapshot()
        window.rootViewController = nil
        window.isHidden = true
        return image
    }
}

// MARK: - SnapshotWindow

private final class SnapshotWindow: UIWindow {
    private var configuration: SnapshotConfiguration = .iPhone(style: .light)

    convenience init(configuration: SnapshotConfiguration, root: UIViewController) {
        let dummyScene = (UIWindowScene.self as NSObject.Type).init() as! UIWindowScene
        self.init(windowScene: dummyScene)
        self.frame = CGRect(origin: .zero, size: configuration.size)
        self.configuration = configuration
        self.layoutMargins = configuration.layoutMargins
        self.rootViewController = root
        self.isHidden = false
        root.view.layoutMargins = configuration.layoutMargins
    }

    override var safeAreaInsets: UIEdgeInsets {
        configuration.safeAreaInsets
    }

    override var traitCollection: UITraitCollection {
        configuration.traitCollection
    }

    func snapshot() -> UIImage {
        setNeedsLayout()
        layoutIfNeeded()

        let renderer = UIGraphicsImageRenderer(bounds: bounds, format: .init(for: traitCollection))
        return renderer.image { action in
            layer.render(in: action.cgContext)
        }
    }
}

// MARK: - Tolerant image comparison

struct SnapshotDifference {
    /// Text can reflow across machines even when the font, the label width and the simulator
    /// runtime are identical, which moves a word across a line break and changes a small fraction
    /// of the pixels. Every pixel that is compared must still match exactly: colour slop is not
    /// tolerated, only a small number of relocated pixels.
    static let maximumMismatchedPixelRatio = 0.01

    let mismatchedPixelRatio: Double
    let maximumChannelDelta: Int

    var isAcceptable: Bool {
        mismatchedPixelRatio <= Self.maximumMismatchedPixelRatio
    }

    var debugSummary: String {
        let percentage = String(format: "%.4f", mismatchedPixelRatio * 100)
        return "\(percentage)% of pixels differ, maximum per-channel delta \(maximumChannelDelta)"
    }
}

private extension UIImage {
    func difference(from other: UIImage) -> SnapshotDifference? {
        guard
            let a = cgImage, let b = other.cgImage,
            a.width == b.width, a.height == b.height,
            let bytesA = a.rgbaBytes(), let bytesB = b.rgbaBytes(),
            bytesA.count == bytesB.count
        else { return nil }

        let pixelCount = bytesA.count / 4
        guard pixelCount > 0 else { return nil }

        var mismatched = 0
        var maximumDelta = 0

        for index in 0..<pixelCount {
            let i = index * 4
            var pixelDelta = 0
            for channel in 0..<4 {
                pixelDelta = max(pixelDelta, abs(Int(bytesA[i + channel]) - Int(bytesB[i + channel])))
            }
            if pixelDelta > 0 {
                mismatched += 1
                maximumDelta = max(maximumDelta, pixelDelta)
            }
        }

        return SnapshotDifference(
            mismatchedPixelRatio: Double(mismatched) / Double(pixelCount),
            maximumChannelDelta: maximumDelta
        )
    }
}

private extension CGImage {
    func rgbaBytes() -> [UInt8]? {
        let bytesPerRow = width * 4
        var data = [UInt8](repeating: 0, count: height * bytesPerRow)
        guard let context = CGContext(
            data: &data,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        context.draw(self, in: CGRect(x: 0, y: 0, width: width, height: height))
        return data
    }
}
