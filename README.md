SMART on FHIR
=============

This is an iOS and OS X framework for building apps that interact with healthcare data through [**SMART on FHIR**](http://docs.smartplatforms.org).
Written in _Swift_ it is compatible with **iOS 8** and **OS X 10.9** and later.
Building the framework requires Xcode 6 or later.

The `master` branch is currently on FHIR _DSTU 1_.  
The `develop` branch is work in progress for FHIR _DSTU 2_.

We have a simple [medication list](https://github.com/p2/SoF-MedList) sample app so you can see how you use the framework.

The first versions of this framework did not contain auto-generated classes, hence some parts are still manually implemented as opposed to using actual FHIR resources.
As such the `Bundle` resource is still missing, all data is retrieved via a REST API.


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

### Dynamic Client Registration

Our sandbox also supports _dynamic client registration_, which is based on the OAuth 2.0 Dynamic Client Registration [protocol](http://tools.ietf.org/html/draft-ietf-oauth-dyn-reg-17) and the Blue Button open registration [specification](http://blue-button.github.io/blue-button-plus-pull/#registration-open).
You can register your app by posting an appropriately formatted JSON app manifest to the registration server, the app manifest looks like this:

```json
{
	"client_name": "Smart-on-FHIR iOS Med List",
	"redirect_uris": [
		"sofmedlist://callback"
	],
	"token_endpoint_auth_method": "none",
	"grant_types": [
		"authorization_code"
	],
	"logo_uri": "https://srv.me/img/cool.jpg",
	"scope": "launch/patient user/*.* patient/*.read openid profile"
}
```

You can POST this manifest to [https://authorize.smartplatforms.org/register]() for registration with our sandbox server, or any SMART on FHIR server for that matter.

