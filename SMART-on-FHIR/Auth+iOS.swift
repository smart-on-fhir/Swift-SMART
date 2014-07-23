//
//  Client+iOS.swift
//  SMART-on-FHIR
//
//  Created by Pascal Pfiffner on 6/25/14.
//  Copyright (c) 2014 SMART Platforms. All rights reserved.
//

import UIKit
import OAuth2iOS


extension Auth {
	
	/** Open a URL in the OS' browser. */
	func openURLInBrowser(url: NSURL) -> Bool {
		return UIApplication.sharedApplication().openURL(url)
	}
	
	/** Shows a modal web view to let the user log in and authorize the app, dismisses on success. */
	func authorizeEmbedded(oauth: OAuth2) {
		let web = oauth.authorizeEmbedded(redirect, scope: scope, params: nil)
		oauth.afterAuthorizeOrFailure = { wasFailure in
			web.dismissViewControllerAnimated(true, completion: nil)
		}
	}
}

