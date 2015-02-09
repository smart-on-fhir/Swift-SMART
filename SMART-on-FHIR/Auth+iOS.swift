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
			
			// present native patient selector: we redirect "onAuthorize" and must make sure to reconnect it when done
			if granularity == .PatientSelectNative {
				let onAuth = oauth.onAuthorize
				oauth.onAuthorize = { params in
					let view = PatientListViewController(list: PatientListAll(), server: self.server)
					view.onPatientSelect = { patient in
						var parameters = params
						if let pat = patient {
							parameters["patient"] = pat.id
						}
						onAuth?(parameters: parameters)
						if !(view.parentViewController ?? view).isBeingDismissed() {
							root.dismissViewControllerAnimated(true, completion: nil)
						}
					}
					view.title = oauth.viewTitle
					view.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .Done, target: view, action: "dismissFromModal:")
					
					root.dismissViewControllerAnimated(false) {
						let navi = UINavigationController(rootViewController: view)
						root.presentViewController(navi, animated: false, completion: nil)
					}
				}
				oauth.afterAuthorizeOrFailure = { wasFailure, error in
					oauth.onAuthorize = onAuth
					if wasFailure {
						web.dismissViewControllerAnimated(true, completion: nil)
					}
				}
			}
			
			// other authorize granularities, dismiss when done
			else {
				oauth.afterAuthorizeOrFailure = { wasFailure, error in
					root.dismissViewControllerAnimated(true, completion: nil)
				}
			}
		}
		else {
			oauth.onFailure?(error: genOAuth2Error("No root view controller, cannot present authorize screen"))
		}
	}
}

