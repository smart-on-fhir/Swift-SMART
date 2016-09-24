//
//  Client+iOS.swift
//  SMART-on-FHIR
//
//  Created by Pascal Pfiffner on 6/25/14.
//  Copyright (c) 2014 SMART Health IT. All rights reserved.
//

import Cocoa


extension Auth {
	
	/** Show the authorization view controller corresponding to the auth properties. */
	func authorizeWith(oauth: OAuth2, properties: SMARTAuthProperties, callback: @escaping ((OAuth2JSON?, OAuth2Error?) -> Void)) {
		oauth.authConfig.authorizeContext = authContext
		oauth.authConfig.authorizeEmbedded = properties.embedded
		oauth.authConfig.authorizeEmbeddedAutoDismiss = properties.granularity != .patientSelectNative
		
		oauth.authorize(params: ["aud": server.aud], callback: callback)
	}
	
	func showPatientList(withParameters parameters: OAuth2JSON) {
		fatalError("Not yet implemented")
	}
}

