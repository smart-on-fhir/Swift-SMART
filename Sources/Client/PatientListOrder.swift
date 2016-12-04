//
//  PatientListOrder.swift
//  SMART-on-FHIR
//
//  Created by Pascal Pfiffner on 2/9/15.
//  Copyright (c) 2015 SMART Health IT. All rights reserved.
//

import Foundation


/**
An enum to define how a list of patients should be ordered.
*/
public enum PatientListOrder: String {
	
	/// Order by given name, family name, birthday.
	case nameGivenASC = "given:asc,family:asc,birthdate:asc"
	
	// Order by family name, given name, birthday.
	case nameFamilyASC = "family:asc,given:asc,birthdate:asc"
	
	/// Order by birthdate, family name, given name.
	case birthDateASC = "birthdate:asc,family:asc,given:asc"
	
	/**
	Applies the receiver's ordering to a given list of patients.
	
	- parameter patients: A list of Patient instances
	- returns: An ordered list of Patient instances
	*/
	func ordered(_ patients: [Patient]) -> [Patient] {
		switch self {
		case .nameGivenASC:
			return patients.sorted() {
				let given = $0.compareNameGiven(toPatient: $1)
				if 0 != given {
					return given < 0
				}
				let family = $0.compareNameFamily(toPatient: $1)
				if 0 != family {
					return family < 0
				}
				let birth = $0.compareBirthDate(toPatient: $1)
				return birth < 0
			}
		case .nameFamilyASC:
			return patients.sorted() {
				let family = $0.compareNameFamily(toPatient: $1)
				if 0 != family {
					return family < 0
				}
				let given = $0.compareNameGiven(toPatient: $1)
				if 0 != given {
					return given < 0
				}
				let birth = $0.compareBirthDate(toPatient: $1)
				return birth < 0
			}
		case .birthDateASC:
			return patients.sorted() {
				let birth = $0.compareBirthDate(toPatient: $1)
				if 0 != birth {
					return birth < 0
				}
				let family = $0.compareNameFamily(toPatient: $1)
				if 0 != family {
					return family < 0
				}
				let given = $0.compareNameGiven(toPatient: $1)
				return given < 0
			}
		}
	}
}


extension Patient {
	
	func compareNameGiven(toPatient: Patient) -> Int {
		let a = name?.first?.given?.first ?? "ZZZ"
		let b = toPatient.name?.first?.given?.first ?? "ZZZ"
		if a < b {
			return -1
		}
		if a > b {
			return 1
		}
		// TODO: look at other first names?
		return 0
	}
	
	func compareNameFamily(toPatient: Patient) -> Int {
		let a = name?.first?.family?.first ?? "ZZZ"
		let b = toPatient.name?.first?.family?.first ?? "ZZZ"
		if a < b {
			return -1
		}
		if a > b {
			return 1
		}
		// TODO: lookt at other family names?
		return 0
	}
	
	func compareBirthDate(toPatient: Patient) -> Int {
		let nodate = Date(timeIntervalSince1970: -70 * 365.25 * 24 * 3600)
		let a = birthDate?.nsDate ?? nodate
		return a.compare(toPatient.birthDate?.nsDate ?? nodate).rawValue
	}
	
	var displayNameFamilyGiven: String {
		if let humanName = name?.first {
			let given = humanName.given?.reduce(nil) { (nil != $0 ? ($0! + " ") : "") + $1 }
			let family = humanName.family?.reduce(nil) { (nil != $0 ? ($0! + " ") : "") + $1 }
			if nil == given {
				if nil != family {
					let prefix = ("male" == gender) ? "Mr.".fhir_localized : "Ms.".fhir_localized
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
		return "Unnamed Patient".fhir_localized
	}
	
	var currentAge: String {
		if nil == birthDate {
			return ""
		}
		
		let calendar = Calendar.current
		var comps = calendar.dateComponents([.year, .month], from: birthDate!.nsDate, to: Date())
		
		// babies
		if comps.year! < 1 {
			if comps.month! < 1 {
				comps = calendar.dateComponents([.day], from: birthDate!.nsDate, to: Date())
				if comps.day! < 1 {
					return "just born".fhir_localized
				}
				let str = (1 == comps.day) ? "day old".fhir_localized : "days old".fhir_localized
				return "\(comps.day ?? 0) \(str)"
			}
			let str = (1 == comps.day) ? "month old".fhir_localized : "months old".fhir_localized
			return "\(comps.month ?? 0) \(str)"
		}
		
		// kids and adults
		if 0 != comps.month {
			let yr = (1 == comps.year) ? "yr".fhir_localized : "yrs".fhir_localized
			let mth = (1 == comps.month) ? "mth".fhir_localized : "mths".fhir_localized
			return "\(comps.year ?? 0) \(yr), \(comps.month ?? 0) \(mth)"
		}
		
		let yr = (1 == comps.year) ? "year old".fhir_localized : "years old".fhir_localized
		return "\(comps.year ?? 0) \(yr)"
	}
}

