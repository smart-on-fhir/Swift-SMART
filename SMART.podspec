#
#  Swift-SMART
#
#  Swift SMART on FHIR framework for iOS and OS X
#  Enjoy!
#

Pod::Spec.new do |s|
  s.name         = "SMART"
  s.version      = "3.0.0"
  s.summary      = "Swift SMART on FHIR framework for iOS and OS X"
  s.description  = <<-DESC
                   Swift SMART on FHIR framework for iOS and OS X.
                   
                   Swift-SMART is a full client implementation of the 🔥FHIR specification for building apps that
                   interact with healthcare data through [**SMART on FHIR**](http://docs.smarthealthit.org).
                   
                   Start with `import SMART` in your source files. Code documentation is available from within
                   Xcode (ALT + click on symbols) and on [smart-on-fhir.github.io/Swift-SMART/](http://smart-on-fhir.github.io/Swift-SMART/).
                   DESC
  s.homepage     = "https://github.com/smart-on-fhir/Swift-SMART"
  s.documentation_url = "http://docs.smarthealthit.org/Swift-SMART/"
  s.license      = "Apache 2"
  s.author       = { "Pascal Pfiffner" => "phase.of.matter@gmail.com" }

  s.source            = { :git => "https://github.com/smart-on-fhir/Swift-SMART.git", :tag => "#{s.version}", :submodules => true }
  s.prepare_command   = "git submodule update --init --recursive"  # The :submodules flag above is not recursive :P

  s.ios.deployment_target = "8.0"
  s.osx.deployment_target = "10.10"

  s.pod_target_xcconfig   = { 'OTHER_SWIFT_FLAGS' => '-DNO_MODEL_IMPORT -DNO_MODULE_IMPORT -DNO_KEYCHAIN_IMPORT' }
  s.source_files          = "Sources/Client/*.swift",
                            "Swift-FHIR/Sources/Models/*.swift",
                            "Swift-FHIR/Sources/Client/DomainResource+Containment.swift",
                            "Swift-FHIR/Sources/Client/Element+Extensions.swift",
                            "Swift-FHIR/Sources/Client/FHIRBaseRequestHandler.swift",
                            "Swift-FHIR/Sources/Client/FHIRMinimalServer.swift",
                            "Swift-FHIR/Sources/Client/FHIROpenServer.swift",
                            "Swift-FHIR/Sources/Client/FHIROperation.swift",
                            "Swift-FHIR/Sources/Client/FHIRSearch.swift",
                            "Swift-FHIR/Sources/Client/FHIRServerDataResponse.swift",
                            "Swift-FHIR/Sources/Client/FHIRString+Localization.swift",
                            "Swift-FHIR/Sources/Client/Patient+SMART.swift",
                            "Swift-FHIR/Sources/Client/Reference+Resolving.swift",
                            "Swift-FHIR/Sources/Client/Resource+Instantiation.swift",
                            "Swift-FHIR/Sources/Client/Resource+Operation.swift",
                            "Swift-FHIR/Sources/Client/Resource+REST.swift",
                            "Swift-FHIR/Sources/Client/ValueSet+Localization.swift",
                            "OAuth2/SwiftKeychain/Keychain/Keychain.swift",
                            "OAuth2/Sources/Base/*.swift",
                            "OAuth2/Sources/Flows/*.swift"
  s.ios.source_files      = "Sources/iOS/*.swift",
                            "OAuth2/Sources/iOS/*.swift"
  s.osx.source_files      = "Sources/macOS/*.swift",
                            "OAuth2/Sources/macOS/*.swift"
end
