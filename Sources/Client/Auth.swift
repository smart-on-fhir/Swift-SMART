//
//  Auth.swift
//  SMART-on-FHIR
//
//  Created by Pascal Pfiffner on 6/11/14.
//  Copyright (c) 2014 SMART Health IT. All rights reserved.
//

import Foundation


/**
The OAuth2-type to use.
*/
enum AuthType: String {
	case none = "none"
	case implicitGrant = "implicit"
	case codeGrant = "authorization_code"
	case clientCredentials = "client_credentials"
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
	var authCallback: ((_ parameters: OAuth2JSON?, _ error: Error?) -> ())?
	
	
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
			self.configure(withSettings: sett)
		}
	}
	
	/**
	Convenience initializer from the server cabability statement's rest.security parts.
	
	- parameter fromCapabilitySecurity: The server cabability statement's rest.security pieces to inspect
	- parameter server:                 The server to use
	- parameter settings:               Settings, mostly passed on to the OAuth2 instance
	*/
	convenience init?(fromCapabilitySecurity security: CapabilityStatementRestSecurity, server: Server, settings: OAuth2JSON?) {
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
		if let smartauth = security.extensions(forURI: "http://fhir-registry.smarthealthit.org/StructureDefinition/oauth-uris")?.first?.extension_fhir {
			for subext in smartauth where nil != subext.url {
				switch subext.url?.absoluteString ?? "" {
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
		if !hasAuthURI {
			server.logger?.warn("SMART", msg: "Unsupported security services, will proceed without authorization method")
			return nil
		}
		let hasTokenURI = (nil != authSettings["token_uri"])
		self.init(type: (hasTokenURI ? .codeGrant : .implicitGrant), server: server, settings: authSettings)
	}
	
	
	// MARK: - Configuration
	
	/**
	Finalize instance setup based on type and the a settings dictionary.
	
	- parameter withSettings: A dictionary with auth settings, passed on to OAuth2*()
	*/
	func configure(withSettings settings: OAuth2JSON) {
		switch type {
		case .codeGrant:
			oauth = OAuth2CodeGrant(settings: settings)
		case .implicitGrant:
			oauth = OAuth2ImplicitGrant(settings: settings)
		case .clientCredentials:
			oauth = OAuth2ClientCredentials(settings: settings)
		default:
			oauth = nil
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
	
	- parameter properties: The authorization properties to use
	- parameter callback:   The callback to call when authorization finishes (or is aborted)
	*/
	func authorize(with properties: SMARTAuthProperties, callback: @escaping ((_ parameters: OAuth2JSON?, _ error: Error?) -> Void)) {
		if nil != authCallback {
			abort()
		}
		
		authProperties = properties
		authCallback = callback
		
		// authorization via OAuth2
		if let oa = oauth {
			if oa.hasUnexpiredAccessToken() {
				if properties.granularity != .patientSelectWeb {
					server.logger?.debug("SMART", msg: "Have an unexpired access token and don't need web patient selection: not requesting a new token")
					authDidSucceed(withParameters: OAuth2JSON(minimumCapacity: 0))
					return
				}
				server.logger?.debug("SMART", msg: "Have an unexpired access token but want web patient selection: starting auth flow")
				oa.forgetTokens()
			}
			
			// adjust the scope for desired auth properties
			var scope = oa.scope ?? "user/*.* openid profile"		// plus "launch" or "launch/patient", if needed
			// TODO: clean existing "launch" scope if it's already contained
			switch properties.granularity {
				case .tokenOnly:
					break
				case .launchContext:
					scope = "launch \(scope)"
				case .patientSelectWeb:
					scope = "launch/patient \(scope)"
				case .patientSelectNative:
					break
			}
			oa.scope = scope
			
			// start authorization (method implemented in iOS and OS X extensions)
			authorize(with: oa, properties: properties) { parameters, error in
				if let error = error {
					self.authDidFail(withError: error)
				}
				else {
					self.authDidSucceed(withParameters: parameters ?? OAuth2JSON())
				}
			}
		}
			
		// open server?
		else if .none == type {
			authDidSucceed(withParameters: OAuth2JSON(minimumCapacity: 0))
		}
		
		else {
			authDidFail(withError: FHIRError.error("I am not yet set up to authorize"))
		}
	}
	
	func handleRedirect(_ redirect: URL) -> Bool {
		guard let oauth = oauth, oauth.isAuthorizing else {
			return false
		}
		do {
			try oauth.handleRedirectURL(redirect)
			return true
		}
		catch {}
		return false
	}
	
	internal func authDidSucceed(withParameters parameters: OAuth2JSON) {
		if let props = authProperties, props.granularity == .patientSelectNative {
			server.logger?.debug("SMART", msg: "Showing native patient selector after authorizing with parameters \(parameters)")
			showPatientList(withParameters: parameters)
		}
		else {
			server.logger?.debug("SMART", msg: "Did authorize with parameters \(parameters)")
			processAuthCallback(parameters: parameters, error: nil)
		}
	}
	
	internal func authDidFail(withError error: Error?) {
		if let error = error {
			server.logger?.debug("SMART", msg: "Failed to authorize with error: \(error)")
		}
		processAuthCallback(parameters: nil, error: error)
	}
	
	func abort() {
		server.logger?.debug("SMART", msg: "Aborting authorization")
		processAuthCallback(parameters: nil, error: nil)
	}
	
	func forgetClientRegistration() {
		oauth?.forgetClient()
	}
	
	func processAuthCallback(parameters: OAuth2JSON?, error: Error?) {
		if nil != authCallback {
			authCallback!(parameters, error)
			authCallback = nil
		}
	}
	
	
	// MARK: - Requests
	
	/**
	Returns a signed request, nil if the receiver cannot produce a signed request.
	
	- parameter forURL: The URL to request a resource from
	- returns:          A URL request preconfigured and signed
	*/
	func signedRequest(forURL url: URL) -> URLRequest? {
		return oauth?.request(forURL: url)
	}
}

