Changelog
=========


## 2.8.2

- Do not request summary of `Conformance`, which does not include rest.security


## 2.8.1

- Make `Server` open to allow subclassing


## 2.8

- Update to Swift 3.0


## 2.3

- Update for Swift 2.3


## 2.2.4

- Support resolving bundled references
- Some logging improvements


## 2.2.3

- Address deprecation warnings appearing with Swift 2.2 (now requires Swift 2.2)


## 2.2.2

- Implement automatic dynamic client registration if the client has no `client_id`
- Reorganize source files for future compatibility with the Swift Package Manager

## 2.2.1

- Update Podspec for CocoaPods compatibility

## 2.2

- Update to FHIR `1.0.2.7202` (DSTU 2 with technical errata, compatible with `1.0.1`)
- Add a very simple base implementation of `FHIRServer` called `FHIROpenServer`, which also serves as superclass for our SMART `Server` class
- New error handling using `FHIRError`
- Implement absolute reference resolver (will not work if the other server is protected)
- Fixes to `ElementDefinition`
- Only request the `Conformance` statement's summary

## 2.1

- Update to FHIR `1.0.1.7108` (official DSTU 2)
- Improved request and authorization aborting

## 2.0

- Update to Swift 2.0


## 1.0

- Update to swift 1.2

## 0.2

- Update to FHIR `0.5.0.5149` (DSTU 2 May 2015 ballot version)
- Update to Swift 1.1

## 0.1

- Initial release:
    + FHIR `0.0.81.2382` (DSTU 1)
    + Swift 1.0
