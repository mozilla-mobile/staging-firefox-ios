// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import Common
import UIKit

public enum ToolbarButtonGesture {
    case tap
    case longPress
}

class ToolbarButton: UIButton, ThemeApplicable {
    private struct UX {
        static let verticalInset: CGFloat = 8
        static let horizontalInset: CGFloat = 8
        static let badgeImageViewBorderWidth: CGFloat = 1
        static let badgeImageViewCornerRadius: CGFloat = 10
        static let badgeIconSize = CGSize(width: 20, height: 20)
    }

    private(set) var foregroundColorNormal: UIColor = .clear
    private(set) var foregroundColorHighlighted: UIColor = .clear
    private(set) var foregroundColorDisabled: UIColor = .clear
    private(set) var backgroundColorNormal: UIColor = .clear

    private var badgeImageView: UIImageView?
    private var shouldDisplayAsHighlighted = false

    private var onLongPress: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)

        configuration = UIButton.Configuration.plain()
        configuration?.contentInsets = NSDirectionalEdgeInsets(top: UX.verticalInset,
                                                               leading: UX.horizontalInset,
                                                               bottom: UX.verticalInset,
                                                               trailing: UX.horizontalInset)
    }

    open func configure(element: ToolbarElement) {
        guard var config = configuration else {
            return
        }
        removeAllGestureRecognizers()
        configureLongPressGestureRecognizerIfNeeded(for: element)
        shouldDisplayAsHighlighted = element.shouldDisplayAsHighlighted

        let image = UIImage(named: element.iconName)?.withRenderingMode(.alwaysTemplate)
        let action = UIAction(title: element.a11yLabel,
                              image: image,
                              handler: { _ in
            element.onSelected?()
        })

        config.image = image
        isEnabled = element.isEnabled
        accessibilityIdentifier = element.a11yId
        accessibilityLabel = element.a11yLabel
        addAction(action, for: .touchUpInside)

        showsLargeContentViewer = true
        largeContentTitle = element.a11yLabel
        largeContentImage = image

        configuration = config
        if let badgeName = element.badgeImageName {
            addBadgeIcon(imageName: badgeName)
        }
        layoutIfNeeded()
    }

    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func updateConfiguration() {
        guard var updatedConfiguration = configuration else {
            return
        }

        switch state {
        case .highlighted:
            updatedConfiguration.baseForegroundColor = foregroundColorHighlighted
        case .disabled:
            updatedConfiguration.baseForegroundColor = foregroundColorDisabled
        default:
            updatedConfiguration.baseForegroundColor = shouldDisplayAsHighlighted ?
                                                       foregroundColorHighlighted :
                                                       foregroundColorNormal
        }

        updatedConfiguration.background.backgroundColor = backgroundColorNormal
        configuration = updatedConfiguration
    }

    private func addBadgeIcon(imageName: String) {
        badgeImageView = UIImageView(image: UIImage(named: imageName))
        guard let badgeImageView, configuration?.image != nil else { return }

        badgeImageView.layer.borderWidth = UX.badgeImageViewBorderWidth
        badgeImageView.layer.cornerRadius = UX.badgeImageViewCornerRadius
        badgeImageView.clipsToBounds = true
        badgeImageView.translatesAutoresizingMaskIntoConstraints = false

        imageView?.addSubview(badgeImageView)
        NSLayoutConstraint.activate([
            badgeImageView.widthAnchor.constraint(equalToConstant: UX.badgeIconSize.width),
            badgeImageView.heightAnchor.constraint(equalToConstant: UX.badgeIconSize.height),
            badgeImageView.leadingAnchor.constraint(equalTo: centerXAnchor),
            badgeImageView.bottomAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    private func configureLongPressGestureRecognizerIfNeeded(for element: ToolbarElement) {
        guard element.onLongPress != nil else { return }
        onLongPress = element.onLongPress
        let longPressRecognizer = UILongPressGestureRecognizer(
            target: self,
            action: #selector(handleLongPress)
        )
        addGestureRecognizer(longPressRecognizer)
    }

    private func removeAllGestureRecognizers() {
        guard let gestureRecognizers else { return }
            for recognizer in gestureRecognizers {
                removeGestureRecognizer(recognizer)
            }
    }

    // MARK: - Selectors
    @objc
    private func handleLongPress(_ gestureRecognizer: UILongPressGestureRecognizer) {
        if gestureRecognizer.state == .began {
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            onLongPress?()
        }
    }

    // MARK: - ThemeApplicable
    public func applyTheme(theme: Theme) {
        foregroundColorNormal = theme.colors.iconPrimary
        foregroundColorHighlighted = theme.colors.actionPrimary
        foregroundColorDisabled = theme.colors.iconDisabled
        badgeImageView?.layer.borderColor = theme.colors.layer1.cgColor
        badgeImageView?.backgroundColor = theme.colors.layer1
        backgroundColorNormal = .clear
        setNeedsUpdateConfiguration()
    }
}
