![](assets/banner.png)

Swift-SMART is a full client implementation of the 🔥FHIR specification for building apps that interact with healthcare data through [**SMART on FHIR**](http://docs.smarthealthit.org).
Written in _Swift_ it is compatible with **iOS 8** and **OS X 10.9** and newer and requires Xcode 6 or newer.


### Versioning

Due to the complications of combining two volatile technologies, here's an overview of which version numbers use which **Swift** and **FHIR versions**.
The `master` branch should always compile and is on (point releases of) these main versions.
See the `develop` branch or specific `feature/x` branches for new Swift or FHIR versions, and check the [tags](https://github.com/smart-on-fhir/Swift-FHIR/releases).

Version  | Swift Version | FHIR Version
---------|---------------|-------------
 **1.0** |           1.2 | DSTU 2 (May 2015, `0.5.0.5149`)
 **0.2** |           1.1 | DSTU 2 (May 2015, `0.5.0.5149`)
 **0.1** |           1.0 | DSTU 1 (`0.0.81.2382`)


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

```swift
import SMART

// create the client
let smart = Client(
    baseURL: "https://fhir-api-dstu2.smarthealthit.org",
    settings: [
        "client_id": "my_mobile_app",
        "redirect": "smartapp://callback",    // must be registered
    ]
)

// authorize, then search for prescriptions
smart.authorize() { patient, error in
    if nil != error || nil == patient {
        // report error
    }
    else {
        MedicationPrescription.search(["patient": patient!.id])
        .perform(smart.server) { bundle, error in
            if nil != error {
                // report error
            }
            else {
                var meds = [MedicationPrescription]()
                if let entries = bundle?.entry {
                    for entry in entries {
                        if let med = entry.resource as? MedicationPrescription {
                            meds.append(med)
                        }
                    }
                }
                
                // now `meds` holds all known patient prescriptions
            }
        }
    }
}
```


License
-------

This work is [Apache 2](LICENSE.txt) licensed.
