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
    
    This implementation holds on to an `Auth` instance to handle authentication. It is automatically instantiated with properties from the
    settings dictionary provided upon initalization of the Server instance OR from the server's Conformance statement.

    This implementation automatically downloads and parses the FHIR Conformance statement, which is used during various tasks, such as
    instantiating the `Auth` instance or validating/executing operations.

    This implementation manages its own NSURLSession, either with an optional delegate provided via `sessionDelegate` or simply the shared
    session. Subclasses can change this behavior by overriding `createDefaultSession` or any of the other request-related methods.
 */
public class Server: FHIRServer
{
	/// The service URL as a string, as specified during initalization to be used as `aud` parameter.
	final let aud: String
	
	/// The server's base URL.
	public final let baseURL: NSURL
	
	/// An optional name of the server; will be read from conformance statement unless manually assigned.
	public final var name: String?
	
	/// The authorization to use with the server.
	var auth: Auth?
	
	/// Settings to be applied to the Auth instance.
	var authSettings: OAuth2JSON? {
		didSet {
			didSetAuthSettings()
		}
	}
	
	/// The operations the server supports, as specified in the conformance statement.
	var operations: [String: OperationDefinition]?
	var conformanceOperations: [ConformanceRestOperation]?
	
	/// The active URL session.
	var session: NSURLSession?
	
	var mustAbortAuthorization = false
	
	/// An optional NSURLSessionDelegate.
	public var sessionDelegate: NSURLSessionDelegate? {
		didSet {
			session = nil
			if let oauth = auth?.oauth {
				oauth.sessionDelegate = sessionDelegate
			}
		}
	}
	
	
	/**
	Main initializer. Makes sure the base URL ends with a "/" to facilitate URL generation later on.
	*/
	public init(baseURL base: NSURL, auth: OAuth2JSON? = nil) {
		aud = base.absoluteString
		if let last = base.absoluteString.characters.last where last != "/" {
			baseURL = base.URLByAppendingPathComponent("/")
		}
		else {
			baseURL = base
		}
		authSettings = auth
		didSetAuthSettings()
	}
	
	public convenience init(base: String, auth: OAuth2JSON? = nil) {
		self.init(baseURL: NSURL(string: base)!, auth: auth)			// yes, this will crash on invalid URL
	}
	
	func didSetAuthSettings() {
		var authType: AuthType? = nil
		if let typ = authSettings?["authorize_type"] as? String {
			authType = AuthType(rawValue: typ)
		}
		if nil == authType || .None == authType! {
			if let _ = authSettings?["authorize_uri"] as? String {
				if let _ = authSettings?["token_uri"] as? String {
					authType = .CodeGrant
				}
				else {
					authType = .ImplicitGrant
				}
			}
		}
		if let type = authType {
			auth = Auth(type: type, server: self, settings: authSettings)
			logIfDebug("Initialized server auth of type “\(type.rawValue)”")
		}
	}
	
	
	// MARK: - Server Conformance
	
	/// The server's conformance statement. Must be implicitly fetched using `getConformance()`
	public internal(set) var conformance: Conformance? {
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
						if nil != auth {
							logIfDebug("Initialized server auth of type “\(auth?.type.rawValue)”")
						}
					}
					
					// if we have not yet initialized an Auth object we'll use one for "no auth"
					if nil == auth {
						auth = Auth(type: .None, server: self, settings: authSettings)
						logIfDebug("Server seems to be open, proceeding with none-type auth")
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
	*/
	final func getConformance(callback: (error: FHIRError?) -> ()) {
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
				callback(error: error ?? FHIRError.Error("Conformance.readFrom() did not return a Conformance instance but \(resource)"))
			}
		}
	}
	
	
	// MARK: - Authorization
	
	public func authClientCredentials() -> (id: String, secret: String?)? {
		if let clientId = auth?.oauth?.clientId where !clientId.isEmpty {
			return (id: clientId, secret: auth?.oauth?.clientSecret)
		}
		return nil
	}
	
	/**
	Ensures that the server is ready to perform requests before calling the callback.
	
	Being "ready" in this case entails holding on to an `Auth` instance. Such an instance is automatically created if either the client
	init settings are sufficient (i.e. contain an "authorize_uri" and optionally a "token_uri") or after the conformance statement has been
	fetched.
	*/
	public func ready(callback: (error: FHIRError?) -> ()) {
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
				callback(error: error ?? FHIRError.Error("Failed to detect the authorization method from server metadata"))
			}
		}
	}
	
	/**
	Ensures that the receiver is ready, then calls the auth method's `authorize()` method.
	*/
	public func authorize(authProperties: SMARTAuthProperties, callback: ((patient: Patient?, error: ErrorType?) -> Void)) {
		self.ready { error in
			if self.mustAbortAuthorization {
				self.mustAbortAuthorization = false
				callback(patient: nil, error: nil)
			}
			else if nil != error || nil == self.auth {
				callback(patient: nil, error: error ?? FHIRError.Error("Client error, no auth instance created"))
			}
			else {
				self.auth!.authorize(authProperties) { parameters, error in
					if self.mustAbortAuthorization {
						self.mustAbortAuthorization = false
						callback(patient: nil, error: nil)
					}
					else if let error = error {
						callback(patient: nil, error: error)
					}
					else if let patient = parameters?["patient_resource"] as? Patient {		// native patient list auth flow will deliver a Patient instance
						callback(patient: patient, error: nil)
					}
					else if let patientId = parameters?["patient"] as? String {
						Patient.read(patientId, server: self) { resource, error in
							logIfDebug("Did read patient \(resource) with error \(error)")
							callback(patient: resource as? Patient, error: error)
						}
					}
					else {
						callback(patient: nil, error: nil)
					}
				}
			}
		}
	}
	
	/**
	Resets authorization state - including deletion of any known access and refresh tokens.
	*/
	func reset() {
		abortSession()
		auth?.reset()
	}
	
	
	// MARK: - Registration
	
	/**
	Internal method forwarding the public method calls.
	
	- parameter dynreg: The `OAuth2DynReg` instance to use for client registration
	- parameter onlyIfNeeded: If set to _true_, registration will only be performed if no client-id has been assigned
	- parameter callback: Callback to call when registration succeeds or fails
	*/
	func registerIfNeeded(dynreg: OAuth2DynReg, onlyIfNeeded: Bool, callback: ((json: OAuth2JSON?, error: ErrorType?) -> Void)) {
		ready() { error in
			if let oauth = self.auth?.oauth {
				dynreg.registerAndUpdateClient(oauth, onlyIfNeeded: onlyIfNeeded, callback: callback)
			}
			else if let error = error {
				callback(json: nil, error: error)
			}
			else {
				callback(json: nil, error: FHIRError.Error("No OAuth2 handle, cannot register client"))
			}
		}
	}
	
	/**
	Given an `OAuth2DynReg` instance, checks if the OAuth2 handler has client-id/secret, and if not attempts to register. Experimental.
	
	- parameter dynreg: The `OAuth2DynReg` instance to use for client registration
	- parameter callback: Callback to call when registration succeeds or fails
	*/
	public func ensureRegistered(dynreg: OAuth2DynReg, callback: ((json: OAuth2JSON?, error: ErrorType?) -> Void)) {
		registerIfNeeded(dynreg, onlyIfNeeded: true, callback: callback)
	}
	
	/**
	Registers the client with the help of the `OAuth2DynReg` instance. Experimental.
	
	- parameter dynreg: The `OAuth2DynReg` instance to use for client registration
	- parameter callback: Callback to call when registration succeeds or fails
	*/
	public func register(dynreg: OAuth2DynReg, callback: ((json: OAuth2JSON?, error: ErrorType?) -> Void)) {
		registerIfNeeded(dynreg, onlyIfNeeded: false, callback: callback)
	}
	
	
	// MARK: - Requests
	
	/**
	The server can return the appropriate request handler for the type and resource combination.
	
	Request handlers are responsible for constructing an NSURLRequest that correctly performs the desired REST interaction.
	
	- parameter type: The type of the request (GET, PUT, POST or DELETE)
	- parameter resource: The resource to be involved in the request, if any
	- returns: An appropriate `FHIRServerRequestHandler`, for example a _FHIRServerJSONRequestHandler_ if sending and receiving JSON
	*/
	public func handlerForRequestOfType(type: FHIRRequestType, resource: FHIRResource?) -> FHIRServerRequestHandler? {
		return FHIRServerJSONRequestHandler(type, resource: resource)
	}
	
	/**
	This method simply creates an absolute URL from the receiver's `baseURL` and the given path.
	
	A chance for subclasses to mess with URL generation if needed.
	*/
	public func absoluteURLForPath(path: String, handler: FHIRServerRequestHandler) -> NSURL? {
		return NSURL(string: path, relativeToURL: baseURL)
	}
	
	/**
	This method should first execute `handlerForRequestOfType()` to obtain an appropriate request handler, then execute the prepared
	request against the server.
	
	- parameter type: The type of the request (GET, PUT, POST or DELETE)
	- parameter path: The relative path on the server to be interacting against
	- parameter resource: The resource to be involved in the request, if any
	- parameter callback: A callback, likely called asynchronously, returning a response instance
	*/
	public func performRequestOfType(type: FHIRRequestType, path: String, resource: FHIRResource?, callback: ((response: FHIRServerResponse) -> Void)) {
		if let handler = handlerForRequestOfType(type, resource: resource) {
			performRequestAgainst(path, handler: handler, callback: callback)
		}
		else {
			let res = FHIRServerRequestHandler.noneAvailableForType(type)
			callback(response: res)
		}
	}
	
	/**
	Method to execute a given request with a given request/response handler.
	
	- parameter path: The path, relative to the server's base; may include URL query and URL fragment (!)
	- parameter handler: The RequestHandler that prepares the request and processes the response
	- parameter callback: The callback to execute; NOT guaranteed to be performed on the main thread!
	*/
	public func performRequestAgainst<R: FHIRServerRequestHandler>(path: String, handler: R, callback: ((response: FHIRServerResponse) -> Void)) {
		if let url = absoluteURLForPath(path, handler: handler) {
			let request = auth?.signedRequest(url) ?? NSMutableURLRequest(URL: url)
			do {
				try handler.prepareRequest(request)
				self.performPreparedRequest(request, handler: handler, callback: callback)
			}
			catch let error {
				let err = (error as NSError).localizedDescription ?? "if only I knew why (\(__FILE__):\(__LINE__))"
				callback(response: handler.notSent("Failed to prepare request against \(url): \(err)"))
			}
		}
		else {
			let res = handler.notSent("Failed to parse path «\(path)» relative to server base URL")
			callback(response: res)
		}
	}
	
	/**
	Method to execute an already prepared request and use the given request/response handler.
	
	This implementation uses the instance's NSURLSession to execute data tasks with the requests. Subclasses can override to supply
	different NSURLSessions based on the request, if so desired.
	
	- parameter request: The URL request to perform
	- parameter handler: The RequestHandler that prepares the request and processes the response
	- parameter callback: The callback to execute; NOT guaranteed to be performed on the main thread!
	*/
	public func performPreparedRequest<R: FHIRServerRequestHandler>(request: NSMutableURLRequest, handler: R, callback: ((response: FHIRServerResponse) -> Void)) {
		performPreparedRequest(request, withSession: URLSession(), handler: handler, callback: callback)
	}
	
	/**
	Method to execute an already prepared request with a given session and use the given request/response handler.
	
	- parameter request: The URL request to perform
	- parameter withSession: The NSURLSession instance to use
	- parameter handler: The RequestHandler that prepares the request and processes the response
	- parameter callback: The callback to execute; NOT guaranteed to be performed on the main thread!
	*/
	public func performPreparedRequest<R: FHIRServerRequestHandler>(request: NSMutableURLRequest, withSession session: NSURLSession, handler: R, callback: ((response: FHIRServerResponse) -> Void)) {
		let task = session.dataTaskWithRequest(request) { data, response, error in
			let res = handler.response(response: response, data: data, error: error)
			logIfDebug("Server responded with status \(res.status)")
			//let str = NSString(data: data!, encoding: NSUTF8StringEncoding)
			//logIfDebug("\(str)")
			callback(response: res)
		}
		
		logIfDebug("Performing \(handler.type.rawValue) request against \(request.URL!)")
		task.resume()
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
	
	Once an OperationDefinition has been retrieved, it is cached into the instance's `operations` dictionary. Must be used after the
	conformance statement has been fetched, i.e. after using `ready` or `getConformance`.
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
	
	- parameter operation: The operation instance to perform
	- parameter callback: The callback to call when the request ends (success or failure)
	*/
	public func performOperation(operation: FHIROperation, callback: ((response: FHIRServerResponse) -> Void)) {
		self.operation(operation.name) { definition in
			if let def = definition {
				do {
					try operation.validateWith(def)
					operation.perform(self, callback: callback)
				}
				catch let error {
					callback(response: FHIRServerJSONResponse(error: error))
				}
			}
			else {
				callback(response: FHIRServerJSONResponse(error: FHIRError.OperationNotSupported(operation.name)))
			}
		}
	}
	
	
	// MARK: - Session Management
	
	final public func URLSession() -> NSURLSession {
		if nil == session {
			session = createDefaultSession()
		}
		return session!
	}
	
	/** Create the server's default session. Override in subclasses to customize NSURLSession behavior. */
	public func createDefaultSession() -> NSURLSession {
		if let delegate = sessionDelegate {
			return NSURLSession(configuration: NSURLSessionConfiguration.defaultSessionConfiguration(), delegate: delegate, delegateQueue: nil)
		}
		return NSURLSession.sharedSession()
	}
	
	func abortAuthorization() {
		logIfDebug("Aborting authorization")
		mustAbortAuthorization = true
		if nil != auth {
			auth!.abort()
		}
	}
	
	func abortSession() {
		if nil != session {
			session!.invalidateAndCancel()
			session = nil
		}
	}
}

