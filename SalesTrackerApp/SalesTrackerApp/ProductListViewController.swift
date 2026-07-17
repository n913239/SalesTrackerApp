//
//  ProductListViewController.swift
//  SalesTrackerApp
//
//  Created by mike on 2026/7/18.
//

import UIKit
import SalesTracker

public final class ProductListViewController: UITableViewController {

    enum AccessibilityIdentifier {
        static let messageLabel = "product-list-message-label"
    }

    /// Loads the catalogue. The exchange rates are not part of this: the list needs a name and a
    /// count, so a slow or failing rates request must never keep the products off the screen.
    public var onLoad: (() async -> Result<[ProductSummary], Error>)?
    public var onSelect: ((Product) -> Void)?

    private let presenter = ProductListPresenter()
    private var summaries = [ProductSummary]()
    private var viewModels = [ProductViewModel]()

    private let messageLabel: UILabel = {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .body)
        label.adjustsFontForContentSizeCategory = true
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0
        label.accessibilityIdentifier = AccessibilityIdentifier.messageLabel
        return label
    }()

    public override func viewDidLoad() {
        super.viewDidLoad()

        title = ProductListPresenter.title
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "ProductCell")
        tableView.backgroundView = messageLabel

        refreshControl = UIRefreshControl()
        refreshControl?.addTarget(self, action: #selector(refresh), for: .valueChanged)

        refresh()
    }

    @objc public func refresh() {
        beginRefreshing()
        display(message: nil)

        // Held onto here rather than reached through `self` inside the task: `await self?.onLoad?()`
        // would keep the view controller alive for as long as the request is in flight.
        let load = onLoad

        Task { [weak self] in
            guard let result = await load?() else { return }
            self?.display(result)
        }
    }

    /// `beginRefreshing()` on its own only sets the state: the spinner sits above the content and
    /// stays out of sight unless the table is scrolled down to it. A load the user did not start by
    /// pulling would otherwise show nothing at all.
    private func beginRefreshing() {
        guard let refreshControl, !refreshControl.isRefreshing else { return }

        refreshControl.beginRefreshing()

        if tableView.contentOffset.y <= 0 {
            tableView.setContentOffset(CGPoint(x: 0, y: -refreshControl.frame.height), animated: true)
        }
    }

    private func display(_ result: Result<[ProductSummary], Error>) {
        refreshControl?.endRefreshing()

        switch result {
        case let .success(summaries):
            self.summaries = summaries
            self.viewModels = presenter.viewModels(for: summaries)
            display(message: summaries.isEmpty ? SalesTrackerStrings.localized("EMPTY_PRODUCTS_MESSAGE") : nil)

        case .failure:
            display(message: SalesTrackerStrings.localized("LOAD_FAILED_MESSAGE"))
        }

        tableView.reloadData()
    }

    private func display(message: String?) {
        messageLabel.text = message
        messageLabel.isHidden = message == nil
    }

    // MARK: - Table view

    public override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        viewModels.count
    }

    public override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ProductCell", for: indexPath)
        let viewModel = viewModels[indexPath.row]

        var content = UIListContentConfiguration.valueCell()
        content.text = viewModel.name
        content.secondaryText = viewModel.salesCount
        cell.contentConfiguration = content
        cell.accessoryType = .disclosureIndicator

        return cell
    }

    public override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        onSelect?(summaries[indexPath.row].product)
    }
}
