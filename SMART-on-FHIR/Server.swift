//
//  Server.swift
//  SMART-on-FHIR
//
//  Created by Pascal Pfiffner on 6/11/14.
//  Copyright (c) 2014 SMART Platforms. All rights reserved.
//

import Foundation


/**
 *  Representing the FHIR resource server a client connects to.
 */
public class Server: FHIRServer
{
	/// The server's base URL.
	public let baseURL: NSURL
	
	/// The authorization to use with the server.
	var auth: Auth?
	
	public init(baseURL: NSURL) {
		self.baseURL = baseURL
	}
	
	public convenience init(base: String) {
		self.init(baseURL: NSURL(string: base)!)				// yes, this will crash on invalid URL
	}
	
	
	// MARK: - Server Conformance
	
	public var registrationURL: NSURL?
	public var authURL: NSURL?
	public var tokenURL: NSURL?
	
	var session: NSURLSession?
	
	/// The server's conformance statement. Must be implicitly fetched using `getConformance()`
	public var conformance: Conformance? {							// `public` to enable unit testing
		didSet(oldMeta) {
			
			// extract OAuth2 endpoint URLs from rest[0].security.extension[#].valueUri
			// TODO: we only look at the first "rest" entry, should we support multiple endpoints in a way?
			if let security = conformance?.rest?.first?.security {
				
				if let services = security.service {
					for service in services {
						logIfDebug("Server supports REST security via \(service.text ?? nil))")
						if let codings = service.coding {
							for coding in codings {
								logIfDebug("-- \(coding.code) (\(coding.system))")
								// TODO: server needs to support multiple auth systems, should be initialized here automatically
							}
						}
					}
				}
				
				if let extensions = security.fhirExtension {
					for ext in extensions {
						if let urlString = ext.url?.absoluteString {
							switch urlString {
							case "http://fhir-registry.smartplatforms.org/Profile/oauth-uris#register":
								registrationURL = ext.valueUri
							case "http://fhir-registry.smartplatforms.org/Profile/oauth-uris#authorize":
								authURL = ext.valueUri
							case "http://fhir-registry.smartplatforms.org/Profile/oauth-uris#token":
								tokenURL = ext.valueUri
							default:
								break
							}
						}
					}
				}
			}
		}
	}
	
	/**
	 *  Executes a `read` action against the server's "metadata" path, which should return a Conformance statement.
	 */
	public func getConformance(callback: (error: NSError?) -> ()) {		// `public` to enable unit testing
		if nil != conformance {
			callback(error: nil)
			return
		}
		
		// not yet fetched, fetch it
		Conformance.readFrom("metadata", server: self) { resource, error in
			if nil != error {
				callback(error: error)
			}
			else if let conf = resource as? Conformance {
				self.conformance = conf
				callback(error: nil)
			}
			else {
				callback(error: genSMARTError("Conformance.readFrom() did not return a Conformance instance but \(resource)", 0))
			}
		}
	}
	
	
	// MARK: - Requests
	
	public func requestJSON(path: String, callback: ((json: NSDictionary?, error: NSError?) -> Void)) {
		performJSONRequest(path, auth: auth, callback: callback)
	}
	
	/**
	 *  Requests JSON data from `path`, which is relative to the server's `baseURL`, using a signed request if `auth` is
	 *  provided.
	 *
	 *  The callback is always dispatched to the main queue.
	*/
	func performJSONRequest(path: String, auth: Auth?, callback: ((json: NSDictionary?, error: NSError?) -> Void)) {
		if let url = NSURL(string: path, relativeToURL: baseURL) {
			let req = auth?.signedRequest(url) ?? NSMutableURLRequest(URL: url)
			req.setValue("application/json", forHTTPHeaderField: "Accept")
			
			// run on default session
			let task = defaultSession().dataTaskWithRequest(req) { data, response, error in
				var finalError: NSError?
				
				if nil != error {
					finalError = error
				}
				else if nil != response && nil != data {
					if let http = response as? NSHTTPURLResponse {
						if 200 == http.statusCode {
							if let json = NSJSONSerialization.JSONObjectWithData(data, options: nil, error: &finalError) as? NSDictionary {
								logIfDebug("Did receive valid JSON data")
								//logIfDebug("\(json)")
								dispatch_sync(dispatch_get_main_queue()) {
									callback(json: json, error: nil)
								}
								return
							}
							let errstr = "Failed to deserialize JSON into a dictionary: \(NSString(data: data, encoding: NSUTF8StringEncoding))"
							finalError = genSMARTError(errstr, nil)
						}
						else {
							let errstr = NSHTTPURLResponse.localizedStringForStatusCode(http.statusCode)
							finalError = genSMARTError(errstr, http.statusCode)
						}
					}
					else {
						finalError = genSMARTError("Not an HTTP response", nil)
					}
				}
				else {
					finalError = genSMARTError("No data received", nil)
				}
				
				// if we're still here an error must have happened
				if nil == finalError {
					finalError = NSError(domain: NSCocoaErrorDomain, code: 0, userInfo: [NSLocalizedDescriptionKey: "Unknown connection error"])
				}
				
				logIfDebug("Failed to fetch JSON data: \(finalError!.localizedDescription)")
				dispatch_sync(dispatch_get_main_queue()) {
					callback(json: nil, error: finalError)
				}
			}
			
			logIfDebug("Requesting data from \(req.URL)")
			task.resume()
		}
		else {
			let error = genSMARTError("Failed to parse path \(path) relative to base URL \(baseURL)", nil)
			if NSThread.isMainThread() {
				callback(json: nil, error: error)
			}
			else {
				dispatch_sync(dispatch_get_main_queue(), { () -> Void in
					callback(json: nil, error: error)
				})
			}
		}
	}
	
	
	// MARK: - Session Management
	
	func defaultSession() -> NSURLSession {
		if nil == session {
			session = NSURLSession(configuration: NSURLSessionConfiguration.defaultSessionConfiguration())
		}
		return session!
	}
	
	func abortSession() {
		if nil != session {
			session!.invalidateAndCancel()
			session = nil
		}
	}
}

