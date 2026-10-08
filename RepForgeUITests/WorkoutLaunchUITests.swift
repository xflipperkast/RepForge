import XCTest

/// Exercises the interaction sequence most likely to regress during visual
/// redesigns: global start -> blank workout -> add exercise. A rendered UI
/// alone cannot catch modal-presentation or hit-target failures.
final class WorkoutLaunchUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testBlankWorkoutOpensExercisePicker() throws {
        let app = XCUIApplication()
        app.launch()

        let start = app.buttons["Start or resume workout"]
        XCTAssertTrue(start.waitForExistence(timeout: 25), "Main Start control is not accessible")
        start.tap()

        let blank = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "Blank workout")
        ).firstMatch
        XCTAssertTrue(blank.waitForExistence(timeout: 15),
                      "The session launcher did not present an empty workout option")
        blank.tap()

        let addExercise = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "Add Exercise")
        ).firstMatch
        XCTAssertTrue(addExercise.waitForExistence(timeout: 20),
                      "Blank workout did not open the new logging surface")
        addExercise.tap()

        let search = app.textFields["Exercise or machine"]
        XCTAssertTrue(search.waitForExistence(timeout: 15),
                      "Exercise selector failed to open from an active workout")
    }
}
