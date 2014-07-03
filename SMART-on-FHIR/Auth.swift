//
//  Auth.swift
//  SMART-on-FHIR
//
//  Created by Pascal Pfiffner on 6/11/14.
//  Copyright (c) 2014 SMART Platforms. All rights reserved.
//

import Foundation
import OAuth2iOS			// TODO: figure out a way to use the iOS framework as simply "OAuth2"


enum AuthMethod {
	case None
	case ImplicitGrant
	case CodeGrant
}


/*!
 *  Describes the authentication to be used.
 */
class Auth: OAuth2Delegate {
	
	/*! The authentication type; only "oauth2" is supported. */
	let type: AuthMethod
	
	/*! The scopes needed; supply a space-separated list just as if supplying directly to OAuth2. */
	let scope: String
	
	/*! The redirect to be used. */
	let redirect: String
	
	/*! Additional settings to be used to initialize the OAuth2 subclass. */
	let settings: NSDictionary
	
	/*! The authentication object to be used. */
	var oauth: OAuth2?
	
	init(type: AuthMethod, scope: String, redirect: String, settings: NSDictionary) {
		self.type = type
		self.scope = scope
		self.redirect = redirect
		self.settings = settings
	}
	
	
	var clientId: String? {
	get {
		return oauth?.clientId
	}
	}
	
	var patientId: String?
	
	
	// MARK: OAuth
	
	func create(# authURL: NSURL, tokenURL: NSURL?) {
		// TODO: make a nice factory method
		var settings = self.settings.mutableCopy() as NSMutableDictionary
		settings["authorize_uri"] = authURL.absoluteString
		if tokenURL {
			settings["token_uri"] = tokenURL!.absoluteString
		}
		//settings["redirect_uris"] = [redirect]
		
		switch type {
		case .CodeGrant:
			oauth = OAuth2CodeGrant(settings: settings)
			oauth!.delegate = self
		default:
			fatalError("Invalid auth method type")
		}
		
#if DEBUG
		oauth!.verbose = true
#endif
	}
	
	func authorizeURL() -> NSURL? {
		switch type {
		case .CodeGrant:
			if let cg = oauth as? OAuth2CodeGrant {
				return cg.authorizeURLWithRedirect(redirect, scope: scope, params: nil)
			}
		default:
			break
		}
		return nil
	}
	
	func handleRedirect(redirect: NSURL, callback: (error: NSError?) -> ()) {
		if oauth {
			oauth!.handleRedirectURL(redirect, callback: callback)
		}
	}
	
	func didAuthorize(oauth2: OAuth2, parameters: NSDictionary) {
		if let patient = parameters["patient"] as? String {
			patientId = patient
			logIfDebug("Did receive patient id \(patient)")
		}
	}
	
	
	// MARK: Requests
	
	func signedRequest(url: NSURL) -> NSMutableURLRequest {
		return oauth!.request(forURL: url)
	}
}

