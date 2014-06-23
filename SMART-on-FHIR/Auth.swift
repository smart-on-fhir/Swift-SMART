//
//  Auth.swift
//  SMART-on-FHIR
//
//  Created by Pascal Pfiffner on 6/11/14.
//  Copyright (c) 2014 SMART Platforms. All rights reserved.
//

import Foundation
import OAuth2iOS			// TODO: figure out a way to use the iOS framework as simply "OAuth"


enum AuthMethod {
	case None
	case ImplicitGrant
	case CodeGrant
}


/*!
 *  Describes the authentication to be used.
 */
class Auth {
	
	/*! The authentication type; only "oauth2" is supported. */
	let type: AuthMethod
	
	/*! Settings to be used to initialize the OAuth2 subclass. */
	let settings: NSDictionary
	
	/*! The authentication object to be used. */
	var oauth: OAuth2?
	
	init(type: AuthMethod, settings: NSDictionary) {
		self.type = type
		self.settings = settings
	}
	
	
	var clientId: String? {
	get {
		return oauth?.clientId
	}
	}
	
	func create(# auth: NSURL, token: NSURL?) {
		// TODO: make a nice factory method
		var settings = self.settings.mutableCopy() as NSMutableDictionary
		settings["authorize_uri"] = auth.absoluteString
		if token {
			settings["token_uri"] = token!.absoluteString
		}
		
		switch type {
		case .CodeGrant:
			oauth = OAuth2CodeGrant(settings: settings)
		default:
			fatalError("Invalid auth method type")
		}
	}
}
