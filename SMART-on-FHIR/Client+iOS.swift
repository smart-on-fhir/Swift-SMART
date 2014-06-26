//
//  Client+iOS.swift
//  SMART-on-FHIR
//
//  Created by Pascal Pfiffner on 6/25/14.
//  Copyright (c) 2014 SMART Platforms. All rights reserved.
//

import UIKit


extension Client {
	
	/*! Open a URL in the OS' browser */
	func openURL(url: NSURL) -> Bool {
		return UIApplication.sharedApplication().openURL(url)
	}
}

