SMART on FHIR
=============

This is an iOS and OS X framework for building apps that interact with healthcare data through [**SMART on FHIR**](http://docs.smartplatforms.org).
Written in _Swift_ it is compatible with **iOS 8** and **OS X 10.9** and later and requires Xcode 6 or later.
You can target **iOS 7** by including all source files in your main project rather than using the embedded framework target.

We have a simple [medication list](https://github.com/p2/SoF-MedList) sample app so you can see how you use the framework.

The `master` branch is currently on FHIR _DSTU 1_.  
The `develop` branch is work in progress for FHIR _DSTU 2_.


Installation
------------

Use `git` to obtain the framework.
Using Terminal.app, navigate to your project directory and execute:

    $ git clone --recursive https://github.com/smart-on-fhir/SMART-on-FHIR-Cocoa

This will download the latest codebase and all dependencies.
Once this process completes open your app project in Xcode and add `SMART-on-FHIR.xcodeproj`.


Documentation
-------------

Technical documentation for framework usage TBD.
Make sure to take a look at the [official SMART on FHIR documentation](http://docs.smartplatforms.org).

> **Note:** The SMART framework contains the [FHIR data models framework](https://github.com/smart-on-fhir/Swift-FHIR).
> These are compiled into the framework, you will need to `import SMART` in your source files.


Running Apps
------------

Apps running against a SMART provider must be **registered** with the server.
If you are simply testing grounds you can use our sandbox server and the shared `my_mobile_app` client-id:

```Swift
@lazy var smart = Client(
    serverURL: "https://fhir-api.smartplatforms.org",
    clientId: "my_mobile_app",
    redirect: "smartapp://callback"    // must match a registered redirect uri
)
```
