//
//  ServerTests.swift
//  SMART-on-FHIR
//
//  Created by Pascal Pfiffner on 6/23/14.
//  2014, SMART Health IT.
//

import XCTest

@testable
import SMART


class ServerTests: XCTestCase {
	
	func testMetadataParsing() throws {
		let server = Server(base: "https://api.io")
		XCTAssertEqual("https://api.io/", server.baseURL.absoluteString)
		XCTAssertEqual("https://api.io", server.aud)
		
		let metaURL = Bundle(for: type(of: self)).url(forResource: "metadata", withExtension: "")
		XCTAssertNotNil(metaURL, "Need file `metadata` for unit tests")
		let metaData = try? Data(contentsOf: metaURL!)
		let meta = try JSONSerialization.jsonObject(with: metaData!, options: []) as! FHIRJSON
		XCTAssertNotNil(meta, "Should parse `metadata`")
		let conformance = Conformance(json: meta)
		
		server.conformance = conformance
		XCTAssertNotNil(server.conformance, "Should store all metadata")
    }
	
	func testMetadataLoading() {
		var server = Server(base: "https://api.ioio")		// invalid TLD, so this should definitely fail
		let exp1 = self.expectation(description: "Metadata fetch expectation 1")
		server.getConformance { error in
			XCTAssertNotNil(error, "Must raise an error when fetching metatada fails")
			exp1.fulfill()
		}
		
		let fileURL = URL(fileURLWithPath: "\(#file)".smart_deletingLastPathComponent)
		server = Server(baseURL: fileURL)
		let exp2 = self.expectation(description: "Metadata fetch expectation 2")
		server.getConformance { error in
			XCTAssertNil(error, "Expecting filesystem-fetching to succeed")
			XCTAssertNotNil(server.auth, "Server is OAuth2 protected, must have `Auth` instance")
			if let auth = server.auth {
				XCTAssertTrue(auth.type == AuthType.codeGrant, "Should use code grant auth type, not \(server.auth!.type.rawValue)")
				XCTAssertNotNil(auth.settings, "Server `Auth` instance must have settings dictionary")
				XCTAssertNotNil(auth.settings?["token_uri"], "Must read token_uri")
				XCTAssertEqual(auth.settings?["token_uri"] as? String, "https://authorize-dstu2.smarthealthit.org/token", "token_uri must be “https://authorize-dstu2.smarthealthit.org/token”")
			}
			exp2.fulfill()
		}
		
		waitForExpectations(timeout: 20, handler: nil)
	}
}


extension String {
	
	func smart_appendingPathComponent(_ part: String) -> String {
		return (self as NSString).appendingPathComponent(part)
	}
	
	var smart_deletingLastPathComponent: String {
		return (self as NSString).deletingLastPathComponent
	}
}

