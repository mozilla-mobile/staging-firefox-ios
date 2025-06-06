// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import Common
import UIKit
import ComponentLibrary

public final class MenuRedesignMainView: UIView,
                                 ThemeApplicable {
    private struct UX {
        static let headerTopMargin: CGFloat = 15
    }

    // MARK: - UI Elements
    private var collectionView: MenuCollectionView = .build()
    private var tableView: MenuTableView = .build()
    public var accountHeaderView: HeaderView = .build()

    // MARK: - Initializers
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
        handleUpdateHeaderLineView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - UI Setup
    private func setupView() {
        accountHeaderView.updateHeaderLineView(isHidden: true)
        self.addSubview(accountHeaderView)
        self.addSubview(collectionView)
        self.addSubview(tableView)

        NSLayoutConstraint.activate([
            accountHeaderView.topAnchor.constraint(equalTo: self.topAnchor, constant: UX.headerTopMargin),
            accountHeaderView.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            accountHeaderView.trailingAnchor.constraint(equalTo: self.trailingAnchor),

            collectionView.topAnchor.constraint(equalTo: accountHeaderView.bottomAnchor),
            collectionView.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: self.trailingAnchor),

            tableView.topAnchor.constraint(equalTo: collectionView.bottomAnchor),
            tableView.bottomAnchor.constraint(equalTo: self.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: self.trailingAnchor)
        ])
    }

    public func setupDetails(subtitle: String, title: String, icon: UIImage?) {
        accountHeaderView.setupDetails(subtitle: subtitle,
                                       title: title,
                                       icon: icon)
    }

    public func setupAccessibilityIdentifiers(closeButtonA11yLabel: String,
                                              closeButtonA11yId: String,
                                              mainButtonA11yLabel: String,
                                              mainButtonA11yId: String,
                                              menuA11yId: String,
                                              menuA11yLabel: String) {
        accountHeaderView.setupAccessibility(closeButtonA11yLabel: closeButtonA11yLabel,
                                             closeButtonA11yId: closeButtonA11yId,
                                             mainButtonA11yLabel: mainButtonA11yLabel,
                                             mainButtonA11yId: mainButtonA11yId)
        collectionView.setupAccessibilityIdentifiers(menuA11yId: menuA11yId, menuA11yLabel: menuA11yLabel)
        tableView.setupAccessibilityIdentifiers(menuA11yId: menuA11yId, menuA11yLabel: menuA11yLabel)
    }

    private func handleUpdateHeaderLineView() {
        tableView.updateHeaderLineView = { [weak self] isHidden in
            guard let self else { return }
            self.accountHeaderView.updateHeaderLineView(isHidden: isHidden)
        }
    }

    // MARK: - Interface
    public func reloadDataView(with data: [MenuSection]) {
        collectionView.reloadCollectionView(with: data)
        tableView.reloadTableView(with: data)
    }

    // MARK: - ThemeApplicable
    public func applyTheme(theme: Theme) {
        backgroundColor = .clear
        collectionView.applyTheme(theme: theme)
        tableView.applyTheme(theme: theme)
        accountHeaderView.applyTheme(theme: theme)
        accountHeaderView.setIconTheme(with: theme)
    }
}
