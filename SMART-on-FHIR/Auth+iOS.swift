//
//  Client+iOS.swift
//  SMART-on-FHIR
//
//  Created by Pascal Pfiffner on 6/25/14.
//  Copyright (c) 2014 SMART Platforms. All rights reserved.
//

import UIKit
import SwiftFHIR
import OAuth2


extension Auth
{
	/** Open a URL in the OS' browser. */
	func openURLInBrowser(url: NSURL) -> Bool {
		return UIApplication.sharedApplication().openURL(url)
	}
	
	/**
		Shows a modal web view on the key window's root view controller to let the user log in and authorize the app.
		Can be automatically dismissed on success.
	 */
	func authorizeEmbedded(oauth: OAuth2, granularity: SMARTAuthGranularity) {
		if let root = UIApplication.sharedApplication().keyWindow?.rootViewController {
			let web = oauth.authorizeEmbeddedFrom(root, params: nil)
			if granularity == .PatientSelectWeb {
				oauth.afterAuthorizeOrFailure = { wasFailure in
					web.dismissViewControllerAnimated(true, completion: nil)
				}
			}
			else if granularity == .PatientSelectNative {
				oauth.afterAuthorizeOrFailure = { wasFailure in
					let search = FHIRSearch(query: [])
					search.pageCount = 50
					let query = PatientListQuery(search: search)
					let list = PatientList(query: query)
					let view = PatientListViewController(list: list, server: self.server)
					view.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .Done, target: view, action: "dismissFromModal:")
					
					root.dismissViewControllerAnimated(false) {
						let navi = UINavigationController(rootViewController: view)
						root.presentViewController(navi, animated: false, completion: nil)
					}
				}
			}
		}
		else {
			oauth.onFailure?(error: genOAuth2Error("No root view controller, cannot present authorize screen"))
		}
	}
}

