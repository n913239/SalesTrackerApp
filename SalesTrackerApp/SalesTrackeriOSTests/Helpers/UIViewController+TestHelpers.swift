//
//  UIViewController+TestHelpers.swift
//  SalesTrackeriOSTests
//
//  Created by mike on 2026/7/18.
//

import UIKit

extension UIViewController {
    /// The fields and labels stay private in the view controllers: a test that reaches them through
    /// the same accessibility identifiers VoiceOver uses tests what the user can reach, and does not
    /// force the production code to open up its internals.
    func view<T: UIView>(withIdentifier identifier: String) -> T? {
        view.firstDescendant { $0.accessibilityIdentifier == identifier } as? T
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

extension UITableViewController {
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
}
