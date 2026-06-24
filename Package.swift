// swift-tools-version: 6.0

import PackageDescription
import CompilerPluginSupport

let package = Package(
    name: "cucumber-swift",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "CucumberSwift",
            targets: ["CucumberSwift"]),
    ],
    dependencies: [.package(url: "https://github.com/AnarchoSystems/swift-gherkin.git",
                            exact: "0.1.0"),
                   .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "600.0.0"),
    ],
    targets: [
        .macro(name: "CukeMacros",
               dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax")
               ]),
        .target(name: "CucumberSwift",
                dependencies: [.product(name: "SwiftSyntax", package: "swift-syntax"),
                       .product(name: "Gherkin", package: "swift-gherkin"),
                               "CukeMacros"]),
        .testTarget(name: "cucumber-swiftTests",
                    dependencies: ["CucumberSwift"],
                    resources: [.process("Test.feature")])
    ]
)
