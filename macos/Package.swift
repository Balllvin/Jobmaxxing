// swift-tools-version: 5.9
import PackageDescription

let package = Package(
  name: "JobmaxxingMac",
  platforms: [.macOS(.v14)],
  products: [
    .executable(name: "Jobmaxxing", targets: ["Jobmaxxing"])
  ],
  dependencies: [],
  targets: [
    .executableTarget(
      name: "Jobmaxxing",
      path: "Sources/Jobmaxxing",
      linkerSettings: [.linkedLibrary("sqlite3")]
    ),
    .testTarget(
      name: "JobmaxxingTests",
      dependencies: ["Jobmaxxing"],
      path: "Tests/JobmaxxingTests"
    )
  ]
)
