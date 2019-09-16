#!/bin/bash
#
#  Build documentation using jazzy:
#    [sudo] gem install jazzy

jazzy \
	-r "http://smart-on-fhir.github.io/Swift-SMART" \
	-o "docs" \
	--module-version "4.2.0"

mkdir docs/assets 2>/dev/null
cp assets/banner.png docs/assets/
