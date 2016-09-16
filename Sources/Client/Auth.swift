//
//  Auth.swift
//  SMART-on-FHIR
//
//  Created by Pascal Pfiffner on 6/11/14.
//  Copyright (c) 2014 SMART Health IT. All rights reserved.
//

import Foundation


enum AuthType: String {
	case None = "none"
	case ImplicitGrant = "implicit"
	case CodeGrant = "authorization_code"
	case ClientCredentials = "client_credentials"
}


/**
Describes the OAuth2 authentication method to be used.
*/
class Auth {
	
	/// The authentication type to use.
	let type: AuthType
	
	/**
	Settings to be used to initialize the OAuth2 subclass. Supported keys:
	
	- client_id
	- registration_uri
	- authorize_uri
	- token_uri
	- title
	*/
	var settings: OAuth2JSON?
	
	/// The server this instance belongs to.
	unowned let server: Server
	
	/// The authentication object, used internally.
	var oauth: OAuth2? {
		didSet {
			if let logger = server.logger {
				oauth?.logger = logger
			}
			else if let logger = oauth?.logger {
				server.logger = logger
			}
		}
	}
	
	/// The configuration for the authorization in progress.
	var authProperties: SMARTAuthProperties?
	
	/// Context used during authorization to pass OS-specific information, handled in the extensions.
	var authContext: AnyObject?
	
	/// The closure to call when authorization finishes.
	var authCallback: ((parameters: OAuth2JSON?, error: ErrorType?) -> ())?
	
	
	/**
	Designated initializer.
	
	- parameter type: The authorization type to use
	- parameter server: The server these auth settings apply to
	- parameter settings: Authentication settings
	*/
	init(type: AuthType, server: Server, settings: OAuth2JSON?) {
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
		
		if let services = security.service {
			for service in services {
				server.logger?.debug("SMART", msg: "Server supports REST security via “\(service.text ?? "unknown")”")
				if let codings = service.coding {
					for coding in codings {
						if "OAuth2" == coding.code || "SMART-on-FHIR" == coding.code {
							// TODO: what is this good for anyway?
						}
					}
				}
			}
		}
		
		// SMART OAuth2 endpoints are at rest[0].security.extension[#].valueUri
		if let smartauth = security.extensionsFor("http://fhir-registry.smarthealthit.org/StructureDefinition/oauth-uris")?.first?.extension_fhir {
			for subext in smartauth where nil != subext.url {
				switch subext.url!.absoluteString! {
				case "authorize":
					authSettings["authorize_uri"] = subext.valueUri?.absoluteString
				case "token":
					authSettings["token_uri"] = subext.valueUri?.absoluteString
				case "register":
					authSettings["registration_uri"] = subext.valueUri?.absoluteString
				default:
					break
				}
			}
		}
		
		let hasAuthURI = (nil != authSettings["authorize_uri"])
		if hasAuthURI {
			let hasTokenURI = (nil != authSettings["token_uri"])
			return Auth(type: hasTokenURI ? .CodeGrant : .ImplicitGrant, server: server, settings: authSettings)
		}
		
		server.logger?.warn("SMART", msg: "Unsupported security services, will proceed without authorization method")
		return nil
	}
	
	
	/**
	Finalize instance setup based on type and the a settings dictionary.
	
	- parameter settings: A dictionary with auth settings, passed on to OAuth2*()
	*/
	func configureWith(settings: OAuth2JSON) {
		switch type {
			case .CodeGrant:
				oauth = OAuth2CodeGrant(settings: settings)
			case .ImplicitGrant:
				oauth = OAuth2ImplicitGrant(settings: settings)
			case .ClientCredentials:
				oauth = OAuth2ClientCredentials(settings: settings)
			default:
				oauth = nil
		}
		
		// configure the OAuth2 instance's callbacks
		if let oa = oauth {
			oa.onAuthorize = authDidSucceed
			oa.onFailure = authDidFail
		}
	}
	
	/**
	Reset auth, which includes setting authContext to nil and purging any known access and refresh tokens.
	*/
	func reset() {
		authContext = nil
		oauth?.forgetTokens()
	}
	
	
	// MARK: - OAuth
	
	/**
	Starts the authorization flow, either by opening an embedded web view or switching to the browser.
	
	Automatically adds the correct "launch*" scope, according to the authorization property granularity.
	
	If you use the OS browser to authorize, remember that you need to intercept the callback from the browser and call the client's
	`didRedirect()` method, which redirects to this instance's `handleRedirect()` method.
	
	If selecting a patient is part of the authorization flow, will add a "patient" key with the patient-id to the returned dictionary. On
	native patient selection adds a "patient_resource" key with the patient resource.
	*/
	func authorize(properties: SMARTAuthProperties, callback: (parameters: OAuth2JSON?, error: ErrorType?) -> Void) {
		if nil != authCallback {
			abort()
		}
		
		authProperties = properties
		authCallback = callback
		
		// authorization via OAuth2
		if let oa = oauth {
			if oa.hasUnexpiredAccessToken() {
				if properties.granularity != .PatientSelectWeb {
					server.logger?.debug("SMART", msg: "Have an unexpired access token and don't need web patient selection: not requesting a new token")
					authDidSucceed(OAuth2JSON(minimumCapacity: 0))
					return
				}
				server.logger?.debug("SMART", msg: "Have an unexpired access token but want web patient selection: starting auth flow")
				oa.forgetTokens()
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
			
			// start authorization (method implemented in iOS and OS X extensions)
			authorizeWith(oa, properties: properties)
		}
			
		// open server?
		else if .None == type {
			authDidSucceed(OAuth2JSON(minimumCapacity: 0))
		}
		
		else {
			authDidFail(FHIRError.Error("I am not yet set up to authorize"))
		}
	}
	
	func handleRedirect(redirect: NSURL) -> Bool {
		guard let oauth = oauth where nil != authCallback else {
			return false
		}
		do {
			try oauth.handleRedirectURL(redirect)
			return true
		}
		catch {}
		return false
	}
	
	internal func authDidSucceed(parameters: OAuth2JSON) {
		if let props = authProperties where props.granularity == .PatientSelectNative {
			server.logger?.debug("SMART", msg: "Showing native patient selector after authorizing with parameters \(parameters)")
			showPatientList(parameters)
		}
		else {
			server.logger?.debug("SMART", msg: "Did authorize with parameters \(parameters)")
			processAuthCallback(parameters: parameters, error: nil)
		}
	}
	
	internal func authDidFail(error: ErrorType?) {
		server.logger?.debug("SMART", msg: "Failed to authorize with error: \(error)")
		authDidFailInternal(error)
		processAuthCallback(parameters: nil, error: error)
	}
	
	func abort() {
		server.logger?.debug("SMART", msg: "Aborting authorization")
		processAuthCallback(parameters: nil, error: nil)
	}
	
	func forgetClientRegistration() {
		oauth?.forgetClient()
	}
	
	func processAuthCallback(parameters  parameters: OAuth2JSON?, error: ErrorType?) {
		if nil != authCallback {
			authCallback!(parameters: parameters, error: error)
			authCallback = nil
		}
	}
	
	
	// MARK: - Requests
	
	/**
	Returns a signed request, nil if the receiver cannot produce a signed request.
	
	- parameter url: The URL to request a resource from
	- returns: A mutable URL request preconfigured and signed
	*/
	func signedRequest(url: NSURL) -> NSMutableURLRequest? {
		return oauth?.request(forURL: url)
	}
}

