//
//  Server.swift
//  SMART-on-FHIR
//
//  Created by Pascal Pfiffner on 6/11/14.
//  Copyright (c) 2014 SMART Health IT. All rights reserved.
//

import Foundation


/**
	Representing the FHIR resource server a client connects to.
 */
public class Server: FHIRServer
{
	/// The server's base URL.
	public final let baseURL: NSURL
	
	/// An optional name of the server; will be read from conformance statement unless manually assigned.
	public final var name: String?
	
	/// The authorization to use with the server.
	var auth: Auth?
	
	/// Settings to be applied to the Auth instance.
	var authSettings: OAuth2JSON?
	
	/// The operations the server supports, as specified in the conformance statement.
	var operations: [String: OperationDefinition]?
	var conformanceOperations: [ConformanceRestOperation]?
	
	/// The active URL session.
	var session: NSURLSession?
	
	
	public init(baseURL: NSURL, auth: OAuth2JSON? = nil) {
		self.baseURL = baseURL
		self.authSettings = auth
	}
	
	public convenience init(base: String, auth: OAuth2JSON? = nil) {
		self.init(baseURL: NSURL(string: base)!, auth: auth)			// yes, this will crash on invalid URL
	}
	
	
	// MARK: - Server Conformance
	
	/// The server's conformance statement. Must be implicitly fetched using `getConformance()`
	public var conformance: Conformance? {							// `public` to enable unit testing
		didSet {
			if nil == name && nil != conformance?.name {
				name = conformance!.name
			}
			
			// look at ConformanceRest entries for security and operation information
			if let rests = conformance?.rest {
				var best: ConformanceRest?
				for rest in rests {
					if nil == best {
						best = rest
					}
					else if "client" == rest.mode {
						best = rest
						break
					}
				}
				
				// use the "best" matching rest entry to extract the information we want
				if let rest = best {
					if let security = rest.security {
						auth = Auth.fromConformanceSecurity(security, server: self, settings: authSettings)
					}
					
					// if we have not yet initialized an Auth object we'll use one for "no auth"
					if nil == auth {
						auth = Auth(type: .None, server: self, settings: authSettings)
					}
					
					if let operations = rest.operation {
						conformanceOperations = operations
					}
				}
			}
		}
	}
	
	/**
		Executes a `read` action against the server's "metadata" path, which should return a Conformance statement.
	
		Is public to enable unit testing.
	 */
	public final func getConformance(callback: (error: NSError?) -> ()) {
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
	
	
	// MARK: - Authorization
	
	/**
		Ensures that the server is ready to perform requests before calling the callback.
	 */
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
	
	/**
		Ensures that the receiver is ready, then calls the auth method's `authorize()` method.
	 */
	public func authorize(authProperties: SMARTAuthProperties, callback: (patient: Patient?, error: NSError?) -> ()) {
		self.ready { error in
			if nil != error || nil == self.auth {
				callback(patient: nil, error: error ?? genSMARTError("Client error, no auth instance created"))
			}
			else {
				self.auth!.authorize(authProperties) { parameters, error in
					if nil != error {
						callback(patient: nil, error: error)
					}
					else if let patientId = parameters?["patient"] as? String {
						if let patient = parameters?["patient_resource"] as? Patient {
							callback(patient: patient, error: nil)
						}
						else {
							Patient.read(patientId, server: self) { resource, error in
								logIfDebug("Did read patient \(resource) with error \(error)")
								callback(patient: resource as? Patient, error: error)
							}
						}
					}
					else {
						callback(patient: nil, error: nil)
					}
				}
			}
		}
	}
	
	
	// MARK: - Requests
	
	/**
		Request a JSON resource at the given path from the server using the server's `auth` instance.
	
		:param: path The path relative to the server's base URL to request
		:param: callback The callback to execute once the request finishes
	 */
	public func getJSON(path: String, callback: ((response: FHIRServerJSONResponse) -> Void)) {
		getJSON(path, auth: auth, callback: callback)
	}
	
	/**
		Requests JSON data from `path`, which is relative to the server's `baseURL`, using a signed request if `auth` is
		provided.
	
		:param: path The path relative to the server's base URL to request
		:param: auth The Auth instance to use for signing the request
		:param: callback The callback to execute once the request finishes, always dispatched to the main queue.
	 */
	func getJSON(path: String, auth: Auth?, callback: ((response: FHIRServerJSONResponse) -> Void)) {
		let handler = FHIRServerJSONRequestHandler(.GET)
		if let url = NSURL(string: path, relativeToURL: baseURL) {
			let request = auth?.signedRequest(url) ?? NSMutableURLRequest(URL: url)
			performRequest(request, handler: handler) { response in
				callOnMainThread() {
					callback(response: response as! FHIRServerJSONResponse)
				}
			}
		}
		else {
			let res = handler.notSent("Failed to parse path \(path) relative to base URL \(baseURL)")
			callOnMainThread {
				callback(response: res as! FHIRServerJSONResponse)
			}
		}
	}
	
	/**
		Performs a PUT request against the given path by serializing the body data to JSON and using the receiver's
		`auth` instance to authorize the request
	
		:param: path The path relative to the server's base URL to request
		:param: callback The callback to execute once the request finishes, always dispatched to the main queue.
	 */
	public func putJSON(path: String, body: FHIRJSON, callback: ((response: FHIRServerJSONResponse) -> Void)) {
		putJSON(path, auth: auth, body: body, callback: callback)
	}
	
	/**
		Performs a PUT request against the given path by serializing the body data to JSON.
		
		:param: path The path relative to the server's base URL to request
		:param: auth The Auth instance to use for signing the request
		:param: callback The callback to execute once the request finishes, always dispatched to the main queue.
	*/
	func putJSON(path: String, auth: Auth?, body: FHIRJSON, callback: ((response: FHIRServerJSONResponse) -> Void)) {
		let handler = FHIRServerJSONRequestHandler(.PUT, json: body)
		if let url = NSURL(string: path, relativeToURL: baseURL) {
			let request = auth?.signedRequest(url) ?? NSMutableURLRequest(URL: url)
			performRequest(request, handler: handler) { response in
				callOnMainThread() {
					callback(response: response as! FHIRServerJSONResponse)
				}
			}
		}
		else {
			let res = handler.notSent("Failed to parse path \(path) relative to base URL \(baseURL)")
			callOnMainThread {
				callback(response: res as! FHIRServerJSONResponse)
			}
		}
	}
	
	public func postJSON(path: String, body: FHIRJSON, callback: ((response: FHIRServerJSONResponse) -> Void)) {
		callback(response: FHIRServerJSONResponse(notSentBecause: genSMARTError("POST is not yet implemented")))
	}
	
	/**
		Method to execute a given request with a given request/response handler.
	
		:param: request The URL request to perform
		:param: handler The RequestHandler that prepares the request and processes the response
		:param: callback The callback to execute; will NOT be performed on the main thread!
	 */
	func performRequest<R: FHIRServerRequestHandler>(request: NSMutableURLRequest, handler: R, callback: ((response: R.ResponseType) -> Void)) {
		var error: NSErrorPointer = nil
		if handler.prepareRequest(request, error: error) {
			let task = defaultSession().dataTaskWithRequest(request) { data, response, error in
				let res = handler.response(response: response, data: data)
				if nil != error {
					res.error = error
				}
				
				logIfDebug("Server responded with status \(res.status)")
				//let str = NSString(data: data!, encoding: NSUTF8StringEncoding)
				//logIfDebug("\(str)")
				callback(response: res)
			}
			
			logIfDebug("Performing request against \(request.URL)")
			task.resume()
		}
		else {
			let err = error.memory?.localizedDescription ?? "if only I knew why"
			callback(response: handler.notSent("Failed to prepare request against \(request.URL): \(err)"))
		}
	}
	
	
	// MARK: - Operations
	
	func conformanceOperation(name: String) -> ConformanceRestOperation? {
		if let defs = conformanceOperations {
			for def in defs {
				if name == def.name {
					return def
				}
			}
		}
		return nil
	}
	
	/**
		Retrieve the operation definition with the given name, either from cache or load the resource.
	
		Once an OperationDefinition has been retrieved, it is cached into the instance's `operations` dictionary. Must
		be used after the conformance statement has been fetched, i.e. after using `ready` or `getConformance`.
	 */
	public func operation(name: String, callback: (OperationDefinition? -> Void)) {
		if let op = operations?[name] {
			callback(op)
		}
		else if let def = conformanceOperation(name) {
			def.definition?.resolve(OperationDefinition.self) { optop in
				if let op = optop {
					if nil != self.operations {
						self.operations![name] = op
					}
					else {
						self.operations = [name: op]
					}
				}
				callback(optop)
			}
		}
		else {
			callback(nil)
		}
	}
	
	/**
		Performs the given Operation.
	
		`Resource` has extensions to facilitate working with operations, be sure to take a look.
	
		:param: operation The operation instance to perform
		:param: callback The callback to call when the request ends (success or failure)
	 */
	public func perform(operation: FHIROperation, callback: ((response: FHIRServerJSONResponse) -> Void)) {
		self.operation(operation.name) { definition in
			if let def = definition {
				var error: NSError?
				if operation.validateWith(def, error: &error) {
					operation.perform(self, callback: callback)
				}
				else {
					callback(response: FHIRServerJSONResponse(notSentBecause: error ?? genServerError("Unknown validation error with operation \(operation)")))
				}
			}
			else {
				callback(response: FHIRServerJSONResponse(notSentBecause: genServerError("The server does not support operation \(operation)")))
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

