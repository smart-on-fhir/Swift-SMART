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
open class PatientListQuery {
	
	/// The FHIR search element that produces the desired patient list
	open let search: FHIRSearch
	
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
	
	func execute(onServer server: FHIRServer, order: PatientListOrder, callback: @escaping (Bundle?, FHIRError?) -> Void) {
		if isDone {
			callback(nil, nil)
			return
		}
		
		let cb: (Bundle?, FHIRError?) -> Void = { bundle, error in
			if nil != error || nil == bundle {
				callback(nil, error)
			}
			else {
				self.isDone = !self.search.hasMore
				callback(bundle, nil)
			}
		}
		
		// starting fresh, add sorting and page count URL parameters
		if !isDone && !search.hasMore {
			search.sort = order.rawValue
			search.perform(server, callback: cb)
		}
		
		// get next page of results
		else {
			search.nextPage(server, callback: cb)
		}
	}
}

