//
//  ProductDetailViewController.swift
//  SalesTrackerApp
//
//  Created by mike on 2026/9/29.
//

import UIKit
import SalesTracker

public final class ProductDetailViewController: UITableViewController, ProductDetailView, ResourceLoadingView, ResourceErrorView {

    enum AccessibilityIdentifier {
        static let subtitleLabel = "productDetail.subtitleLabel"
        static let errorLabel = "productDetail.errorLabel"
        static let emptyLabel = "productDetail.emptyLabel"
    }

    public var onLoad: (() -> Void)?
    public var onRefresh: (() -> Void)?

    private var sales: [SaleViewModel] = []

    /// Set to nil after the first appearance: the detail loads once, and a pull is the only way
    /// to ask for it again.
    private var onViewIsAppearing: ((ProductDetailViewController) -> Void)?

    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .subheadline)
        label.adjustsFontForContentSizeCategory = true
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        label.accessibilityIdentifier = AccessibilityIdentifier.subtitleLabel
        return label
    }()

    private let errorLabel: UILabel = {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .footnote)
        label.adjustsFontForContentSizeCategory = true
        label.textColor = .systemRed
        label.numberOfLines = 0
        label.isHidden = true
        label.accessibilityIdentifier = AccessibilityIdentifier.errorLabel
        return label
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

    private lazy var headerView: UIView = {
        let stack = UIStackView(arrangedSubviews: [subtitleLabel, errorLabel])
        stack.axis = .vertical
        stack.spacing = 4

        let container = UIView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: 8),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -8),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16)
        ])
        return container
    }()

    public override func viewDidLoad() {
        super.viewDidLoad()

        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "SaleCell")
        tableView.allowsSelection = false
        tableView.tableHeaderView = headerView
        registerForTraitChanges([UITraitPreferredContentSizeCategory.self], action: #selector(reloadRows))

        refreshControl = UIRefreshControl()
        refreshControl?.addTarget(self, action: #selector(refresh), for: .valueChanged)

        onViewIsAppearing = { controller in
            controller.onViewIsAppearing = nil
            controller.onLoad?()
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

    // MARK: - ProductDetailView

    public func display(_ viewModel: ProductDetailViewModel) {
        sales = viewModel.sales
        subtitleLabel.text = viewModel.subtitle
        emptyLabel.text = viewModel.emptyMessage
        tableView.backgroundView = viewModel.emptyMessage == nil ? nil : emptyLabel
        tableView.reloadData()
        tableView.sizeTableHeaderToFit()
    }

    // MARK: - ResourceLoadingView

    public func display(_ viewModel: ResourceLoadingViewModel) {
        viewModel.isLoading ? refreshControl?.beginRefreshing() : refreshControl?.endRefreshing()
    }

    // MARK: - ResourceErrorView

    /// Shares the header with the summary, so a failed refresh never costs the user the rows or
    /// the total they were already reading.
    public func display(_ viewModel: ResourceErrorViewModel) {
        errorLabel.text = viewModel.message
        errorLabel.isHidden = viewModel.message == nil
        tableView.sizeTableHeaderToFit()
    }

    // MARK: - UITableViewDataSource

    public override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        sales.count
    }

    public override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let viewModel = sales[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: "SaleCell", for: indexPath)

        var content = cell.defaultContentConfiguration()
        content.text = viewModel.amount

        if tableView.traitCollection.preferredContentSizeCategory.isAccessibilityCategory {
            content.textProperties.numberOfLines = 1
            content.textProperties.adjustsFontSizeToFitWidth = true
            content.textProperties.minimumScaleFactor = 0.5
            content.secondaryAttributedText = dateAboveUSD(for: viewModel)
            cell.accessoryView = nil
        } else {
            content.secondaryText = viewModel.date
            cell.accessoryView = usdLabel(for: viewModel)
        }

        cell.contentConfiguration = content
        return cell
    }

    // MARK: - Row Layout

    /// At accessibility text sizes a USD column beside the amount leaves too little width, and the
    /// amounts would break in the middle of a number, so the USD value moves under the date.
    private func dateAboveUSD(for viewModel: SaleViewModel) -> NSAttributedString {
        let text = NSMutableAttributedString(string: viewModel.date + "\n")
        text.append(NSAttributedString(string: viewModel.amountInUSD, attributes: [
            .foregroundColor: usdColor(for: viewModel)
        ]))
        return text
    }

    private func usdLabel(for viewModel: SaleViewModel) -> UILabel {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .subheadline)
        label.adjustsFontForContentSizeCategory = true
        label.text = viewModel.amountInUSD
        label.textColor = usdColor(for: viewModel)
        label.sizeToFit()
        return label
    }

    private func usdColor(for viewModel: SaleViewModel) -> UIColor {
        viewModel.isConverted ? .label : .tertiaryLabel
    }

    // MARK: - Actions

    @objc private func refresh() {
        onRefresh?()
    }

    @objc private func reloadRows() {
        tableView.reloadData()
    }
}
