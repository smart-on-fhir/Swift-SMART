//
//  FHIRResource+SMART.swift
//  SMART-on-FHIR
//
//  Created by Pascal Pfiffner on 7/3/14.
//  Copyright (c) 2014 SMART Platforms. All rights reserved.
//

import Foundation


extension FHIRResource {
	
	/*!
	 *  Read the resource from the given server.
	 */
	func read(id: String, server: Server, callback: ((resource: FHIRResource?, error: NSError?) -> ())) {
		let url = server.baseURL.URLByAppendingPathComponent(resourceName).URLByAppendingPathComponent(id)
		server.requestJSON(url) { json, error in
			if error {
				println("ERROROROR: \(error!.localizedDescription)")
				callback(resource: nil, error: error)
			}
			else {
				println("Did download JSON: \(json)")
				callback(resource: nil, error: nil)
			}
		}
	}
}
