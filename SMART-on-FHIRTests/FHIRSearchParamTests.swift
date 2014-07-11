//
//  FHIRSearchParamTests.swift
//  SMART-on-FHIR
//
//  Created by Pascal Pfiffner on 7/11/14.
//  Copyright (c) 2014 SMART Platforms. All rights reserved.
//

import XCTest
import SMART


class FHIRSearchParamTests: XCTestCase {
	
    func testConstruction() {
		let first = FHIRSearchParam(profileType: "Test")
		XCTAssertEqualObjects("Test", first.construct())
		
		let second = FHIRSearchParam(subject: "subject", string: "Alex")
		second.previous = first
		XCTAssertTrue(second === first.next!, "Expecting correct chaining")
		XCTAssertTrue(second === first.last(), "Expecting correct chaining")
		XCTAssertEqualObjects("Test?subject=Alex", second.construct())
		
		let third = FHIRSearchParam(subject: "bday", date: "1982-10-15")
		third.previous = second
		XCTAssertTrue(third === first.next!.next!, "Expecting correct chaining")
		XCTAssertTrue(third === first.last(), "Expecting correct chaining")
		XCTAssertEqualObjects("Test?subject=Alex&bday=1982-10-15", first.last().construct())
		XCTAssertEqualObjects("Test?subject=Alex&bday=1982-10-15", third.construct())
		
		let fourth = FHIRSearchParam(subject: "bday", missing: false)
		second.next = fourth
		XCTAssertNil(third.previous, "Must break chain")
		XCTAssertTrue(first === fourth.previous!.previous!, "Must re-chain correctly")
		XCTAssertTrue(fourth === first.last(), "Must re-chain correctly")
		XCTAssertEqualObjects("Test?subject=Alex&bday:missing=false", first.last().construct())
		XCTAssertEqualObjects("Test?subject=Alex&bday:missing=false", fourth.construct())
    }
	
	func testExtensions() {
		let test = FHIRSearchParam(profileType: "Condition")
		XCTAssertEqualObjects("Condition", test.construct())
		
		let first = Condition.search()
		XCTAssertEqualObjects("Condition", first.construct())
		
		let second = first.dateAsserted("2014-03")
		XCTAssertTrue(first === second.previous!, "Must chain correctly")
		XCTAssertEqualObjects("Condition?date-asserted=2014-03", second.construct())
		XCTAssertEqualObjects("Condition?date-asserted=2014-03", first.last().construct())
		
		// TODO: add more
	}
}

