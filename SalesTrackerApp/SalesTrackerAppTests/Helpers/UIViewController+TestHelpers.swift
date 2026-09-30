//
//  UIViewController+TestHelpers.swift
//  SalesTrackerAppTests
//
//  Created by mike on 2026/9/30.
//

import UIKit

extension UIViewController {
    func view<T: UIView>(withIdentifier identifier: String) -> T? {
        view.firstDescendant { $0.accessibilityIdentifier == identifier } as? T
    }

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

    func isConverted(at row: Int) -> Bool {
        (cell(at: row)?.accessoryView as? UILabel)?.textColor == .label
    }

    var emptyMessage: String? {
        (tableView.backgroundView as? UILabel)?.text
    }
}
