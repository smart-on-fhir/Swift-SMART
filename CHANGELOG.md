Changelog
=========

## 4.2

- Add support for Swift Package Manager; deprecate CocoaPod support.


## 4.1

- Update to Swift 5.0


## 4.0

- Update to FHIR **R4** (`4.0.0-a53ec6ee1b`)
- Update to Swift 4.2


## 3.2.0

- Address Swift 3.2 compiler warnings

## 3.0.1

- Address Swift 3.1 compiler warnings


## 3.0

- Update to FHIR **STU-3** (`3.0.0.11832`)


## 2.9

- Update to FHIR `1.6.0.9663`


## 2.8

- Update to Swift 3.0


## 2.4

- Update to FHIR `1.6.0.9663`
- (still on Swift 2.2)


## 2.3

- Update to Swift 2.3


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
