//
//  Server.swift
//  SMART-on-FHIR
//
//  Created by Pascal Pfiffner on 6/11/14.
//  Copyright (c) 2014 SMART Platforms. All rights reserved.
//

import Foundation
import SwiftFHIR


/** Returns an OAuth2Request or NSMutableURLRequest GET with headers set for a correct FHIR request. */
func fhirGETRequest(auth: Auth?, url: NSURL) -> NSMutableURLRequest {
	let req = auth?.signedRequest(url) ?? NSMutableURLRequest(URL: url)
	req.HTTPMethod = "GET"
	req.setValue("application/json+fhir", forHTTPHeaderField: "Accept")
	req.setValue("UTF-8", forHTTPHeaderField: "Accept-Charset")
	
	return req
}

/** Returns an OAuth2Request or NSMutableURLRequest PUT with headers and body set for a correct FHIR request. */
func fhirPUTRequest(auth: Auth?, url: NSURL, body: NSData) -> NSMutableURLRequest {
	let req = auth?.signedRequest(url) ?? NSMutableURLRequest(URL: url)
	req.HTTPMethod = "PUT"
	req.HTTPBody = body
	req.setValue("application/json+fhir; charset=utf-8", forHTTPHeaderField: "Content-Type")
	req.setValue("application/json+fhir", forHTTPHeaderField: "Accept")
	req.setValue("UTF-8", forHTTPHeaderField: "Accept-Charset")
	//let str = NSString(data: body, encoding: NSUTF8StringEncoding)
	//println("-->  PUT  \(str!)")
	
	return req
}


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
			if let conf = resource as? Conformance {
				self.conformance = conf
				callback(error: nil)
			}
			else {
				callback(error: error ?? genSMARTError("Conformance.readFrom() did not return a Conformance instance but \(resource)"))
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
			if nil != self.auth {
				callback(error: nil)
			}
			else {
				callback(error: error ?? genSMARTError("Failed to detect the authorization method from server metadata"))
			}
		}
	}
	
	/** Ensures that the receiver is ready, then calls the auth method's `authorize()` method. */
	public func authorize(useWebView: Bool, callback: (patient: Patient?, error: NSError?) -> ()) {
		self.ready { error in
			if nil != error || nil == self.auth {
				callback(patient: nil, error: error ?? genSMARTError("Client error, no auth instance created"))
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
		Request a JSON resource at the given path from the server using the server's `auth` instance.
	
		:param: path The path relative to the server's base URL to request
		:param: callback The callback to execute once the request finishes
	*/
	public func getJSON(path: String, callback: FHIRServerJSONResponseCallback) {
		getJSON(path, auth: auth, callback: callback)
	}
	
	/**
		Requests JSON data from `path`, which is relative to the server's `baseURL`, using a signed request if `auth` is
		provided.
	
		:param: path The path relative to the server's base URL to request
		:param: auth The Auth instance to use for signing the request
		:param: callback The callback to execute once the request finishes, always dispatched to the main queue.
	 */
	func getJSON(path: String, auth: Auth?, callback: FHIRServerJSONResponseCallback) {
		if let url = NSURL(string: path, relativeToURL: baseURL) {
			let task = defaultSession().dataTaskWithRequest(fhirGETRequest(auth, url)) { data, response, error in
				let res = (nil != response) ? FHIRServerJSONResponse.from(response: response!, data: data) : FHIRServerJSONResponse.noneReceived()
				if nil != error {
					res.error = error
				}
				
				logIfDebug("Server responded with a \(res.status)")
				callOnMainThread {
					callback(response: res)
				}
			}
			
			logIfDebug("Getting data from \(url)")
			task.resume()
		}
		else {
			let res = FHIRServerJSONResponse(notSentBecause: genSMARTError("Failed to parse path \(path) relative to base URL \(baseURL)"))
			callOnMainThread {
				callback(response: res)
			}
		}
	}
	
	/**
		Performs a PUT request against the given path by serializing the body data to JSON and using the receiver's
		`auth` instance to authorize the request
	
		:param: path The path relative to the server's base URL to request
		:param: callback The callback to execute once the request finishes, always dispatched to the main queue.
	 */
	public func putJSON(path: String, body: JSONDictionary, callback: FHIRServerJSONResponseCallback) {
		putJSON(path, auth: auth, body: body, callback: callback)
	}
	
	/**
		Performs a PUT request against the given path by serializing the body data to JSON.
		
		:param: path The path relative to the server's base URL to request
		:param: auth The Auth instance to use for signing the request
		:param: callback The callback to execute once the request finishes, always dispatched to the main queue.
	*/
	func putJSON(path: String, auth: Auth?, body: JSONDictionary, callback: FHIRServerJSONResponseCallback) {
		if let url = NSURL(string: path, relativeToURL: baseURL) {
			
			// serialize JSON
			var error: NSError? = nil
			if let data = NSJSONSerialization.dataWithJSONObject(body, options: nil, error: &error) {
				
				// run on default session
				let task = defaultSession().dataTaskWithRequest(fhirPUTRequest(auth, url, data)) { data, response, error in
					let res = (nil != response) ? FHIRServerJSONResponse.from(response: response!, data: data) : FHIRServerJSONResponse.noneReceived()
					if nil != error {
						res.error = error
					}
					
					logIfDebug("Server responded with a \(res.status)")
					callOnMainThread {
						callback(response: res)
					}
				}
				
				logIfDebug("Putting data to \(url)")
				task.resume()
			}
			else {
				logIfDebug("JSON serialization for \(url) failed")
				callOnMainThread {
					callback(response: FHIRServerJSONResponse(notSentBecause: error!))
				}
			}
		}
		else {
			let res = FHIRServerJSONResponse(notSentBecause: genSMARTError("Failed to parse path \(path) relative to base URL \(baseURL)"))
			callOnMainThread {
				callback(response: res)
			}
		}
	}
	
	public func postJSON(path: String, body: JSONDictionary, callback: FHIRServerJSONResponseCallback) {
		callback(response: FHIRServerJSONResponse(notSentBecause: genSMARTError("POST is not yet implemented")))
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


func callOnMainThread(callback: (Void -> Void)) {
	if NSThread.isMainThread() {
		callback()
	}
	else {
		dispatch_sync(dispatch_get_main_queue(), {
			callback()
		})
	}
}

