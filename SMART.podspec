#
#  Swift-SMART
#
#  Swift SMART on FHIR framework for iOS and OS X
#  Enjoy!
#

Pod::Spec.new do |s|
  s.name         = "SMART"
  s.version      = "2.1"
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
  s.osx.deployment_target = "10.9"
  s.requires_arc          = true
  s.source_files          = "Classes/*", "Swift-FHIR/Classes/*", "Swift-FHIR/Models/*", "OAuth2/SwiftKeychain/SwiftKeychain/Keychain/*.swift", "OAuth2/OAuth2/*.swift"
  s.ios.source_files      = "Classes+iOS/*", "OAuth2/OAuth2+iOS/*"
  s.osx.source_files      = "Classes+OSX/*", "OAuth2/OAuth2+OSX/*"
end
