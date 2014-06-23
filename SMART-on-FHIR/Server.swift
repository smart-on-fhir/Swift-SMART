//
//  Server.swift
//  SMART-on-FHIR
//
//  Created by Pascal Pfiffner on 6/11/14.
//  Copyright (c) 2014 SMART Platforms. All rights reserved.
//

import Foundation

/*!
 *  Representing the FHIR resource server a client connects to.
 */
class Server {
	
	/*! The server base. */
	let baseURL: NSURL
	
	init(base: String) {
		baseURL = NSURL(string: base)
	}
	
	
	// MARK: Server Metadata
	
	var registrationURL: NSURL?
	var authURL: NSURL?
	var tokenURL: NSURL?
	
	var metadata: NSDictionary? {
	didSet(oldMeta) {
		if metadata {
			
			// extract OAuth2 endpoint URLs from rest[0].security.extension[#].valueUri
			if let rest = metadata!["rest"] as? NSArray {
				if let security = rest[0]?["security"] as? NSDictionary {
					if let extensions = security["extension"] as? NSArray {
						for obj: AnyObject in extensions {
							if let ext = obj as? NSDictionary {
								if let url = ext["url"] as? NSString {
									switch url {
									case "http://fhir-registry.smartplatforms.org/Profile/oauth-uris#register":
										registrationURL = NSURL(string: ext["valueUri"] as NSString)
									case "http://fhir-registry.smartplatforms.org/Profile/oauth-uris#authorize":
										authURL = NSURL(string: ext["valueUri"] as NSString)
									case "http://fhir-registry.smartplatforms.org/Profile/oauth-uris#token":
										tokenURL = NSURL(string: ext["valueUri"] as NSString)
									default:
										break
									}
								}
							}
						}
					}
				}
			}
		}
	}
	}
	
	func getMetadata(callback: (error: NSError?) -> ()) {
		if metadata {
			callback(error: nil)
			return
		}
		
		// not yet fetched, fetch it
		let url = baseURL.URLByAppendingPathComponent("metadata")
		logIfDebug("Requesting server metadata from \(url)")
		
		let req = NSMutableURLRequest(URL: url)
		req.setValue("application/json", forHTTPHeaderField: "Content-Type")
		NSURLConnection.sendAsynchronousRequest(req, queue: NSOperationQueue.mainQueue(), completionHandler: { response, data, error in
			var finalError: NSError?
			
			if error {
				finalError = error
			}
			else if response {
				if data {				// Swift compiler bug, cannot test two implicitly unwrapped optionals with `&&`
					if let http = response as? NSHTTPURLResponse {
						if 200 == http.statusCode {
							if let json = NSJSONSerialization.JSONObjectWithData(data, options: nil, error: &finalError) as? NSDictionary {
								self.metadata = json
								logIfDebug("Did receive metadata")
								callback(error: nil)
								return
							}
						}
					}
				}
			}
			
			// if we're still here an error must have happened
			if !finalError {
				finalError = NSError(domain: NSCocoaErrorDomain, code: 0, userInfo: [NSLocalizedDescriptionKey: "Unknown connection error"])
			}
			
			callback(error: finalError)
		})
	}
}
