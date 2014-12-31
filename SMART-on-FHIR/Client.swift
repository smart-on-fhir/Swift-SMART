//
//  Client.swift
//  SMART-on-FHIR
//
//  Created by Pascal Pfiffner on 6/11/14.
//  Copyright (c) 2014 SMART Platforms. All rights reserved.
//

import Foundation


let SMARTErrorDomain = "SMARTErrorDomain"


/**
	A client instance handles authentication and connection to a SMART on FHIR resource server.
 */
public class Client
{
	/// The server this client connects to.
	public let server: Server
	
	/// Set to false if you don't want to use a built in web view for authentication.
	var useWebView = true
	
	/** Designated initializer. */
	init(server: Server) {
		self.server = server
		logIfDebug("Initialized SMART on FHIR client against server \(server.baseURL.description)")		// crashing in Xcode 6.1 GM
//		logIfDebug("Initialized SMART on FHIR client")
	}
	
	/** Use this initializer with the appropriate server settings. */
	public convenience init(serverURL: String,
	                         clientId: String,
                             redirect: String,
		                        scope: String = "launch/patient user/*.* patient/*.read openid profile") {
		var settings = [
			"client_id": clientId,
			"scope": scope,
			"redirect_uris": [redirect],
		]
		let srv = Server(base: serverURL, auth: settings)
		self.init(server: srv)
	}
	
	
	// MARK: - Preparations
	
	/**
		Executes the callback immediately, if the server is ready to perform requests, after performing necessary
		setup operations and requests otherwise.
	 */
	public func ready(callback: (error: NSError?) -> ()) {
		server.ready(callback)
	}
	
	/**
		Call this to start the authorization process.
	
		If you set `useWebView` to false you will need to intercept the OAuth redirect and call `didRedirect` yourself.
	*/
	public func authorize(callback: (patient: Patient?, error: NSError?) -> ()) {
		self.server.authorize(self.useWebView, callback)
	}
	
	/// Will return true while the client is waiting for the authorization callback.
	public var awaitingAuthCallback: Bool {
		get { return nil != server.auth?.authCallback }
	}
	
	/** Call this with the redirect URL when intercepting the redirect callback in the app delegate. */
	public func didRedirect(redirect: NSURL) -> Bool {
		return server.handleRedirect(redirect)
	}
	
	/** Stops any request currently in progress. */
	public func abort() {
		server.abortSession()
	}
	
	
	// MARK: - Making Requests
	
	/**
		Request a JSON resource at the given path from the client's server.
	
		:param: path The path relative to the server's base URL to request
		:param: callback The callback to execute once the request finishes
	 */
	public func requestJSON(path: String, callback: ((json: NSDictionary?, error: NSError?) -> Void)) {
		server.requestJSON(path, callback: callback)
	}
}



public func logIfDebug(log: String) {
#if DEBUG
	println("SoF: \(log)")
#endif
}

public func genSMARTError(text: String, code: Int?) -> NSError {
	return NSError(domain: SMARTErrorDomain, code: code ?? 0, userInfo: [NSLocalizedDescriptionKey: text])
}

