//
//  Client.swift
//  SMART-on-FHIR
//
//  Created by Pascal Pfiffner on 6/11/14.
//  Copyright (c) 2014 SMART Health IT. All rights reserved.
//

import Foundation


/**
	Describes properties for the authorization flow.
 */
public struct SMARTAuthProperties
{
	/// Whether the client should use embedded view controllers for the auth flow or just redirect to the OS's browser.
	public var embedded = true
	
	/// How granular the authorize flow should be.
	public var granularity = SMARTAuthGranularity.PatientSelectNative
}


/**
	Enum describing the desired granularity of the authorize flow.
 */
public enum SMARTAuthGranularity {
	case TokenOnly
	case LaunchContext
	case PatientSelectWeb
	case PatientSelectNative
}


/**
	A client instance handles authentication and connection to a SMART on FHIR resource server.
 */
public class Client
{
	/// The server this client connects to.
	public final let server: Server
	
	/// Set the authorize type you want, e.g. to use a built in web view for authentication and patient selection.
	public var authProperties = SMARTAuthProperties()
	
	
	/** Designated initializer. */
	public init(server: Server) {
		self.server = server
		logIfDebug("Initialized SMART on FHIR client against server \(server.baseURL.description)")
	}
	
	/**
	    Use this initializer with the appropriate server/auth settings. You can use:
	
	    - client_id
	    - redirect: after-auth redirect URL (string). Do not forget to register as your app's URL handler
	    - redirect_uris: array of redirect URL (strings); will be created if you supply "redirect"
	    - scope: authorization scope, defaults to "user/ *.* openid profile" plus launch scope, if needed
	    - authorize_uri and token_uri: OPTIONAL, if present will NOT use the authorization endpoints defined in the server's metadata. Know
	        what you do when you set these.
	    - authorize_type: OPTIONAL, inferred to be "authorization_code" or "implicit". Can also be "client_credentials" for a 2-legged
	        OAuth2 flow.
	
	    - parameter baseURL: The server's base URL
	    - parameter settings: Client settings, mostly concerning authorization
	    - parameter title: A title to display in the authorization window; can also be supplied in the settings dictionary
	 */
	public convenience init(baseURL: String, settings: OAuth2JSON, title: String = "SMART") {
		var sett = settings
		if let redirect = settings["redirect"] as? String {
			sett["redirect_uris"] = [redirect]
		}
		if nil == settings["title"] {
			sett["title"] = title
		}
		let srv = Server(base: baseURL, auth: sett)
		self.init(server: srv)
	}
	
	
	// MARK: - Preparations
	
	/**
	Executes the callback immediately if the server is ready to perform requests, after performing necessary setup operations and
	requests otherwise.
	*/
	public func ready(callback: (error: ErrorType?) -> ()) {
		server.ready(callback)
	}
	
	/**
	Call this to start the authorization process. Implicitly calls `ready`, so no need to call it yourself.
	
	If you use the OS browser as authorize type you will need to intercept the OAuth redirect and call `didRedirect` yourself.
	*/
	public func authorize(callback: (patient: Patient?, error: ErrorType?) -> ()) {
		server.mustAbortAuthorization = false
		server.ready() { error in
			if let error = error {
				callback(patient: nil, error: error)
			}
			else {
				self.server.authorize(self.authProperties, callback: callback)
			}
		}
	}
	
	/// Will return true while the client is waiting for the authorization callback.
	public var awaitingAuthCallback: Bool {
		get { return nil != server.auth?.authCallback }
	}
	
	/** Call this with the redirect URL when intercepting the redirect callback in the app delegate. */
	public func didRedirect(redirect: NSURL) -> Bool {
		return server.auth?.handleRedirect(redirect) ?? false
	}
	
	/** Stops any request currently in progress. */
	public func abort() {
		server.abort()
	}
	
	/** Resets state and authorization data. */
	public func reset() {
		server.reset()
	}
	
	/** Throws away local client registration data. */
	public func forgetClientRegistration() {
		server.forgetClientRegistration()
	}
	
	
	// MARK: - Making Requests
	
	/**
	Request a JSON resource at the given path from the client's server.
	
	- parameter path: The path relative to the server's base URL to request
	- parameter callback: The callback to execute once the request finishes
	*/
	public func getJSON(path: String, callback: ((response: FHIRServerJSONResponse) -> Void)) {
		let handler = FHIRServerJSONRequestHandler(.GET)
		server.performRequestAgainst(path, handler: handler) { (response) -> Void in
			callback(response: response as! FHIRServerJSONResponse)
		}
	}
}



public func logIfDebug(log: String) {
#if DEBUG
	print("SoF: \(log)")
#endif
}

