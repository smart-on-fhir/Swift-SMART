//
//  ServerTests.swift
//  SMART-on-FHIR
//
//  Created by Pascal Pfiffner on 6/23/14.
//  Copyright (c) 2014 SMART Platforms. All rights reserved.
//

import XCTest
import SMART


class ServerTests: XCTestCase {
	
	func testMetadata() {
		let server = Server(base: "https://api.io")
		XCTAssertTrue("https://api.io" == server.baseURL.absoluteString)
		XCTAssertNil(server.authURL)
		
		// TODO: How to use NSBundle(forClass)?
		let metaURL = NSBundle(path: __FILE__.stringByDeletingLastPathComponent).URLForResource("metadata", withExtension: "json")
		XCTAssertNotNil(metaURL, "Need metadata.json for unit tests")
		let metaData = NSData(contentsOfURL: metaURL)
		let meta = NSJSONSerialization.JSONObjectWithData(metaData, options: nil, error: nil) as NSDictionary
		XCTAssertNotNil(meta, "Should parse metadata.json")
		
		server.metadata = meta
		XCTAssertNotNil(server.metadata, "Should store all metadata")
		XCTAssertNotNil(server.registrationURL, "Should parse registration URL")
		XCTAssertNotNil(server.authURL, "Should parse authorize URL")
		XCTAssertNotNil(server.tokenURL, "Should parse token URL")
    }
}
