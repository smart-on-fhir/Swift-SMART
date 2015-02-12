//
//  Client.swift
//  SMART-on-FHIR
//
//  Created by Pascal Pfiffner on 6/11/14.
//  Copyright (c) 2014 SMART Platforms. All rights reserved.
//

import Foundation
import SwiftFHIR


let SMARTErrorDomain = "SMARTErrorDomain"


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
	public let server: Server
	
	/// Set the authorize type you want, e.g. to use a built in web view for authentication and patient selection.
	public var authProperties = SMARTAuthProperties()
	
	
	/** Designated initializer. */
	init(server: Server) {
		self.server = server
		logIfDebug("Initialized SMART on FHIR client against server \(server.baseURL.description)")		// crashing in Xcode 6.1 GM, not anymore in Xcode 6.2
	}
	
	/**
		Use this initializer with the appropriate server/auth settings. You can use:
	
		- client_id
		- redirect: after-auth redirect URL (string). Do not forget to register as your app's URL handler
		- redirect_uris: array of redirect URL (strings); will be created if you supply "redirect"
		- scope: authorization scope, defaults to "user/ *.* openid profile" plus launch scope, if needed
		
		:param baseURL: The server's base URL
		:param settings: Client settings, mostly concerning authorization
		:param title: A title to display in the authorization window; can also be supplied in the settings dictionary
	 */
	public convenience init(baseURL: String, settings: JSONDictionary, title: String = "SMART") {
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
		Executes the callback immediately if the server is ready to perform requests, after performing necessary
		setup operations and requests otherwise.
	 */
	public func ready(callback: (error: NSError?) -> ()) {
		server.ready(callback)
	}
	
	/**
		Call this to start the authorization process.
	
		If you use the OS browser as authorize type you will need to intercept the OAuth redirect and call `didRedirect`
		yourself.
	 */
	public func authorize(callback: (patient: Patient?, error: NSError?) -> ()) {
		// TODO: if we don't use "launch" context, check if we have a token and omit the full authorization flow
		server.authorize(authProperties, callback)
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
		server.abortSession()
	}
	
	
	// MARK: - Making Requests
	
	/**
		Request a JSON resource at the given path from the client's server.
	
		:param: path The path relative to the server's base URL to request
		:param: callback The callback to execute once the request finishes
	 */
	public func getJSON(path: String, callback: FHIRServerJSONResponseCallback) {
		server.getJSON(path, callback: callback)
	}
}



public func logIfDebug(log: String) {
#if DEBUG
	println("SoF: \(log)")
#endif
}

public func genSMARTError(text: String, code: Int = 0) -> NSError {
	return NSError(domain: SMARTErrorDomain, code: code, userInfo: [NSLocalizedDescriptionKey: text])
}

