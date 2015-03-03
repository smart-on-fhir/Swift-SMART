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
			if let extensions = conformance?.rest?.first?.security?.fhirExtension {
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
		requestJSON(path, auth: auth, callback: callback)
	}
	
	/**
		Requests JSON data from `path`, which is relative to the server's `baseURL`, using a signed request if `auth` is
		provided.
	
		The callback is always dispatched to the main queue.
	 */
	func requestJSON(path: String, auth: Auth?, callback: ((json: NSDictionary?, error: NSError?) -> Void)) {
		let headers = [
			"Accept": "application/fhir+json, application/json",
			"Accept-Charset": "UTF-8",
		]
		
		requestData(path, auth: auth, headers: headers) { (data, error) -> Void in
			if nil != error || nil == data {
				callback(json: nil, error: error)
			}
			else {
				var finalError: NSError?
				let json = NSJSONSerialization.JSONObjectWithData(data!, options: nil, error: &finalError) as? NSDictionary
				if nil != json {
					logIfDebug("Did receive valid JSON data")
				}
				else {
					let jsstring = NSString(data: data!, encoding: NSUTF8StringEncoding)
					finalError = genSMARTError("Failed to deserialize JSON into a dictionary: \(finalError!.localizedDescription)\n\(jsstring)", nil)
				}
				dispatch_sync(dispatch_get_main_queue()) {
					callback(json: json, error: finalError)
				}
			}
		}
	}
	
	/**
		Request data from the given path, assumed to be relative to the server's base URL.
		
		@attention The callback is NOT necessarily being called on the main thread to allow further data processing on
		the background queue, should the request succeed.
	 */
	func requestData(path: String, auth: Auth?, headers: [String: String]?, callback: ((data: NSData?, error: NSError?) -> Void)) {
		if let url = NSURL(string: path, relativeToURL: baseURL) {
			requestData(url, auth: auth, headers: headers, callback: callback)
		}
		else {
			callback(data: nil, error: genSMARTError("Failed to create a URL with path \(path) on base \(baseURL)", nil))
		}
	}
	
	/**
		Request data from the given URL.
		
		@attention The callback is NOT necessarily being called on the main thread to allow further data processing on
		the background queue, should the request succeed.
	*/
	func requestData(url: NSURL, auth: Auth?, headers: [String: String]?, callback: ((data: NSData?, error: NSError?) -> Void)) {
		let request = auth?.signedRequest(url) ?? NSMutableURLRequest(URL: url)
		if nil != headers {
			for (key, val) in headers! {
				request.setValue(val, forHTTPHeaderField: key)
			}
		}
		requestData(request, callback: callback)
	}
	
	/**
		Request data with the given request.
		
		@attention The callback is NOT necessarily being called on the main thread to allow further data processing on
		the background queue, should the request succeed.
	*/
	func requestData(request: NSURLRequest, callback: ((data: NSData?, error: NSError?) -> Void)) {
		let task = defaultSession().dataTaskWithRequest(request) { data, response, error in
			var finalError: NSError?
			
			if nil != error {
				finalError = error
			}
			else if nil != response && nil != data {
				if let http = response as? NSHTTPURLResponse {
					if http.statusCode < 400 {
						logIfDebug("Did load data with status code \(http.statusCode)")
						callback(data: data, error: nil)
						return
					}
					
					let errstr = NSHTTPURLResponse.localizedStringForStatusCode(http.statusCode)
					finalError = genSMARTError(errstr, http.statusCode)
				}
				else {
					finalError = genSMARTError("Not an HTTP response", nil)
				}
			}
			else {
				finalError = genSMARTError("No data received", nil)
			}
			
			if let err = finalError?.localizedDescription {
				logIfDebug("Failed to load data: \(err)")
			}
			else {
				logIfDebug("Failed to load data")
			}
			
			callback(data: nil, error: finalError)
		}
		
		logIfDebug("Requesting data from \(request.URL)")
		task.resume()
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

