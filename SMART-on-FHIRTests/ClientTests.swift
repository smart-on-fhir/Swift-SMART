//
//  SMART_on_FHIR_iOSTests.swift
//  SMART-on-FHIR-iOSTests
//
//  Created by Pascal Pfiffner on 6/20/14.
//  Copyright (c) 2014 SMART Platforms. All rights reserved.
//

import XCTest
import SMART


class ClientTests: XCTestCase {
	
	func testInit() {
		let client = Client(serverURL: "https://api.io", clientId: "client", clientSecret: nil)
		XCTAssertTrue(client.server.baseURL.absoluteString == "https://api.io")
		
		XCTAssertNil(client.auth.clientId, "clientId will only be queryable once we have an OAuth2 instance")
		client.ready { error in
			println(error?.localizedDescription)
		}
    }
    
//    func testPerformanceExample() {
//        // This is an example of a performance test case.
//        self.measureBlock() {
//            // Put the code you want to measure the time of here.
//        }
//    }
}

