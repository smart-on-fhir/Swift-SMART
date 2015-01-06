//
//  Server.swift
//  SMART-on-FHIR
//
//  Created by Pascal Pfiffner on 6/11/14.
//  Copyright (c) 2014 SMART Platforms. All rights reserved.
//

import Foundation


/**
	Representing the FHIR resource server a client connects to.
 */
public class Server: FHIRServer
{
	/// The server's base URL.
	public let baseURL: NSURL
	
	/// The authorization to use with the server.
	var auth: Auth?
	
	/// Settings to be applied to the Auth instance.
	var authSettings: NSDictionary?
	
	/// The active URL session.
	var session: NSURLSession?
	
	
	public init(baseURL: NSURL, auth: NSDictionary? = nil) {
		self.baseURL = baseURL
		self.authSettings = auth
	}
	
	public convenience init(base: String, auth: NSDictionary? = nil) {
		self.init(baseURL: NSURL(string: base)!, auth: auth)			// yes, this will crash on invalid URL
	}
	
	
	// MARK: - Server Conformance
	
	/// The server's conformance statement. Must be implicitly fetched using `getConformance()`
	public var conformance: Conformance? {							// `public` to enable unit testing
		didSet {
			
			// TODO: we only look at the first "rest" entry, should we support multiple endpoints?
			if let security = conformance?.rest?.first?.security {
				auth = Auth.fromConformanceSecurity(security, settings: authSettings)
			}
			
			// if we have not yet initialized an Auth object we'll use one for "no auth"
			if nil == auth {
				auth = Auth(type: .None, settings: authSettings)
			}
		}
	}
	
	/**
		Executes a `read` action against the server's "metadata" path, which should return a Conformance statement.
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
	
	
	// MARK: - Auth Status
	
	/** Ensures that the server is ready to perform requests before calling the callback. */
	public func ready(callback: (error: NSError?) -> ()) {
		if nil != auth {
			callback(error: nil)
			return
		}
		
		// if we haven't initialized the auth instance we likely didn't fetch the server metadata yet
		getConformance { error in
			if nil != error {
				callback(error: error)
			}
			else if nil != self.auth {
				callback(error: nil)
			}
			else {
				callback(error: genSMARTError("Failed to detect the authorization method from server metadata", 0))
			}
		}
	}
	
	/** Ensures that the receiver is ready, then calls the auth method's `authorize()` method. */
	public func authorize(useWebView: Bool, callback: (patient: Patient?, error: NSError?) -> ()) {
		self.ready { error in
			if nil != error {
				callback(patient: nil, error: error)
			}
			else if nil == self.auth {
				callback(patient: nil, error: genSMARTError("Client error, no auth instance created", 0))
			}
			else {
				self.auth!.authorize(useWebView) { patientId, error in
					if nil != error || nil == patientId {
						callback(patient: nil, error: error)
					}
					else {
						Patient.read(patientId!, server: self) { resource, error in
							logIfDebug("Did read patient \(resource) with error \(error)")
							callback(patient: resource as? Patient, error: error)
						}
					}
				}
			}
		}
	}
	
	public func handleRedirect(redirect: NSURL) -> Bool {
		if nil != auth {
			return auth!.handleRedirect(redirect)
		}
		return false
	}
	
	
	// MARK: - Requests
	
	/**
		Request a JSON resource at the given path from the server, forwards to ``.
	
		:param: path The path relative to the server's base URL to request
		:param: callback The callback to execute once the request finishes
	*/
	public func requestJSON(path: String, callback: ((json: JSONDictionary?, error: NSError?) -> Void)) {
		requestJSON(path, auth: auth, callback: callback)
	}
	
	/**
		Requests JSON data from `path`, which is relative to the server's `baseURL`, using a signed request if `auth` is
		provided.
	
		:param: path The path relative to the server's base URL to request
		:param: auth The Auth instance to use for authentication purposes
		:param: callback The callback to execute once the request finishes, always dispatched to the main queue.
	 */
	func requestJSON(path: String, auth: Auth?, callback: ((json: JSONDictionary?, error: NSError?) -> Void)) {
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
							if let json = NSJSONSerialization.JSONObjectWithData(data, options: nil, error: &finalError) as? JSONDictionary {
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
		if nil != auth {
			auth!.abort()
		}
		
		if nil != session {
			session!.invalidateAndCancel()
			session = nil
		}
	}
}

