//
//  Auth.swift
//  SMART-on-FHIR
//
//  Created by Pascal Pfiffner on 6/11/14.
//  Copyright (c) 2014 SMART Platforms. All rights reserved.
//

import Foundation
import OAuth2iOS			// TODO: figure out a way to use the iOS framework as simply "OAuth2"


enum AuthMethod {
	case None
	case ImplicitGrant
	case CodeGrant
}


/**
	Describes the OAuth2 authentication method to be used.
 */
class Auth
{
	/// The authentication method to use.
	let type: AuthMethod
	
	/// Settings to be used to initialize the OAuth2 subclass.
	var settings: NSDictionary?
	
	/// The authentication object, used internally.
	var oauth: OAuth2?
	
	/// The closure to call when authorization finishes.
	var authCallback: ((patientId: String?, error: NSError?) -> ())?
	
	
	/** Designated initializer. */
	init(type: AuthMethod, settings: NSDictionary?) {
		self.type = type
		self.settings = settings
		if nil != self.settings {
			self.configureWith(self.settings!)
		}
	}
	
	
	var clientId: String? {
		get { return oauth?.clientId ?? (settings?["client_id"] as? String) }
	}
	
	var patientId: String?
	
	
	// MARK: - Factory & Setup
	
	class func fromConformanceSecurity(security: ConformanceRestSecurity, settings: NSDictionary?) -> Auth? {
		var authSettings = (settings?.mutableCopy() as NSMutableDictionary) ?? NSMutableDictionary()
		var hasAuthURI = false
		var hasTokenURI = false
		
		if let services = security.service {
			for service in services {
				logIfDebug("Server supports REST security via \(service.text ?? nil))")
				if let codings = service.coding {
					for coding in codings {
						logIfDebug("-- \(coding.code) (\(coding.system))")
						if "OAuth2" == coding.code? {
							// TODO: support multiple Auth methods per server?
						}
					}
				}
			}
		}
		
		// SMART OAuth2 endpoints are at rest[0].security.extension[#].valueUri
		// TODO: Grahame's server puts the SMART extensions on the top level?
		if let extensions = security.fhirExtension {
			for ext in extensions {
				if let urlString = ext.url?.absoluteString {
					switch urlString {
					case "http://fhir-registry.smartplatforms.org/Profile/oauth-uris#register":
						authSettings["registration_uri"] = ext.valueUri?.absoluteString
					case "http://fhir-registry.smartplatforms.org/Profile/oauth-uris#authorize":
						authSettings["authorize_uri"] = ext.valueUri?.absoluteString
						hasAuthURI = true
					case "http://fhir-registry.smartplatforms.org/Profile/oauth-uris#token":
						authSettings["token_uri"] = ext.valueUri?.absoluteString
						hasTokenURI = true
					default:
						break
					}
				}
			}
		}
		
		if hasAuthURI {
			return Auth(type: hasTokenURI ? .CodeGrant : .ImplicitGrant, settings: authSettings)
		}
		
		logIfDebug("Unsupported security services, will proceed without an authorization method")
		return nil
	}
	
	
	/**
		Finalize instance setup based on type and the a settings dictionary.
	
		:param: settings A dictionary with auth settings, passed on to OAuth2*()
	 */
	func configureWith(settings: NSDictionary) {
		switch type {
		case .CodeGrant:
			oauth = OAuth2CodeGrant(settings: settings)
		case .ImplicitGrant:
			oauth = OAuth2ImplicitGrant(settings: settings)
		case .None:
			oauth = nil
		}
		
		// configure the OAuth2 instance's callbacks
		if let oa = oauth {
			oa.onAuthorize = { parameters in
				if let patient = parameters["patient"] as? String {
					logIfDebug("Did receive patient with id \(patient)")
					self.processAuthCallback(patientId: patient, error: nil)
				}
				else {
					logIfDebug("Did handle redirect but do not have a patient context, returning without patient")
					self.processAuthCallback(patientId: nil, error: nil)
				}
			}
			oa.onFailure = { error in
				self.processAuthCallback(patientId: nil, error: error)
			}
			#if DEBUG
			oa.verbose = true
			#endif
		}
	}
	
	
	// MARK: - OAuth
	
	/**
		Starts the authorization flow, either by opening an embedded web view or switching to the browser.
	
		If you set `embedded` to false remember that you need to intercept the callback from the browser and call
		the client's `didRedirect()` method, which redirects to this instance's `handleRedirect()` method.
	 */
	func authorize(embedded: Bool, callback: (patientId: String?, error: NSError?) -> Void) {
		if nil != authCallback {
			processAuthCallback(patientId: nil, error: genSMARTError("Timeout", nil))
		}
		
		if nil != oauth {
			authCallback = callback
			if embedded {
				authorizeEmbedded(oauth!)
			}
			else {
				openURLInBrowser(oauth!.authorizeURL())
			}
		}
		else {
			let err: NSError? = (.None == type) ? nil : genSMARTError("I am not yet set up to authorize, missing a handle to my oauth instance", nil)
			callback(patientId: nil, error: err)
		}
	}
	
	func handleRedirect(redirect: NSURL) -> Bool {
		if nil == oauth || nil == authCallback {
			return false
		}
		
		oauth!.handleRedirectURL(redirect)
		return true
	}
	
	func abort() {
		processAuthCallback(patientId: nil, error: nil)
	}
	
	func processAuthCallback(# patientId: String?, error: NSError?) {
		if nil != authCallback {
			authCallback!(patientId: patientId, error: error)
			authCallback = nil
		}
	}
	
	
	// MARK: - Requests
	
	/** Returns a signed request, nil if the receiver cannot produce a signed request. */
	func signedRequest(url: NSURL) -> NSMutableURLRequest? {
		return oauth?.request(forURL: url)
	}
}

