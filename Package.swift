// swift-tools-version:5.0
//  Package.swift
//
//  Created by Dave Carlson on 8/8/19.

import PackageDescription

let package = Package(
    name: "SMART",
	platforms: [
		.macOS(.v10_13), .iOS(.v11)
	],
    products: [
        .library(
            name: "SMART",
            targets: ["SMART"]),
    ],
    dependencies: [
		.package(url: "https://github.com/smart-on-fhir/Swift-FHIR", "4.2.0"..<"5.0.0"),
		.package(url: "https://github.com/p2/OAuth2", "5.1.0"..<"6.0.0"),
    ],
    targets: [
		.target(
			name: "SMART",
			dependencies: [
				.product(name: "OAuth2"),
				.product(name: "FHIR"),
			],
			path: "Sources",
			sources: ["SMART", "Client", "iOS", "macOS"]),
    ]
)
