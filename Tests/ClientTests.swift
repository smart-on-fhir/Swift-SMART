//
//  SMART_on_FHIR_iOSTests.swift
//  SMART-on-FHIR-iOSTests
//
//  Created by Pascal Pfiffner on 6/20/14.
//  2014, SMART Platforms.
//

import XCTest
import SMART


class ClientTests: XCTestCase {
	
	func testInit() {
		let client = Client(baseURL: "https://api.io", settings: ["cliend_id": "client", "redirect": "oauth://callback"])
		XCTAssertTrue(client.server.baseURL.absoluteString == "https://api.io/")

//		//XCTAssertNil(client.auth.clientId, "clientId will only be queryable once we have an OAuth2 instance")
		client.ready { error in
			XCTAssertNil(error)
		}
    }
}

