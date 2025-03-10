// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import Common
import Foundation

class AppIconSetting: Setting {
    private weak var settingsDelegate: GeneralSettingsDelegate?

    override var accessoryView: UIImageView? {
        guard let theme else { return nil }

        return SettingDisclosureUtility.buildDisclosureIndicator(theme: theme)
    }

    override var accessibilityIdentifier: String? {
        return AccessibilityIdentifiers.Settings.AppIconSelection.settingsRowTitle
    }

    init(theme: Theme,
         settingsDelegate: GeneralSettingsDelegate?) {
        self.settingsDelegate = settingsDelegate
        super.init(
            title: NSAttributedString(
                string: .Settings.AppIconSelection.SettingsOptionName,
                attributes: [
                    NSAttributedString.Key.foregroundColor: theme.colors.textPrimary
                ]
            )
        )
    }

    override func onClick(_ navigationController: UINavigationController?) {
        settingsDelegate?.pressedCustomizeAppIcon()
    }
}
