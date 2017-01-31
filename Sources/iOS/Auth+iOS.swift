//
//  Client+iOS.swift
//  SMART-on-FHIR
//
//  Created by Pascal Pfiffner on 6/25/14.
//  Copyright (c) 2014 SMART Health IT. All rights reserved.
//

import UIKit


extension Auth {
	
	/**
	Make the current root view controller the authorization context and show the view controller corresponding to the auth properties.
	
	- parameter oauth:      The OAuth2 instance to use for authorization
	- parameter properties: SMART authorization properties to use
	- parameter callback:   The callback that is called when authorization completes or fails
	*/
	func authorize(with oauth: OAuth2, properties: SMARTAuthProperties, callback: @escaping ((OAuth2JSON?, OAuth2Error?) -> Void)) {
		authContext = UIApplication.shared.keyWindow?.rootViewController
		
		oauth.authConfig.authorizeContext = authContext
		oauth.authConfig.authorizeEmbedded = properties.embedded
		oauth.authConfig.authorizeEmbeddedAutoDismiss = properties.granularity != .patientSelectNative
		
		oauth.authorize(params: ["aud": server.aud]) { parameters, error in
			if nil != error,
				properties.granularity == .patientSelectNative,   // not auto-dismissing, must do it ourselves
				let vc = oauth.authConfig.authorizeContext as? UIViewController {
				vc.dismiss(animated: true)
			}
			callback(parameters, error)
		}
	}
	
	/**
	Show the native patient list on the current authContext or the window's root view controller.
	
	- parameter withParameters: Additional authorization parameters to pass through
	*/
	func showPatientList(withParameters parameters: OAuth2JSON) {
		guard let root = authContext as? UIViewController ?? UIApplication.shared.keyWindow?.rootViewController else {
			authDidFail(withError: OAuth2Error.invalidAuthorizationContext)
			return
		}
		
		// instantiate patient list view
		let view = PatientListViewController(list: PatientListAll(), server: self.server)
		view.title = self.oauth?.authConfig.ui.title
		let dismiss = #selector(PatientListViewController.dismissFromModal(_:))
		view.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: view, action: dismiss)
		view.onPatientSelect = { patient in
			var params = parameters
			if let patient = patient {
				params["patient"] = patient.id
				params["patient_resource"] = patient
			}
			self.processAuthCallback(parameters: params, error: nil)
		}
		
		// present on root view controller
		let navi = UINavigationController(rootViewController: view)
		if nil != root.presentedViewController {		// assumes the login screen is the presented view
			root.dismiss(animated: false) {
				root.present(navi, animated: false, completion: nil)
			}
		}
		else {
			root.present(navi, animated: true, completion: nil)
		}
	}
}

