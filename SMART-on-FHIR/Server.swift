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
public class Server: FHIRServer {
	
	/** The server base URL. */
	public let baseURL: NSURL
	
	/** The authorization to use with the server. */
	var auth: Auth?
	
	public init(baseURL: NSURL) {
		self.baseURL = baseURL
	}
	
	public convenience init(base: String) {
		self.init(baseURL: NSURL(string: base)!)					// yes, this will crash on invalid URL
	}
	
	
	// MARK: - Server Metadata
	
	public var registrationURL: NSURL?
	public var authURL: NSURL?
	public var tokenURL: NSURL?
	
	var session: NSURLSession?
	
	public var metadata: NSDictionary? {							// `public` to enable unit testing
		didSet(oldMeta) {
			if nil != metadata {
				
				// extract OAuth2 endpoint URLs from rest[0].security.extension[#].valueUri
				if let rest = metadata!["rest"] as? NSArray {
					if let security = rest.firstObject?["security"] as? NSDictionary {
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
	
	public func getMetadata(callback: (error: NSError?) -> ()) {		// `public` to enable unit testing
		if nil != metadata {
			callback(error: nil)
			return
		}
		
		// not yet fetched, fetch it
		requestJSONUnsigned("metadata") { json, error in
			if nil != error {
				callback(error: error)
			}
			else if nil != json {
				self.metadata = json
				callback(error: nil)
			}
		}
	}
	
	
	// MARK: - Requests
	
	public func requestJSON(path: String, callback: ((json: NSDictionary?, error: NSError?) -> Void)) {
		if nil == auth {
			callback(json: nil, error: genSMARTError("The server does not yet have an auth instance, cannot perform a signed request", 700))
			return
		}
		
		performJSONRequest(path, auth: auth!, callback: callback)
	}
	
	func requestJSONUnsigned(path: String, callback: ((json: NSDictionary?, error: NSError?) -> Void)) {
		performJSONRequest(path, auth: nil, callback: callback)
	}
	
	/**
	 *  Requests JSON data from `path`, which is relative to the server's `baseURL`, using a signed request if `auth` is
	 *  provided.
	 *
	 *  The callback is always dispatched to the main queue.
	*/
	func performJSONRequest(path: String, auth: Auth?, callback: ((json: NSDictionary?, error: NSError?) -> Void)) {
		if let url = NSURL(string: path, relativeToURL: baseURL) {
			let req = nil != auth ? auth!.signedRequest(url) : NSMutableURLRequest(URL: url)
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

