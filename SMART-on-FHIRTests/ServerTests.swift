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
	
	func testMetadataParsing() {
		let server = Server(base: "https://api.io")
		XCTAssertTrue("https://api.io" == server.baseURL.absoluteString)
		
		// TODO: How to use NSBundle(forClass)?
		let metaURL = NSBundle(path: __FILE__.stringByDeletingLastPathComponent)!.URLForResource("metadata", withExtension: "")
		XCTAssertNotNil(metaURL, "Need metadata.json for unit tests")
		let metaData = NSData(contentsOfURL: metaURL!)
		let meta = NSJSONSerialization.JSONObjectWithData(metaData!, options: nil, error: nil) as JSONDictionary
		XCTAssertNotNil(meta, "Should parse metadata.json")
		let conformance = Conformance(json: meta)
		
		server.conformance = conformance
		XCTAssertNotNil(server.conformance, "Should store all metadata")
//		XCTAssertNotNil(server.registrationURL, "Should parse registration URL")
//		XCTAssertNotNil(server.authURL, "Should parse authorize URL")
//		XCTAssertNotNil(server.tokenURL, "Should parse token URL")
    }
	
	func testMetadataLoading() {
		var server = Server(base: "https://api.ioio")		// invalid TLD, so this should definitely fail
		let exp1 = self.expectationWithDescription("Metadata fetch expectation 1")
		server.getConformance { error in
			XCTAssertNotNil(error, "Must raise an error when fetching metatada fails")
			exp1.fulfill()
		}
		
		let fileURL = NSURL(fileURLWithPath: __FILE__.stringByDeletingLastPathComponent)!
		server = Server(baseURL: fileURL)
		let exp2 = self.expectationWithDescription("Metadata fetch expectation 2")
		server.getConformance { error in
			XCTAssertNotNil(error, "Expecting non-HTTP error")
			XCTAssertTrue("Not an HTTP response" == error!.localizedDescription, "Expecting specific error message")
			exp2.fulfill()
		}
		
		waitForExpectationsWithTimeout(20, handler: nil)
	}
}

