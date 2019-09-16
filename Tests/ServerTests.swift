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
		let server = Server(baseURL: URL(string: "https://api.io")!)
		XCTAssertEqual("https://api.io/", server.baseURL.absoluteString)
		XCTAssertEqual("https://api.io", server.aud)
		
		let metaURL = Bundle(for: type(of: self)).url(forResource: "metadata", withExtension: "")
		XCTAssertNotNil(metaURL, "Need file `metadata` for unit tests")
		let metaData = try? Data(contentsOf: metaURL!)
		let meta = try JSONSerialization.jsonObject(with: metaData!, options: []) as! FHIRJSON
		XCTAssertNotNil(meta, "Should parse `metadata`")
//		let cabability = try? CapabilityStatement(json: meta)
		
		// capability var is not visible using Swift Package Manager
//		server.cabability = cabability
//		XCTAssertNotNil(server.cabability, "Should store all metadata")
    }
	
	func testMetadataFailing() {
		var server = Server(baseURL: URL(string: "https://api.ioio")!)		// invalid TLD, so requesting from .ioio should definitely fail
		let exp1 = self.expectation(description: "Metadata fetch expectation 1")
		server.getCapabilityStatement() { error in
			XCTAssertNotNil(error, "Must raise an error when fetching metatada fails")
			exp1.fulfill()
		}
		
		let fileURL = URL(fileURLWithPath: "\(#file)").deletingLastPathComponent()
		server = Server(baseURL: fileURL)
		let exp2 = self.expectation(description: "Metadata fetch expectation 2")
		server.getCapabilityStatement() { error in
			XCTAssertNil(error, "Expecting filesystem-fetching to succeed")
			XCTAssertNotNil(server.auth, "Server is OAuth2 protected, must have `Auth` instance")
			if let auth = server.auth {
				XCTAssertTrue(auth.type == AuthType.codeGrant, "Should use code grant auth type, not \(server.auth!.type.rawValue)")
				XCTAssertNotNil(auth.settings, "Server `Auth` instance must have settings dictionary")
				XCTAssertNotNil(auth.settings?["token_uri"], "Must read token_uri")
				XCTAssertEqual(auth.settings?["token_uri"] as? String, "https://authorize.smarthealthit.org/token", "token_uri must be “https://authorize.smarthealthit.org/token”")
			}
			exp2.fulfill()
		}
		
		waitForExpectations(timeout: 20, handler: nil)
	}
}

