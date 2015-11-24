//
//  Client+iOS.swift
//  SMART-on-FHIR
//
//  Created by Pascal Pfiffner on 6/25/14.
//  Copyright (c) 2014 SMART Health IT. All rights reserved.
//

import UIKit


extension Auth
{
	/** Make the current root view controller the authorization context and show the view controller corresponding to the auth properties.
	 */
	func authorizeWith(oauth: OAuth2, properties: SMARTAuthProperties) {
		authContext = UIApplication.sharedApplication().keyWindow?.rootViewController
		
		oauth.authConfig.authorizeContext = authContext
		oauth.authConfig.authorizeEmbedded = properties.embedded
		oauth.authorize(params: ["aud": server.aud], autoDismiss: properties.granularity != .PatientSelectNative)
	}
	
	/** Show the native patient list on the current authContext or the window's root view controller. */
	func showPatientList(parameters: OAuth2JSON) {
		if let root = authContext as? UIViewController ?? UIApplication.sharedApplication().keyWindow?.rootViewController {
			
			// instantiate patient list view
			let view = PatientListViewController(list: PatientListAll(), server: self.server)
			view.title = self.oauth?.authConfig.ui.title
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
			authDidFail(OAuth2Error.InvalidAuthorizationContext)
		}
	}
}

