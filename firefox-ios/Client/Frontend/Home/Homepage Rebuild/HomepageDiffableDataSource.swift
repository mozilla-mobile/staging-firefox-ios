// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import Common
import UIKit

typealias HomepageSection = HomepageDiffableDataSource.HomeSection
typealias HomepageItem = HomepageDiffableDataSource.HomeItem

/// Holds the data source configuration for the new homepage as part of the rebuild project
final class HomepageDiffableDataSource:
    UICollectionViewDiffableDataSource<HomepageSection, HomepageItem> {
    typealias TextColor = UIColor

    enum HomeSection: Hashable {
        case header
        case topSites
        case pocket(TextColor?)
        case customizeHomepage

        init?(rawValue: Int) {
            switch rawValue {
            case 0: self = .header
            case 1: self = .topSites
            case 2: self = .pocket(nil)
            case 3: self = .customizeHomepage
            default: return nil
            }
        }
    }

    enum HomeItem: Hashable {
        case header(HeaderState)
        case topSite(TopSiteState, TextColor?)
        case topSiteEmpty
        case pocket(PocketStoryState)
        case pocketDiscover(PocketDiscoverState)
        case customizeHomepage

        static var cellTypes: [ReusableCell.Type] {
            return [
                HomepageHeaderCell.self,
                TopSiteCell.self,
                EmptyTopSiteCell.self,
                PocketStandardCell.self,
                PocketDiscoverCell.self,
                CustomizeHomepageSectionCell.self
            ]
        }
    }

    func updateSnapshot(state: HomepageState) {
        var snapshot = NSDiffableDataSourceSnapshot<HomeSection, HomeItem>()

        let textColor = state.wallpaperState.wallpaperConfiguration.textColor

        snapshot.appendSections([.header])
        snapshot.appendItems([.header(state.headerState)], toSection: .header)

        if let topSites = getTopSites(with: state.topSitesState, and: textColor) {
            snapshot.appendSections([.topSites])
            snapshot.appendItems(topSites, toSection: .topSites)
        }

        if let stories = getPocketStories(with: state.pocketState) {
            snapshot.appendSections([.pocket(textColor)])
            snapshot.appendItems(stories, toSection: .pocket(textColor))
        }

        snapshot.appendSections([.customizeHomepage])
        snapshot.appendItems([.customizeHomepage], toSection: .customizeHomepage)

        apply(snapshot, animatingDifferences: true)
    }

    private func getPocketStories(
        with pocketState: PocketState
    ) -> [HomepageDiffableDataSource.HomeItem]? {
        var stories: [HomeItem] = pocketState.pocketData.compactMap { .pocket($0) }
        guard pocketState.shouldShowSection, !stories.isEmpty else { return nil }
        stories.append(.pocketDiscover(pocketState.pocketDiscoverItem))
        return stories
    }

    /// Gets the proper amount of top sites based on layout configuration
    /// which is determined by the number of rows and number of tiles per row
    /// - Parameters:
    ///   - topSiteState: state object for top site section
    ///   - textColor: text color from wallpaper configuration
    private func getTopSites(
        with topSitesState: TopSitesSectionState,
        and textColor: TextColor?
    ) -> [HomepageDiffableDataSource.HomeItem]? {
        let topSites: [HomeItem] = topSitesState.topSitesData.compactMap { .topSite($0, textColor) }
        guard topSitesState.shouldShowSection, !topSites.isEmpty else { return nil }
        let filterTopSites = topSites.prefix(Int(topSitesState.numberOfRows) * topSitesState.numberOfTilesPerRow)
        return Array(filterTopSites)
    }
}
