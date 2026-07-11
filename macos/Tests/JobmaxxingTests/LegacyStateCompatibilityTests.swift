import XCTest
@testable import Jobmaxxing

final class LegacyStateCompatibilityTests: XCTestCase {
  func testCommandHistorySurvivesStateRoundTrip() throws {
    var state = JobmaxxingStore.defaultState
    let run = CommandRun(
      id: "legacy-run",
      command: "prepare application",
      actor: "user",
      modelRouteID: "medium",
      result: "Prepared for review",
      toolHints: ["documents"],
      safety: ["Manual final submit"]
    )
    state.commandRuns = [run]

    let data = try JSONEncoder().encode(state)
    let decoded = try JSONDecoder().decode(JobmaxxingState.self, from: data)

    XCTAssertEqual(decoded.commandRuns, [run])
  }
}
