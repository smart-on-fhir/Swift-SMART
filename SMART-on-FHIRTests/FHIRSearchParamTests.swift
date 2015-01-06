//
//  FHIRSearchParamTests.swift
//  SMART-on-FHIR
//
//  Created by Pascal Pfiffner on 7/11/14.
//  Copyright (c) 2014 SMART Platforms. All rights reserved.
//

import XCTest
import SMART

/*
class FHIRSearchParamTests: XCTestCase {
	
    func testConstruction() {
		let first = FHIRSearchParam(profileType: Patient.self)
		XCTAssertEqual("Patient", first.construct())
		
		let second = FHIRSearchParam(subject: "name", string: "Alex")
		second.previous = first
		XCTAssertTrue(second === first.next!, "Expecting correct chaining")
		XCTAssertTrue(second === first.last(), "Expecting correct chaining")
		XCTAssertEqual("Patient?name=Alex", second.construct())
		
		let third = FHIRSearchParam(subject: "birthdate", date: "1982-10-15")
		third.previous = second
		XCTAssertTrue(third === first.next!.next!, "Expecting correct chaining")
		XCTAssertTrue(third === first.last(), "Expecting correct chaining")
		XCTAssertEqual("Patient?name=Alex&birthdate=1982-10-15", first.last().construct())
		XCTAssertEqual("Patient?name=Alex&birthdate=1982-10-15", third.construct())
		
		let fourth = FHIRSearchParam(subject: "birthdate", missing: false)
		second.next = fourth
		XCTAssertNil(third.previous, "Must break chain")
		XCTAssertTrue(first === fourth.previous!.previous!, "Must re-chain correctly")
		XCTAssertTrue(fourth === first.last(), "Must re-chain correctly")
		XCTAssertEqual("Patient?name=Alex&birthdate:missing=false", first.last().construct())
		XCTAssertEqual("Patient?name=Alex&birthdate:missing=false", fourth.construct())
		
		let fifth = FHIRSearchParam(subject: "gender", tokenAsText: "male")
		fourth.next = fifth
		XCTAssertTrue(fifth === first.last(), "Must re-chain correctly")
		XCTAssertEqual("Patient?name=Alex&birthdate:missing=false&gender:text=male", fifth.construct())
		
		let sixth = FHIRSearchParam(subject: "gender", token: "male")
		fourth.next = sixth
		XCTAssertTrue(sixth === first.last(), "Must re-chain correctly")
		XCTAssertEqual("Patient?name=Alex&birthdate:missing=false&gender=male", sixth.construct())
    }
	
	func testExtensions() {
		let test = FHIRSearchParam(profileType: Condition.self)
		XCTAssertEqual("Condition", test.construct())
		
		let first = Condition.search()
		XCTAssertEqual("Condition", first.construct())
		
		let second = first.dateAsserted("2014-03")
		XCTAssertTrue(first === second.previous!, "Must chain correctly")
		XCTAssertEqual("Condition?date-asserted=2014-03", second.construct())
		XCTAssertEqual("Condition?date-asserted=2014-03", first.last().construct())
		
		XCTAssertEqual("Patient?name=Alex&birthdate=1982-10-15", Patient.search().name("Alex").birthdate("1982-10-15").construct())
		XCTAssertEqual("Patient?name:exact=Alex&birthdate=1982-10-15", Patient.search().name(exact: "Alex").birthdate("1982-10-15").construct())
		XCTAssertEqual("Patient?name:exact=Alex&birthdate=1982-10-15&gender:text=male", Patient.search().name(exact: "Alex").birthdate("1982-10-15").gender(asText: "male").construct())
		
		// TODO: add more
	}
}	//	*/

