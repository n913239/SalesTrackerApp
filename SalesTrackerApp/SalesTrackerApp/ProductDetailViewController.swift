//
//  ProductDetailViewController.swift
//  SalesTrackerApp
//
//  Created by mike on 2026/7/18.
//

import UIKit
import SalesTracker

public final class ProductDetailViewController: UITableViewController {

    enum AccessibilityIdentifier {
        static let subtitleLabel = "product-detail-subtitle-label"
        static let messageLabel = "product-detail-message-label"
    }

    public struct Content {
        public let sales: [Sale]
        /// `nil` when the rates could not be loaded. The sales are still shown - in their own
        /// currency, with the USD column marked unavailable - rather than the screen staying blank.
        public let rates: [CurrencyRate]?

        public init(sales: [Sale], rates: [CurrencyRate]?) {
            self.sales = sales
            self.rates = rates
        }
    }

    public var onLoad: (() async -> Result<Content, Error>)?

    private let product: Product
    private let presenter = ProductDetailPresenter()
    private var viewModel: ProductDetailViewModel?

    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .subheadline)
        label.adjustsFontForContentSizeCategory = true
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0
        label.accessibilityIdentifier = AccessibilityIdentifier.subtitleLabel
        return label
    }()

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

    public init(product: Product) {
        self.product = product
        super.init(style: .plain)
    }

    required init?(coder: NSCoder) { nil }

    public override func viewDidLoad() {
        super.viewDidLoad()

        title = product.name
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "SaleCell")
        tableView.backgroundView = messageLabel

        refreshControl = UIRefreshControl()
        refreshControl?.addTarget(self, action: #selector(refresh), for: .valueChanged)

        configureHeader()
        refresh()
    }

    /// The token expires after two minutes, so coming back to a screen that was opened earlier
    /// must reload rather than keep showing what is on it.
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if viewModel != nil { refresh() }
    }

    @objc public func refresh() {
        refreshControl?.beginRefreshing()
        display(message: nil)

        Task { [weak self] in
            guard let result = await self?.onLoad?() else { return }
            self?.display(result)
        }
    }

    private func display(_ result: Result<Content, Error>) {
        refreshControl?.endRefreshing()

        switch result {
        case let .success(content):
            let viewModel = presenter.viewModel(
                for: product,
                sales: content.sales,
                converter: CurrencyConverter(rates: content.rates ?? [])
            )
            self.viewModel = viewModel
            subtitleLabel.text = viewModel.subtitle

            if content.rates == nil {
                display(message: nil)
                subtitleLabel.text = SalesTrackerStrings.localized("RATES_FAILED_MESSAGE")
            } else if content.sales.isEmpty {
                display(message: SalesTrackerStrings.localized("EMPTY_SALES_MESSAGE"))
            } else {
                display(message: nil)
            }

        case .failure:
            display(message: SalesTrackerStrings.localized("LOAD_FAILED_MESSAGE"))
        }

        sizeHeaderToFit()
        tableView.reloadData()
    }

    private func display(message: String?) {
        messageLabel.text = message
        messageLabel.isHidden = message == nil
    }

    // MARK: - Header

    private func configureHeader() {
        let header = UIView()
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(subtitleLabel)

        NSLayoutConstraint.activate([
            subtitleLabel.topAnchor.constraint(equalTo: header.topAnchor, constant: 12),
            subtitleLabel.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 16),
            subtitleLabel.trailingAnchor.constraint(equalTo: header.trailingAnchor, constant: -16),
            subtitleLabel.bottomAnchor.constraint(equalTo: header.bottomAnchor, constant: -12)
        ])

        tableView.tableHeaderView = header
    }

    private func sizeHeaderToFit() {
        guard let header = tableView.tableHeaderView else { return }

        header.frame.size.width = tableView.bounds.width
        let height = header.systemLayoutSizeFitting(
            CGSize(width: tableView.bounds.width, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        ).height

        header.frame.size.height = height
        tableView.tableHeaderView = header
    }

    // MARK: - Table view

    public override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        viewModel?.sales.count ?? 0
    }

    public override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "SaleCell", for: indexPath)
        guard let sale = viewModel?.sales[indexPath.row] else { return cell }

        var content = UIListContentConfiguration.valueCell()
        content.text = sale.amount
        content.secondaryText = sale.date
        content.prefersSideBySideTextAndSecondaryText = false
        cell.contentConfiguration = content

        let usd = UILabel()
        usd.font = .preferredFont(forTextStyle: .body)
        usd.adjustsFontForContentSizeCategory = true
        usd.text = sale.amountInUSD ?? SalesTrackerStrings.localized("USD_UNAVAILABLE")
        usd.textColor = sale.amountInUSD == nil ? .tertiaryLabel : .label
        usd.sizeToFit()
        cell.accessoryView = usd
        cell.selectionStyle = .none

        return cell
    }
}
