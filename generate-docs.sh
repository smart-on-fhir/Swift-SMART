#!/bin/bash
#
#  Build documentation using jazzy:
#    [sudo] gem install jazzy

jazzy \
	-r "http://smart-on-fhir.github.io/Swift-SMART" \
	-o "docs" \
	--module-version "2.8.2"

mkdir docs/assets 2>/dev/null
cp assets/banner.png docs/assets/
