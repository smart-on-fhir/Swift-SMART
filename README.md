<p align="center"><img src="./assets/banner.png" alt=""></p>

Swift-SMART is a full client implementation of the 🔥FHIR specification for building apps that interact with healthcare data through [**SMART on FHIR**][smart].
Written in _Swift 3_ it is compatible with **iOS 8** and **OS X 10.10** and newer and requires Xcode 8 or newer.


### Versioning

Due to the complications of combining two volatile technologies, here's an overview of which version numbers use which **Swift** and **FHIR versions**.

- The [`master`](https://github.com/smart-on-fhir/Swift-SMART) branch should always compile and is on (point releases of) these main versions.
- The [`develop`](https://github.com/smart-on-fhir/Swift-SMART/tree/develop) branch should be on versions corresponding to the latest freezes and may be updated from time to time with the latest and greatest CI build.

See [tags/releases](https://github.com/smart-on-fhir/Swift-SMART/releases).

 Version |   Swift   |      FHIR     | &nbsp;
---------|-----------|---------------|-----------------------------
 **3.0** |       3.0 | `3.0.0.11832` | STU 3
 **2.9** |       3.0 |  `1.6.0.9663` | STU 3 Ballot, Sep 2016
 **2.8** |       3.0 |  `1.0.2.7202` | DSTU 2 (_+ technical errata_)
 **2.4** |       2.2 |  `1.6.0.9663` | STU 3 Ballot, Sep 2016
 **2.3** |       2.3 |  `1.0.2.7202` | DSTU 2 (_+ technical errata_)
**2.2.3**|       2.2 |  `1.0.2.7202` | DSTU 2 (_+ technical errata_)
 **2.2** |   2.0-2.2 |  `1.0.2.7202` | DSTU 2 (_+ technical errata_)
 **2.1** |   2.0-2.2 |  `1.0.1.7108` | DSTU 2
 **2.0** |   2.0-2.2 |  `0.5.0.5149` | DSTU 2 Ballot, May 2015
 **1.0** |       1.2 |  `0.5.0.5149` | DSTU 2 Ballot, May 2015
 **0.2** |       1.1 |  `0.5.0.5149` | DSTU 2 Ballot, May 2015
 **0.1** |       1.0 | `0.0.81.2382` | DSTU 1


Resources
---------

- [Programming Guide][wiki] with code examples
- [Technical Documentation][docs] of classes, properties and methods
- [Medication List][sample] sample app
- [SMART on FHIR][smart] API documentation

[wiki]: https://github.com/smart-on-fhir/Swift-SMART/wiki
[docs]: http://docs.smarthealthit.org/Swift-SMART/
[sample]: https://github.com/smart-on-fhir/SoF-MedList
[smart]: http://docs.smarthealthit.org


QuickStart
----------

See [the programming guide][wiki] for more code examples and details.

The following is the minimal setup working against our reference implementation.
It is assuming that you don't have a `client_id` and on first authentication will **register the client with our server**, then proceed to retrieve a token.
If you know your client-id you can specify it in the settings dict.
The app must also register the `redirect` URL scheme so it can be notified when authentication completes.

```swift
import SMART

// create the client
let smart = Client(
    baseURL: URL(string: "https://fhir-api-dstu2.smarthealthit.org")!,
    settings: [
        //"client_id": "my_mobile_app",       // if you have one
        "redirect": "smartapp://callback",    // must be registered
    ]
)

// authorize, then search for prescriptions
smart.authorize() { patient, error in
    if nil != error || nil == patient {
        // report error
    }
    else {
        MedicationOrder.search(["patient": patient!.id])
        .perform(smart.server) { bundle, error in
            if nil != error {
                // report error
            }
            else {
                var meds = bundle?.entry?
                    .filter() { return $0.resource is MedicationOrder }
                    .map() { return $0.resource as! MedicationOrder }
                
                // now `meds` holds all the patient's orders (or is nil)
            }
        }
    }
}
```

For authorization to work with Safari/SFViewController, you also need to:

1. register the scheme (such as `smartapp` in the example here) in your app's `Info.plist` and
2. intercept the callback in your app delegate, like so:

```swift
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    func application(_ app: UIApplication, open url: URL,
        options: [UIApplicationOpenURLOptionsKey: Any] = [:]) -> Bool {
        
        // "smart" is your SMART `Client` instance
        if smart.awaitingAuthCallback {
            return smart.didRedirect(to: url)
        }
        return false
    }
}
```


Installation
------------

The suggested approach is to add _Swift-SMART_ as a git submodule to your project.
Find detailed instructions on how this is done on the [Installation page][installation].

The framework can also be installed via _Carthage_ and is also available via _CocoaPods_ under the name [“SMART”][pod].

[installation]: https://github.com/smart-on-fhir/Swift-SMART/wiki/Installation
[pod]: https://cocoapods.org/pods/SMART


License
-------

This work is [Apache 2](./LICENSE.txt) licensed: [NOTICE.txt](./NOTICE.txt).
FHIR® is the registered trademark of [HL7][] and is used with the permission of HL7.

[hl7]: http://hl7.org/
