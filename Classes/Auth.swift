//
//  Auth.swift
//  SMART-on-FHIR
//
//  Created by Pascal Pfiffner on 6/11/14.
//  Copyright (c) 2014 SMART Health IT. All rights reserved.
//

import Foundation


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
	
	/**
		Settings to be used to initialize the OAuth2 subclass. Supported keys:
	
		- client_id
		- registration_uri
		- authorize_uri
		- token_uri
		- title
	 */
	var settings: OAuth2JSON?
	
	/// The server this instance belongs to
	unowned let server: Server
	
	/// The authentication object, used internally.
	var oauth: OAuth2?
	
	/// The configuration for the authorization in progress.
	var authProperties: SMARTAuthProperties?
	
	/// Context used during authorization to pass OS-specific information, handled in the extensions.
	var authContext: AnyObject?
	
	/// The closure to call when authorization finishes.
	var authCallback: ((parameters: OAuth2JSON?, error: NSError?) -> ())?
	
	
	/** Designated initializer. */
	init(type: AuthMethod, server: Server, settings: OAuth2JSON?) {
		self.type = type
		self.server = server
		self.settings = settings
		if let sett = self.settings {
			self.configureWith(sett)
		}
	}
	
	
	// MARK: - Factory & Setup
	
	class func fromConformanceSecurity(security: ConformanceRestSecurity, server: Server, settings: OAuth2JSON?) -> Auth? {
		var authSettings = settings ?? OAuth2JSON(minimumCapacity: 3)
		var hasAuthURI = false
		var hasTokenURI = false
		
		if let services = security.service {
			for service in services {
				logIfDebug("Server supports REST security via \(service.text ?? nil)")
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
		if let extensions = security.extension_fhir {
			for ext in extensions {
				if let urlString = ext.url?.absoluteString {
					switch urlString {
					case "http://fhir-registry.smarthealthit.org/StructureDefinition/oauth-uris#register":
						authSettings["registration_uri"] = ext.valueUri?.absoluteString
					case "http://fhir-registry.smarthealthit.org/StructureDefinition/oauth-uris#authorize":
						authSettings["authorize_uri"] = ext.valueUri?.absoluteString
						hasAuthURI = true
					case "http://fhir-registry.smarthealthit.org/StructureDefinition/oauth-uris#token":
						authSettings["token_uri"] = ext.valueUri?.absoluteString
						hasTokenURI = true
					default:
						break
					}
				}
			}
		}
		
		if hasAuthURI {
			return Auth(type: hasTokenURI ? .CodeGrant : .ImplicitGrant, server: server, settings: authSettings)
		}
		
		logIfDebug("Unsupported security services, will proceed without authorization method")
		return nil
	}
	
	
	/**
		Finalize instance setup based on type and the a settings dictionary.
	
		:param: settings A dictionary with auth settings, passed on to OAuth2*()
	 */
	func configureWith(settings: OAuth2JSON) {
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
			if let ttl = settings["title"] as? String {
				oa.viewTitle = ttl
			}
			oa.onAuthorize = authDidSucceed
			oa.onFailure = authDidFail
			#if DEBUG
			oa.verbose = true
			#endif
		}
	}
	
	
	// MARK: - OAuth
	
	/**
		Starts the authorization flow, either by opening an embedded web view or switching to the browser.
	
		Automatically adds the correct "launch*" scope, according to the authorization property granularity.
	
		If you use the OS browser to authorize, remember that you need to intercept the callback from the browser and
		call the client's `didRedirect()` method, which redirects to this instance's `handleRedirect()` method.
	
		If selecting a patient is part of the authorization flow, will add a "patient" key with the patient-id to the
		returned dictionary. On native patient selection adds a "patient_resource" key with the patient resource.
	 */
	func authorize(properties: SMARTAuthProperties, callback: (parameters: OAuth2JSON?, error: NSError?) -> Void) {
		if nil != authCallback {
			abort()
		}
		
		authProperties = properties
		authCallback = callback
		
		// authorization via OAuth2
		if let oa = oauth {
			if oa.hasUnexpiredAccessToken() && properties.granularity != .PatientSelectWeb {
				logIfDebug("Have an unexpired access token and don't need web patient selection: not requesting a new token")
				authDidSucceed(OAuth2JSON(minimumCapacity: 0))
				return
			}
			
			// adjust the scope for desired auth properties
			var scope = oa.scope ?? "user/*.* openid profile"		// plus "launch" or "launch/patient", if needed
			// TODO: clean existing "launch" scope if it's already contained
			switch properties.granularity {
				case .TokenOnly:
					break
				case .LaunchContext:
					scope = "launch \(scope)"
				case .PatientSelectWeb:
					scope = "launch/patient \(scope)"
				case .PatientSelectNative:
					break
			}
			oa.scope = scope
			
			// start authorization
			authContext = nil
			if properties.embedded {
				authorizeEmbedded(oa, granularity: properties.granularity)
			}
			else {
				openURLInBrowser(oa.authorizeURL())
			}
		}
			
		// open server?
		else if .None == type {
			authDidSucceed(OAuth2JSON(minimumCapacity: 0))
		}
		
		else {
			authDidFail(genSMARTError("I am not yet set up to authorize"))
		}
	}
	
	func handleRedirect(redirect: NSURL) -> Bool {
		if nil == oauth || nil == authCallback {
			return false
		}
		
		oauth!.handleRedirectURL(redirect)
		return true
	}
	
	internal func authDidSucceed(parameters: OAuth2JSON) {
		if nil != authProperties && authProperties!.granularity == .PatientSelectNative {		// Swift 1.1 compiler crashes with authProperties?.granularity
			logIfDebug("Showing native patient selector after authorizing with parameters \(parameters)")
			showPatientList(parameters)
		}
		else {
			logIfDebug("Did authorize with parameters \(parameters)")
			processAuthCallback(parameters: parameters, error: nil)
		}
	}
	
	internal func authDidFail(error: NSError?) {
		logIfDebug("Failed to authorize with error: \(error)")
		self.processAuthCallback(parameters: nil, error: error)
	}
	
	func abort() {
		logIfDebug("Aborting authorization")
		processAuthCallback(parameters: nil, error: nil)
	}
	
	func processAuthCallback(# parameters: OAuth2JSON?, error: NSError?) {
		if nil != authCallback {
			authCallback!(parameters: parameters, error: error)
			authCallback = nil
		}
	}
	
	
	// MARK: - Requests
	
	/** Returns a signed request, nil if the receiver cannot produce a signed request. */
	func signedRequest(url: NSURL) -> NSMutableURLRequest? {
		return oauth?.request(forURL: url)
	}
}

