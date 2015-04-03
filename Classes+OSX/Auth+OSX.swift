//
//  Client+iOS.swift
//  SMART-on-FHIR
//
//  Created by Pascal Pfiffner on 6/25/14.
//  Copyright (c) 2014 SMART Health IT. All rights reserved.
//

import Cocoa


extension Auth
{
	/** Open a URL in the OS' browser. */
	func openURLInBrowser(url: NSURL) -> Bool {
		return NSWorkspace.sharedWorkspace().openURL(url)
	}
	
	/** Lets the user login from within the app, dismisses on success. */
	func authorizeEmbedded(oauth: OAuth2, granularity: SMARTAuthGranularity) {
		fatalError("Not yet implemented")
	}
	
	func showPatientList(parameters: OAuth2JSON) {
		fatalError("Not yet implemented")
	}
}

