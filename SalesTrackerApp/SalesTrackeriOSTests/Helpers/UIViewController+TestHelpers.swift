//
//  UIViewController+TestHelpers.swift
//  SalesTrackeriOSTests
//
//  Created by mike on 2026/9/29.
//

import UIKit

extension UIViewController {
    /// The fields and labels stay private in the view controllers: a test that reaches them through
    /// the same accessibility identifiers VoiceOver uses tests what the user can reach, and does not
    /// force the production code to open up its internals.
    func view<T: UIView>(withIdentifier identifier: String) -> T? {
        view.firstDescendant { $0.accessibilityIdentifier == identifier } as? T
    }

    /// Drives the real appearance transition, so `viewIsAppearing(_:)` fires exactly as it does on
    /// a device. The fake refresh control is swapped in first: `viewIsAppearing` is where the first
    /// load starts, and a `beginRefreshing()` landing on the real control would go unrecorded.
    func simulateAppearance() {
        loadViewIfNeeded()

        if let tableController = self as? UITableViewController,
           !(tableController.refreshControl is FakeRefreshControl) {
            tableController.replaceRefreshControlWithFake()
        }

        beginAppearanceTransition(true, animated: false)
        endAppearanceTransition()
    }

    var errorMessage: String? {
        let label = view.firstDescendant {
            ($0.accessibilityIdentifier ?? "").hasSuffix(".errorLabel")
        } as? UILabel

        guard let label, !label.isHidden, label.alpha > 0 else { return nil }
        return label.text
    }

    var isShowingError: Bool {
        errorMessage?.isEmpty == false
    }
}

extension UIView {
    func firstDescendant(where matches: (UIView) -> Bool) -> UIView? {
        for subview in subviews {
            if matches(subview) { return subview }
            if let found = subview.firstDescendant(where: matches) { return found }
        }
        return nil
    }
}

extension UITextField {
    func simulateTyping(_ text: String) {
        self.text = text
        sendActions(for: .editingChanged)
    }
}

extension UIButton {
    func simulateTap() {
        sendActions(for: .touchUpInside)
    }
}

extension UIRefreshControl {
    func simulatePullToRefresh() {
        sendActions(for: .valueChanged)
    }
}

/// `UIRefreshControl.beginRefreshing()` has no effect while the view is not in a window, and on
/// iOS 17 and later a call made from `viewDidLoad` is ignored outright - the real control always
/// reports `isRefreshing == false` in a test, so a missing spinner would go unnoticed.
final class FakeRefreshControl: UIRefreshControl {
    private var _isRefreshing = false

    override var isRefreshing: Bool { _isRefreshing }
    override func beginRefreshing() { _isRefreshing = true }
    override func endRefreshing() { _isRefreshing = false }
}

extension UITableViewController {
    @discardableResult
    func replaceRefreshControlWithFake() -> FakeRefreshControl {
        let fake = FakeRefreshControl()

        refreshControl?.allTargets.forEach { target in
            refreshControl?.actions(forTarget: target, forControlEvent: .valueChanged)?.forEach { action in
                fake.addTarget(target, action: Selector(action), for: .valueChanged)
            }
        }

        refreshControl = fake
        return fake
    }

    var numberOfRenderedRows: Int {
        tableView.numberOfSections == 0 ? 0 : tableView.numberOfRows(inSection: 0)
    }

    func cell(at row: Int) -> UITableViewCell? {
        guard row < numberOfRenderedRows else { return nil }
        return tableView.dataSource?.tableView(tableView, cellForRowAt: IndexPath(row: row, section: 0))
    }

    func simulateTapOnRow(_ row: Int) {
        tableView.delegate?.tableView?(tableView, didSelectRowAt: IndexPath(row: row, section: 0))
    }

    func title(at row: Int) -> String? {
        (cell(at: row)?.contentConfiguration as? UIListContentConfiguration)?.text
    }

    func subtitle(at row: Int) -> String? {
        (cell(at: row)?.contentConfiguration as? UIListContentConfiguration)?.secondaryText
    }

    func accessoryText(at row: Int) -> String? {
        (cell(at: row)?.accessoryView as? UILabel)?.text
    }

    /// Asserts the behaviour - "this row is shown as converted" - rather than the colour that
    /// happens to express it today.
    func isConverted(at row: Int) -> Bool {
        (cell(at: row)?.accessoryView as? UILabel)?.textColor == .label
    }

    var emptyMessage: String? {
        (tableView.backgroundView as? UILabel)?.text
    }
}
