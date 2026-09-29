//
//  UITableView+HeaderSizing.swift
//  SalesTrackerApp
//
//  Created by mike on 2026/9/29.
//

import UIKit

extension UITableView {
    /// A table header keeps whatever height it was given, so a two-line error at the largest
    /// dynamic type size gets cropped instead of growing. Re-measuring it after layout is what
    /// keeps the whole message on screen.
    func sizeTableHeaderToFit() {
        guard let header = tableHeaderView, bounds.width > 0 else { return }

        let size = header.systemLayoutSizeFitting(
            CGSize(width: bounds.width, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        )

        guard header.frame.height != size.height else { return }

        header.frame.size.height = size.height
        tableHeaderView = header
    }
}
