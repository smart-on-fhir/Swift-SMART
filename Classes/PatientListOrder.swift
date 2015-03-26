//
//  PatientListOrder.swift
//  SMART-on-FHIR
//
//  Created by Pascal Pfiffner on 2/9/15.
//  Copyright (c) 2015 SMART Platforms. All rights reserved.
//

import Foundation


public enum PatientListOrder: String
{
	/// Order by given name, family name, birthday
	case NameGivenASC = "given:asc,family:asc,birthdate:asc"
	
	// Order by family name, given name, birthday
	case NameFamilyASC = "family:asc,given:asc,birthdate:asc"
	
	/// Order by birthdate, family name, given name
	case BirthDateASC = "birthdate:asc,family:asc,given:asc"
	
	/**
		Applies the receiver's ordering to a given list of patients.
		
		:param patients: A list of Patient instances
		:returns: An ordered list of Patient instances
	 */
	func ordered(patients: [Patient]) -> [Patient] {
		switch self {
		case .NameGivenASC:
			return patients.sorted() {
				let given = $0.compareNameGiven($1)
				if 0 != given {
					return given < 0
				}
				let family = $0.compareNameFamily($1)
				if 0 != family {
					return family < 0
				}
				let birth = $0.compareBirthDate($1)
				return birth < 0
			}
		case .NameFamilyASC:
			return patients.sorted() {
				let family = $0.compareNameFamily($1)
				if 0 != family {
					return family < 0
				}
				let given = $0.compareNameGiven($1)
				if 0 != given {
					return given < 0
				}
				let birth = $0.compareBirthDate($1)
				return birth < 0
			}
		case .BirthDateASC:
			return patients.sorted() {
				let birth = $0.compareBirthDate($1)
				if 0 != birth {
					return birth < 0
				}
				let family = $0.compareNameFamily($1)
				if 0 != family {
					return family < 0
				}
				let given = $0.compareNameGiven($1)
				return given < 0
			}
		}
	}
}


extension Patient
{
	func compareNameGiven(other: Patient) -> Int {
		let a = name?.first?.given?.first ?? "ZZZ"
		let b = other.name?.first?.given?.first ?? "ZZZ"
		if a < b {
			return -1
		}
		if a > b {
			return 1
		}
		// TODO: look at other first names?
		return 0
	}
	
	func compareNameFamily(other: Patient) -> Int {
		let a = name?.first?.family?.first ?? "ZZZ"
		let b = other.name?.first?.family?.first ?? "ZZZ"
		if a < b {
			return -1
		}
		if a > b {
			return 1
		}
		// TODO: lookt at other family names?
		return 0
	}
	
	func compareBirthDate(other: Patient) -> Int {
		let nodate = NSDate(timeIntervalSince1970: -70 * 365.25 * 24 * 3600)
		let a = birthDate?.nsDate ?? nodate
		return a.compare(other.birthDate?.nsDate ?? nodate).rawValue
	}
	
	var displayNameFamilyGiven: String {
		if let humanName = name?.first {
			let given = humanName.given?.reduce(nil) { (nil != $0 ? ($0! + " ") : "") + $1 }
			let family = humanName.family?.reduce(nil) { (nil != $0 ? ($0! + " ") : "") + $1 }
			if nil == given {
				if nil != family {
					let prefix = ("male" == gender) ? "Mr." : "Ms."
					return "\(prefix) \(family!)"
				}
			}
			else {
				if nil != family {
					return "\(family!), \(given!)"
				}
				return given!
			}
		}
		return "Unnamed Patient"
	}
}

