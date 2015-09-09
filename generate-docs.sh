#!/bin/bash
#
#  Build documentation using jazzy:
#    [sudo] gem install jazzy

jazzy \
	-a "SMART Health IT" \
	-u "http://www.smarthealthit.org" \
	-m "SwiftSMART" \
	-g "https://github.com/smart-on-fhir/Swift-SMART" \
	-r "http://smart-on-fhir.github.io/Swift-SMART" \
	-o "docs" \
	--module-version "1.0"
