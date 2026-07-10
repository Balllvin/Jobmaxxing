import XCTest
@testable import Jobmaxxing

final class ModelInventoryTests: XCTestCase {
  func testDiscoveredModelIsSelectable() throws {
    let provider = try XCTUnwrap(ModelCatalog.provider(id: "xai"))
    let inventory = ModelInventory(providerID: provider.id, modelIDs: ["grok-example"])

    XCTAssertTrue(ModelCatalog.models(for: provider, inventory: inventory).contains { $0.id == "grok-example" })
  }

  func testOpenCodeDiscoveryUsesOnlyTheRequestedProvider() {
    let output = "opencode-go/model-a\nopencode/model-b\nopencode-go/model-c"

    XCTAssertEqual(
      ModelInventoryService.modelIDs(fromOpenCodeOutput: output, providerID: "opencode-go"),
      ["model-a", "model-c"]
    )
  }
}
