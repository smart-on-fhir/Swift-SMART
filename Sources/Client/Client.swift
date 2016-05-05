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
public struct SMARTAuthProperties {
	
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
	
	Create an instance of this class, then hold on to it for all your interactions with the SMART server:

	```swift
	import SMART

	let smart = Client(
	    baseURL: "https://fhir-api-dstu2.smarthealthit.org",
	    settings: [
	        //"client_id": "my_mobile_app",       // if you have one; otherwise uses dyn reg
	        "redirect": "smartapp://callback",    // must be registered in Info.plist
	    ]
	)
	```

	There are many other options that you can pass to `settings`, take a look at `init(baseURL:settings:)`. Also see our [programming
	guide](https://github.com/smart-on-fhir/Swift-SMART/wiki/Client) for more information.
 */
public class Client {
	
	/// The server this client connects to.
	public final let server: Server
	
	/// Set the authorize type you want, e.g. to use a built in web view for authentication and patient selection.
	public var authProperties = SMARTAuthProperties()
	
	
	/**
	Designated initializer.
	
	- parameter server: The server instance this client manages
	*/
	public init(server: Server) {
		self.server = server
		server.logger?.debug("SMART", msg: "Initialized SMART on FHIR client against server \(server.baseURL.description)")
	}
	
	/**
	Use this initializer with the appropriate server/auth settings. You can use:
	
	- `client_id`:      If you have a client-id; otherwise, if the server supports OAuth2 dynamic client registration, will register itself
	- `redirect`:       After-auth redirect URL (string). Must be registered on the server and in your app's Info.plist (URL handler)
	- `redirect_uris`:  Array of redirect URL (strings); will be created if you supply "redirect"
	- `scope`:          Authorization scope, defaults to "user/ *.* openid profile" plus launch scope, if needed
	- `authorize_uri`:  Optional; if present will NOT use the authorization endpoints defined in the server's metadata. Know what you do!
	- `token_uri`:      Optional; if present will NOT use the authorization endpoints defined in the server's metadata. Know what you do!
	- `authorize_type`: Optional; inferred to be "authorization_code" or "implicit". Can also be "client_credentials" for a 2-legged
	                    OAuth2 flow.
	- `client_name`:    OPTIONAL, if you use dynamic client registration, this is the name of your app
	- `logo_uri`:       OPTIONAL, if you use dynamic client registration, a URL to the icon of your app
	
	The settings are forwarded to the `OAuth2` framework, so you can use any of the settings supported during authorization if you know
	what you're doing: `init(settings:)` from http://p2.github.io/OAuth2/Classes/OAuth2.html .
	
	- parameter baseURL:  The server's base URL
	- parameter settings: Client settings, mostly concerning authorization
	*/
	public convenience init(baseURL: String, settings: OAuth2JSON) {
		var sett = settings
		if let redirect = settings["redirect"] as? String {
			sett["redirect_uris"] = [redirect]
		}
		if nil == settings["title"] {
			sett["title"] = "SMART"
		}
		let srv = Server(base: baseURL, auth: sett)
		self.init(server: srv)
	}
	
	
	// MARK: - Preparations
	
	/**
	Executes the callback immediately if the server is ready to perform requests. Otherwise performs necessary setup operations and
	requests, like retrieving the conformance statement.
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
		server.authorize(self.authProperties, callback: callback)
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
		server.performRequestAgainst(path, handler: handler) { response in
			callback(response: response as! FHIRServerJSONResponse)
		}
	}
	
	/**
	Plain NSData request against the given full URL.
	
	If the server needs authentication and the URL is not in the receiver's baseURL, this is probably going to fail. You usually use this
	method if a resource has attachments that live on the same server, e.g. Patient.photo.url.
	*/
	public func getData(url: NSURL, accept: String, callback: ((response: FHIRServerResponse) -> Void)) {
		let handler = FHIRServerDataRequestHandler(.GET, contentType: accept)
		if nil != url.host {
			server.performRequestWithURL(url, handler: handler, callback: callback)
		}
		else if let path = url.path {
			server.performRequestAgainst(path, handler: handler, callback: callback)
		}
		else {
			callback(response: FHIRServerDataResponse(error: FHIRError.ResourceLocationUnknown))
		}
	}
}

