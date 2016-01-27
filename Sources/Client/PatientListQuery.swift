//
//  PatientListQuery.swift
//  SMART-on-FHIR
//
//  Created by Pascal Pfiffner on 2/9/15.
//  Copyright (c) 2015 SMART Health IT. All rights reserved.
//

import Foundation


/**
A query that returns a list of patients.
*/
public class PatientListQuery {
	
	/// The FHIR search element that produces the desired patient list
	public let search: FHIRSearch
	
	var isDone = false
	
	
	/** Dedicated initializer. */
	public init(search: FHIRSearch) {
		search.profileType = Patient.self
		self.search = search
	}
	
	
	// MARK: - Server Interaction
	
	func reset() {
		isDone = false
	}
	
	func execute(server: FHIRServer, order: PatientListOrder, callback: (bundle: Bundle?, error: FHIRError?) -> Void) {
		if isDone {
			callback(bundle: nil, error: nil)
			return
		}
		
		let cb: (bundle: Bundle?, error: FHIRError?) -> Void = { bundle, error in
			if nil != error || nil == bundle {
				callback(bundle: nil, error: error)
			}
			else {
				self.isDone = !self.search.hasMore
				callback(bundle: bundle, error: nil)
			}
		}
		
		// starting fresh, add sorting and page count URL parameters
		if !isDone && !search.hasMore {
			var sort = [(String, String)]()
			let parts = order.rawValue.characters.split() { $0 == "," }.map() { String($0) }
			for part in parts {
				let exp = part.characters.split() { $0 == ":" }.map() { String($0) }
				sort.append((exp[0], exp[1]))
			}
			search.sort = sort
			search.perform(server, callback: cb)
		}
		
		// get next page of results
		else {
			search.nextPage(server, callback: cb)
		}
	}
}

