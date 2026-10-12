// swift-tools-version: 6.3
// Copyright (c) 2026 Zaid Rahhawi
// SPDX-License-Identifier: MIT
// See LICENSE for license information.

import PackageDescription

let swiftSettings: [SwiftSetting] = [
    // https://github.com/apple/swift-evolution/blob/main/proposals/0335-existential-any.md
    .enableUpcomingFeature("ExistentialAny"),

    // https://github.com/swiftlang/swift-evolution/blob/main/proposals/0444-member-import-visibility.md
    .enableUpcomingFeature("MemberImportVisibility"),

    // https://github.com/swiftlang/swift-evolution/blob/main/proposals/0409-access-level-on-imports.md
    .enableUpcomingFeature("InternalImportsByDefault"),

    // https://github.com/swiftlang/swift-evolution/blob/main/proposals/0461-async-function-isolation.md
    .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
]

let package = Package(
    name: "swift-operation-context",
    platforms: [
        // Supported runtime baseline; individual concurrency primitives may support older OSes.
        .macOS(.v15)
    ],
    products: [
        .library(
            name: "OperationContext",
            targets: ["OperationContext"]
        )
    ],
    targets: [
        .target(
            name: "OperationContext",
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "OperationContextTests",
            dependencies: [
                .target(name: "OperationContext")
            ],
            swiftSettings: swiftSettings
        ),
    ],
    swiftLanguageModes: [.v6]
)
