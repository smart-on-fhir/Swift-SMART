![](assets/banner.png)

Swift-SMART is a full client implementation of the 🔥FHIR specification for building apps that interact with healthcare data through [**SMART on FHIR**](http://docs.smarthealthit.org).
Written in _Swift_ it is compatible with **iOS 8** and **OS X 10.9** and newer and requires Xcode 6 or newer.

The `master` branch is currently on FHIR _DSTU 1_ ([`0.0.82`](https://github.com/smart-on-fhir/Swift-SMART/releases/tag/FHIR-0.0.82)).  
The `develop` branch is up-to-date for the FHIR _DSTU 2_ May 2015 ballot ([`0.5.0`](https://github.com/smart-on-fhir/Swift-SMART/releases/tag/FHIR-0.5.0)).

There are [tags](https://github.com/smart-on-fhir/Swift-SMART/releases) indicating which data models are baked into the framework.
Compare those to the list of [published FHIR versions](http://hl7.org/fhir/directory.html).


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
