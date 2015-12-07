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
public class Server: FHIROpenServer
{
	/// The service URL as a string, as specified during initalization to be used as `aud` parameter.
	final let aud: String
	
	/// An optional name of the server; will be read from conformance statement unless manually assigned.
	public final var name: String?
	
	/// The authorization to use with the server.
	var auth: Auth? {
		didSet {
			if let auth = auth {
				fhir_logIfDebug("Initialized server auth of type “\(auth.type.rawValue)”")
				if let oauth = auth.oauth {
					oauth.sessionDelegate = sessionDelegate
					oauth.onBeforeDynamicClientRegistration = onBeforeDynamicClientRegistration
				}
			}
		}
	}
	
	/// Settings to be applied to the Auth instance.
	var authSettings: OAuth2JSON? {
		didSet {
			didSetAuthSettings()
		}
	}
	
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
	
	/// Allow to inject a custom OAuth2DynReg class and/or setup.
	public var onBeforeDynamicClientRegistration: (NSURL -> OAuth2DynReg)? {
		didSet {
			if let oauth = auth?.oauth {
				oauth.onBeforeDynamicClientRegistration = onBeforeDynamicClientRegistration
			}
		}
	}
	
	
	/**
	Main initializer. Makes sure the base URL ends with a "/" to facilitate URL generation later on.
	*/
	public required init(baseURL base: NSURL, auth: OAuth2JSON? = nil) {
		aud = base.absoluteString
		authSettings = auth
		super.init(baseURL: base, auth: auth)
		didSetAuthSettings()
	}
	
	public convenience init(base: String, auth: OAuth2JSON? = nil) {
		self.init(baseURL: NSURL(string: base)!, auth: auth)			// yes, this will crash on invalid URL
	}
	
	func didSetAuthSettings() {
		instantiateAuthFromAuthSettings()
	}
	
	
	// MARK: - Requests
	
	public override func createDefaultSession() -> NSURLSession {
		if let delegate = sessionDelegate {
			return NSURLSession(configuration: NSURLSessionConfiguration.defaultSessionConfiguration(), delegate: delegate, delegateQueue: nil)
		}
		return super.createDefaultSession()
	}
	
	public override func configurableRequestForURL(url: NSURL) -> NSMutableURLRequest {
		return auth?.signedRequest(url) ?? super.configurableRequestForURL(url)
	}
	
	
	// MARK: - Server Conformance
	
	public override func didSetConformance(conformance: Conformance) {
		if nil == name && nil != conformance.name {
			name = conformance.name
		}
		super.didSetConformance(conformance)
	}
	
	public override func didFindConformanceRestStatement(rest: ConformanceRest) {
		super.didFindConformanceRestStatement(rest)
		
		// initialize Auth; if we can't find a suitable Auth we'll use one for "no auth"
		if let security = rest.security {
			auth = Auth.fromConformanceSecurity(security, server: self, settings: authSettings)
		}
		if nil == auth {
			auth = Auth(type: .None, server: self, settings: authSettings)
			fhir_logIfDebug("Server seems to be open, proceeding with none-type auth")
		}
	}
	
	
	// MARK: - Authorization
	
	public var authClientCredentials: (id: String, secret: String?, name: String?)? {
		if let clientId = auth?.oauth?.clientId where !clientId.isEmpty {
			return (id: clientId, secret: auth?.oauth?.clientSecret, name: auth?.oauth?.clientName)
		}
		return nil
	}
	
	/**
	Attempt to instantiate our `Auth` instance from `authSettings`.
	*/
	func instantiateAuthFromAuthSettings() -> Bool {
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
			return true
		}
		return false
	}
	
	/**
	Ensures that the server is ready to perform requests before calling the callback.
	
	Being "ready" in this case entails holding on to an `Auth` instance. Such an instance is automatically created if either the client
	init settings are sufficient (i.e. contain an "authorize_uri" and optionally a "token_uri" and a "client_id" or "registration_uri") or
	after the conformance statement has been fetched.
	*/
	public func ready(callback: (error: FHIRError?) -> ()) {
		if nil != auth || instantiateAuthFromAuthSettings() {
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
		ready() { error in
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
							fhir_logIfDebug("Did read patient \(resource) with error \(error)")
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
	
	public func abort() {
		abortAuthorization()
		abortSession()
	}
	
	func abortAuthorization() {
		mustAbortAuthorization = true
		if nil != auth {
			auth!.abort()
		}
	}
	
	/**
	Resets authorization state - including deletion of any known access and refresh tokens.
	*/
	func reset() {
		abort()
		auth?.reset()
	}
	
	
	// MARK: - Client Registration
	
	/**
	Runs dynamic client registration unless the client has a client id (or no registration URL is known). Since this happens automatically
	during `authorize()` you probably won't need to call this method explicitly.
	
	- parameter callback: The callback to call when completed or failed; if both json and error is nil no registration was attempted
	*/
	public func registerIfNeeded(callback: ((json: OAuth2JSON?, error: ErrorType?) -> Void)) {
		ready() { error in
			if nil != error || nil == self.auth {
				callback(json: nil, error: error ?? FHIRError.Error("Client error, no auth instance created"))
			}
			else if let oauth = self.auth?.oauth {
				oauth.registerClientIfNeeded(callback)
			}
			else {
				callback(json: nil, error: nil)
			}
		}
	}
	
	func forgetClientRegistration() {
		auth?.forgetClientRegistration()
		auth = nil
	}
}

public typealias FHIRBaseServer = Server

