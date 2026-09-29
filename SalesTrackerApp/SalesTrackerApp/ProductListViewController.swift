//
//  ProductListViewController.swift
//  SalesTrackerApp
//
//  Created by mike on 2026/9/29.
//

import UIKit
import SalesTracker

public final class ProductListViewController: UITableViewController, ProductListView, ResourceLoadingView, ResourceErrorView {

    enum AccessibilityIdentifier {
        static let errorLabel = "productList.errorLabel"
        static let emptyLabel = "productList.emptyLabel"
    }

    public var onRefresh: (() -> Void)?
    public var onSelect: ((Product) -> Void)?

    private var products: [ProductViewModel] = []

    /// Set to nil after the first appearance, so coming back from the detail does not reload.
    private var onViewIsAppearing: ((ProductListViewController) -> Void)?

    private let errorLabel: UILabel = {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .footnote)
        label.adjustsFontForContentSizeCategory = true
        label.textColor = .systemRed
        label.textAlignment = .center
        label.numberOfLines = 0
        label.accessibilityIdentifier = AccessibilityIdentifier.errorLabel
        return label
    }()

    private lazy var errorContainer: UIView = {
        let container = UIView()
        errorLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(errorLabel)
        NSLayoutConstraint.activate([
            errorLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 8),
            errorLabel.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -8),
            errorLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            errorLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16)
        ])
        return container
    }()

    private let emptyLabel: UILabel = {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .body)
        label.adjustsFontForContentSizeCategory = true
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0
        label.accessibilityIdentifier = AccessibilityIdentifier.emptyLabel
        return label
    }()

    public override func viewDidLoad() {
        super.viewDidLoad()

        title = ProductListPresenter.title
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "ProductCell")

        refreshControl = UIRefreshControl()
        refreshControl?.addTarget(self, action: #selector(refresh), for: .valueChanged)

        onViewIsAppearing = { controller in
            controller.onViewIsAppearing = nil
            controller.refresh()
        }
    }

    public override func viewIsAppearing(_ animated: Bool) {
        super.viewIsAppearing(animated)
        onViewIsAppearing?(self)
    }

    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        tableView.sizeTableHeaderToFit()
    }

    // MARK: - ProductListView

    public func display(_ viewModel: ProductListViewModel) {
        products = viewModel.products
        emptyLabel.text = viewModel.emptyMessage
        tableView.backgroundView = viewModel.emptyMessage == nil ? nil : emptyLabel
        tableView.reloadData()
    }

    // MARK: - ResourceLoadingView

    public func display(_ viewModel: ResourceLoadingViewModel) {
        viewModel.isLoading ? refreshControl?.beginRefreshing() : refreshControl?.endRefreshing()
    }

    // MARK: - ResourceErrorView

    /// The message goes in the table header, above the rows. A refresh that fails while the list
    /// already has data has to be visible without scrolling, or the screen looks like it ignored
    /// the gesture.
    public func display(_ viewModel: ResourceErrorViewModel) {
        errorLabel.text = viewModel.message
        errorLabel.isHidden = viewModel.message == nil
        tableView.tableHeaderView = viewModel.message == nil ? nil : errorContainer
        tableView.sizeTableHeaderToFit()
    }

    // MARK: - UITableViewDataSource

    public override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        products.count
    }

    public override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let viewModel = products[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: "ProductCell", for: indexPath)

        var content = cell.defaultContentConfiguration()
        content.text = viewModel.name
        content.secondaryText = viewModel.salesCount
        cell.contentConfiguration = content
        cell.accessoryType = .disclosureIndicator

        return cell
    }

    // MARK: - UITableViewDelegate

    public override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        onSelect?(products[indexPath.row].product)
    }

    // MARK: - Actions

    @objc private func refresh() {
        onRefresh?()
    }
}
