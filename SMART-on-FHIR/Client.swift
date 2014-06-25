//
//  Client.swift
//  SMART-on-FHIR
//
//  Created by Pascal Pfiffner on 6/11/14.
//  Copyright (c) 2014 SMART Platforms. All rights reserved.
//

import Foundation


let SMARTErrorDomain = "SMARTErrorDomain"


/*!
 *  A client instance handles authentication and connection to a SMART on FHIR resource server.
 */
class Client {
	
	/*! The authentication protocol to use. */
	let auth: Auth
	
	/*! The server this client connects to. */
	let server: Server
	
	/*! Designated initializer. */
	init(auth: Auth, server: Server) {
		self.auth = auth
		self.server = server
		logIfDebug("Initialized SMART on FHIR client against server \(server.baseURL.description)")
	}
	
	/*! Use this initializer with the server settings needed to connect. */
	convenience init(serverURL: String, clientId: String, clientSecret: String?, redirect: String) {
		let srv = Server(base: serverURL)
		
		var settings = ["client_id": clientId]
		if clientSecret {
			settings["client_secret"] = clientSecret!
		}
		let myAuth = Auth(type: AuthMethod.CodeGrant, redirect: redirect, settings: settings)
		
		self.init(auth: myAuth, server: srv)
	}
	
	
	// MARK: - Preparations
	
	var authCallback: ((error: NSError?) -> ())?
	
	func ready(callback: (error: NSError?) -> ()) {
		if auth.oauth {
			callback(error: nil)
			return
		}
		
		// if we haven't initialized the auth's OAuth2 instance we likely didn't fetch the server metadata yet
		server.getMetadata { error in
			if error {
				callback(error: error)
			}
			else if self.server.authURL {
				self.auth.create(authURL: self.server.authURL!, tokenURL: self.server.tokenURL)
				callback(error: nil)
			}
			else {
				callback(error: NSError(domain: SMARTErrorDomain, code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to extract `authorize` URL from server metadata"]))
			}
		}
	}
	
	func authorize(callback: (error: NSError?) -> ()) {
		self.ready { error in
			if error {
				callback(error: error)
			}
			else {
				if self.authCallback {
					self.authCallback!(error: NSError(domain: SMARTErrorDomain, code: 0, userInfo: [NSLocalizedDescriptionKey: "Timeout"]))
				}
				
				// open authorize URL
				if let url = self.auth.authorizeURL() {
					if self.openURL(url) {
						self.authCallback = callback
					}
					else {
						callback(error: NSError(domain: SMARTErrorDomain, code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to open authorize webpage"]))
					}
				}
				else {
					callback(error: NSError(domain: SMARTErrorDomain, code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to determine authorize URL"]))
				}
			}
		}
	}
	
	
	// MARK: - Accessing Resources
	
	func read<FHIRBaseResource>(id: String) -> FHIRBaseResource? {
		return nil;
	}
	
	func search<FHIRBaseResource>() -> FHIRBaseResource[] {
		return []
	}
}



func logIfDebug(log: String) {
//#if DEBUG
	println("SoF: \(log)")
//#endif
}

