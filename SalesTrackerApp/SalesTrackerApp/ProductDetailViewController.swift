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

    /// The sales and the rates load independently. The sales are the user's data and go on screen as
    /// soon as they arrive; the rates come from a free-tier middleware that cold-starts in about
    /// fourteen seconds, and waiting for them would leave the screen blank for that long.
    public var onLoad: (() async -> Result<[Sale], Error>)?

    /// `nil` when the rates could not be loaded.
    public var onLoadRates: (() async -> [CurrencyRate]?)?

    private let product: Product
    private let presenter = ProductDetailPresenter()
    private var viewModel: ProductDetailViewModel?
    private var sales = [Sale]()

    /// Tells "the rates have not come back yet" apart from "there is no rate for this currency".
    /// Saying a rate is unavailable while the request is still in flight would be a lie.
    private var hasResolvedRates = false

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
        beginRefreshing()
        display(message: nil)
        hasResolvedRates = false

        // Held onto here rather than reached through `self` inside the task: `await self?.onLoad?()`
        // would keep the view controller alive for as long as the request is in flight.
        let load = onLoad
        let loadRates = onLoadRates

        Task { [weak self] in
            // Started before the sales are awaited, so the two requests overlap.
            async let loadedRates = loadRates?()

            guard let result = await load?() else { return }
            self?.display(result)

            guard case .success = result else { return }

            let resolvedRates = await loadedRates ?? nil
            self?.display(rates: resolvedRates)
        }
    }

    private func display(_ result: Result<[Sale], Error>) {
        endRefreshing()

        switch result {
        case let .success(sales):
            self.sales = sales
            render(converter: nil)
            display(message: sales.isEmpty ? SalesTrackerStrings.localized("EMPTY_SALES_MESSAGE") : nil)

        case .failure:
            self.sales = []
            self.viewModel = nil
            subtitleLabel.text = nil
            display(message: SalesTrackerStrings.localized("LOAD_FAILED_MESSAGE"))
            sizeHeaderToFit()
            tableView.reloadData()
        }
    }

    private func display(rates: [CurrencyRate]?) {
        hasResolvedRates = true

        guard let rates else {
            subtitleLabel.text = SalesTrackerStrings.localized("RATES_FAILED_MESSAGE")
            sizeHeaderToFit()
            tableView.reloadData()
            return
        }

        render(converter: CurrencyConverter(rates: rates))
    }

    private func render(converter: CurrencyConverter?) {
        let viewModel = presenter.viewModel(for: product, sales: sales, converter: converter)
        self.viewModel = viewModel
        subtitleLabel.text = viewModel.subtitle

        sizeHeaderToFit()
        tableView.reloadData()
    }

    private func display(message: String?) {
        messageLabel.text = message
        messageLabel.isHidden = message == nil
    }

    // MARK: - Refresh control

    /// `beginRefreshing()` on its own only sets the state: the spinner sits above the content and
    /// stays out of sight unless the table is scrolled down to it. A load the user did not start by
    /// pulling would otherwise show nothing at all - a blank screen for as long as the request takes.
    private func beginRefreshing() {
        guard let refreshControl, !refreshControl.isRefreshing else { return }

        refreshControl.beginRefreshing()

        if tableView.contentOffset.y <= 0 {
            tableView.setContentOffset(CGPoint(x: 0, y: -refreshControl.frame.height), animated: true)
        }
    }

    private func endRefreshing() {
        refreshControl?.endRefreshing()
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
        usd.text = sale.amountInUSD ?? SalesTrackerStrings.localized(hasResolvedRates ? "USD_UNAVAILABLE" : "USD_PENDING")
        usd.textColor = sale.amountInUSD == nil ? .tertiaryLabel : .label
        usd.sizeToFit()
        cell.accessoryView = usd
        cell.selectionStyle = .none

        return cell
    }
}
