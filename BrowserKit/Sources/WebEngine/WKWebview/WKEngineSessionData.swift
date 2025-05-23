// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import Common
import Foundation

/// Struct use to keep in memory the session data
struct WKEngineSessionData {
    var url: URL?
    var lastRequest: URLRequest?
    var title: String?
    var isPrivate: Bool?
    var pageMetadata: EnginePageMetadata?
    var hasOnlySecureContent: Bool?

    // TODO: FXIOS-11373 - Finish handling reader mode in WebEngine - result and state should be used properly
    // Reader mode
    var readabilityResult: ReadabilityResult?
    var readerModeState: ReaderModeState?
}
