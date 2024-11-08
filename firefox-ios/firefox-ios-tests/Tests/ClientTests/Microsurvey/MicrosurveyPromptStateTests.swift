// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import Redux
import XCTest

@testable import Client

final class MicrosurveyPromptStateTests: XCTestCase {
    override func setUp() {
        super.setUp()
        DependencyHelperMock().bootstrapDependencies()
    }

    override func tearDown() {
        super.tearDown()
        DependencyHelperMock().reset()
    }

    func testShowPromptAction() {
        let initialState = createSubject()
        let reducer = microsurveyReducer()

        XCTAssertEqual(initialState.showPrompt, false)

        let action = getAction(for: .initialize(MicrosurveyModel()))
        let newState = reducer(initialState, action)

        XCTAssertEqual(newState.showPrompt, true)
        XCTAssertEqual(newState.showSurvey, false)
    }

    func testDismissPromptAction() {
        let initialState = MicrosurveyPromptState(
            windowUUID: .XCTestDefaultUUID,
            showPrompt: true,
            showSurvey: false,
            model: MicrosurveyModel()
        )
        let reducer = microsurveyReducer()

        XCTAssertEqual(initialState.showPrompt, true)

        let action = getAction(for: .dismissPrompt)
        let newState = reducer(initialState, action)

        XCTAssertEqual(newState.showPrompt, false)
        XCTAssertEqual(newState.showSurvey, false)
    }

    func testShowSurveyAction() {
        let initialState = createSubject()
        let reducer = microsurveyReducer()

        XCTAssertEqual(initialState.showSurvey, false)

        let action = getAction(for: .openSurvey)
        let newState = reducer(initialState, action)

        XCTAssertEqual(newState.showSurvey, true)
        XCTAssertEqual(newState.showPrompt, true)
    }

    // MARK: - Private
    private func createSubject() -> MicrosurveyPromptState {
        return MicrosurveyPromptState(windowUUID: .XCTestDefaultUUID)
    }

    private func microsurveyReducer() -> Reducer<MicrosurveyPromptState> {
        return MicrosurveyPromptState.reducer
    }

    private func getAction(for actionType: MicrosurveyPromptMiddlewareActionType) -> MicrosurveyPromptMiddlewareAction {
        return  MicrosurveyPromptMiddlewareAction(windowUUID: .XCTestDefaultUUID, actionType: actionType)
    }
}
