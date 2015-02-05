//
//  PatientList.swift
//  SMART-on-FHIR
//
//  Created by Pascal Pfiffner on 2/4/15.
//  Copyright (c) 2015 SMART Platforms. All rights reserved.
//

import Foundation
import SwiftFHIR


public enum PatientListOrder: Int
{
	/// Order by given name, family name, birthday
	case NameGiven
	
	// Order by family name, given name, birthday
	case NameFamily
	
	/// Order by birthdate, family name, given name
	case BirthDate
	
	/**
		Applies the receiver's ordering to a given list of patients.
		
		:param patients: A list of Patient instances
		:returns: An ordered list of Patient instances
	 */
	func ordered(patients: [Patient]) -> [Patient] {
		switch self {
			case .NameGiven:
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
			case .NameFamily:
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
			case .BirthDate:
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

public enum PatientListStatus: Int {
	case Unknown
	case Initialized
	case Loading
	case Ready
}


/**
 *  A class to hold a list of patients, created from a query performed against a FHIRServer.
 */
public class PatientList
{
	/// Current list status
	public var status: PatientListStatus = .Unknown {
		didSet {
			onStatusUpdate?()
		}
	}
	
	/// A block executed whenever the receiver's status changes.
	public var onStatusUpdate: (Void -> Void)?
	
	/// The patients currently in this list.
	public var patients: [Patient]? {
		didSet {
			onPatientUpdate?()
		}
	}
	
	/// A block to be called when the `patients` property changes.
	public var onPatientUpdate: (Void -> Void)?
	
	/// The number of patients currently in the list
	public var numberOfPatients: Int {
		return (nil != patients) ? countElements(patients!) : 0
	}
	
	/// How to order the list
	public var order = PatientListOrder.BirthDate
	
	/// The query used to create the list.
	let query: PatientListQuery
	
	public init(query: PatientListQuery) {
		self.query = query
		self.status = .Initialized
	}
	
	
	// MARK: - Patient Retrieval
	
	/**
		Executes the patient query against the given FHIR server and updates the receiver's `patients` property when
		done.
	
		:param server: A FHIRServer instance to query the patients from
	 */
	public func retrieve(server: FHIRServer) {
		status = .Loading
		query.execute(server) { patients, error in
			if nil != error {
				println("ERROR running patient query: \(error!.localizedDescription)")
			}
			else {
				let ordered = self.order.ordered(patients ?? [Patient]())
				callOnMainThread() {
					self.patients = ordered
					self.status = .Ready
				}
			}
		}
	}
}


/**
 *  A query that returns a list of patients.
 */
public class PatientListQuery
{
	let search: FHIRSearch
	
	public init(search: FHIRSearch) {
		search.profileType = Patient.self
		self.search = search
	}
	
	
	func execute(server: FHIRServer, callback: (patients: [Patient]?, error: NSError?) -> Void) {
		search.perform(server) { bundle, error in
			if nil != error || nil == bundle {
				callback(patients: nil, error: error)
			}
			else {
				let patients = bundle!.entry?
					.filter() { $0.resource is Patient }
					.map() { $0.resource as Patient }
				
				callback(patients: patients, error: nil)
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
		let comp = a.compare(other.birthDate?.nsDate ?? nodate)
		if .OrderedAscending == comp {
			return -1
		}
		if .OrderedDescending == comp {
			return 1
		}
		return 0
	}
}

