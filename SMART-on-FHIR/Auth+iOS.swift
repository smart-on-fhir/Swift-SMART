//
//  Client+iOS.swift
//  SMART-on-FHIR
//
//  Created by Pascal Pfiffner on 6/25/14.
//  Copyright (c) 2014 SMART Platforms. All rights reserved.
//

import UIKit


extension Auth
{
	/** Open a URL in the OS' browser. */
	func openURLInBrowser(url: NSURL) -> Bool {
		authContext = UIApplication.sharedApplication().keyWindow?.rootViewController
		return UIApplication.sharedApplication().openURL(url)
	}
	
	/**
		Shows a modal web view on the key window's root view controller to let the user log in and authorize the app.
		Can be automatically dismissed on success.
	 */
	func authorizeEmbedded(oauth: OAuth2, granularity: SMARTAuthGranularity) {
		if let root = UIApplication.sharedApplication().keyWindow?.rootViewController {
			authContext = root
			oauth.authorizeEmbeddedFrom(root, params: nil)
			if granularity != .PatientSelectNative {
				oauth.afterAuthorizeOrFailure = { wasFailure, error in
					self.dismissEmbedded()
				}
			}
		}
		else {
			authDidFail(genOAuth2Error("No root view controller, cannot present authorize screen"))
		}
	}
	
	func showPatientList(parameters: JSONDictionary) {
		if let root = authContext as? UIViewController ?? UIApplication.sharedApplication().keyWindow?.rootViewController {
			
			// instantiate patient list view
			let view = PatientListViewController(list: PatientListAll(), server: self.server)
			view.title = self.oauth?.viewTitle
			view.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .Done, target: view, action: "dismissFromModal:")
			view.onPatientSelect = { patient in
				var params = parameters
				if let pat = patient {
					params["patient"] = pat.id
					params["patient_resource"] = pat
				}
				self.processAuthCallback(parameters: params, error: nil)
			}
			
			// present on root view controller
			let navi = UINavigationController(rootViewController: view)
			if nil != root.presentedViewController {		// assumes the login screen is the presented view
				root.dismissViewControllerAnimated(false) {
					root.presentViewController(navi, animated: false, completion: nil)
				}
			}
			else {
				root.presentViewController(navi, animated: true, completion: nil)
			}
		}
		else {
			authDidFail(genOAuth2Error("No root view controller in authorization context, cannot present patient list"))
		}
	}
	
	func dismissEmbedded() {
		if let root = authContext as? UIViewController {
			root.dismissViewControllerAnimated(true, completion: nil)
		}
	}
}

