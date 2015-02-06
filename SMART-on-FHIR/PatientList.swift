//
//  PatientList.swift
//  SMART-on-FHIR
//
//  Created by Pascal Pfiffner on 2/4/15.
//  Copyright (c) 2015 SMART Platforms. All rights reserved.
//

import Foundation
import SwiftFHIR


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

public enum PatientListStatus: Int {
	case Unknown
	case Initialized
	case Loading
	case Ready
}


/**
 *  A class to hold a list of patients, created from a query performed against a FHIRServer.
 *
 *  The `retrieve` method must be called at least once so the list can start retrieving patients from the server. Use
 *  the `onStatusUpdate` and `onPatientUpdate` blocks to keep informed about status changes.
 *
 *  You can use subscript syntax to safely retrieve a patient from the list: patientList[5]
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
			// make sure the expected number of patients is at least as high as the number of patients we have
			expectedNumberOfPatients = max(expectedNumberOfPatients, actualNumberOfPatients)
			onPatientUpdate?()
		}
	}
	
	/// A block to be called when the `patients` property changes.
	public var onPatientUpdate: (Void -> Void)?
	
	private(set) public var expectedNumberOfPatients: Int = 0
	
	/// The number of patients currently in the list
	public var actualNumberOfPatients: Int {
		return (nil != patients) ? countElements(patients!) : 0
	}
	
	/// How to order the list
	public var order = PatientListOrder.NameFamilyASC
	
	/// The query used to create the list.
	let query: PatientListQuery
	
	/// Indicating whether not all patients have yet been loaded
	public var hasMore: Bool {
		return query.search.hasMore
	}
	
	
	public init(query: PatientListQuery) {
		self.query = query
		self.status = .Initialized
	}
	
	
	// MARK: - Patient Handling
	
	subscript(index: Int) -> Patient? {
		if nil == patients || countElements(patients!) <= index {
			return nil
		}
		return patients![index]
	}
	
	
	/**
		Executes the patient query against the given FHIR server and updates the receiver's `patients` property when
		done.
	
		:param server: A FHIRServer instance to query the patients from
	 */
	public func retrieve(server: FHIRServer) {
		patients = nil
		expectedNumberOfPatients = 0
		query.reset()
		retrieveBatch(server)
	}
	
	/** Attempts to retrieve the next batch of patients. You should check `hasMore` before calling this method. */
	public func retrieveMore(server: FHIRServer) {
		retrieveBatch(server, appendPatients: true)
	}
	
	func retrieveBatch(server: FHIRServer, appendPatients: Bool = false) {
		status = .Loading
		query.execute(server, order: order) { [weak self] bundle, error in
			if let this = self {
				if nil != error {
					println("ERROR running patient query: \(error!.localizedDescription)")
					callOnMainThread() {
						this.status = .Ready
					}
				}
				else {
					callOnMainThread() {
						if nil != bundle {
							if let total = bundle!.total {
								this.expectedNumberOfPatients = total
							}
							
							let patients = bundle!.entry?
								.filter() { $0.resource is Patient }
								.map() { $0.resource as Patient }
							
							if appendPatients && nil != this.patients {
								//this.patients = self.order.ordered(self.patients! + patients!)
								this.patients! += patients!
							}
							else {
								//this.patients = self.order.ordered(patients!)		// already sorted on server
								this.patients = patients
							}
						}
						else if !appendPatients {
							this.patients = nil
						}
						this.status = .Ready
					}
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
	
	var isDone = false
	
	
	public init(search: FHIRSearch) {
		search.profileType = Patient.self
		self.search = search
	}
	
	
	// MARK: - Server Interaction
	
	func reset() {
		isDone = false
	}
	
	func execute(server: FHIRServer, order: PatientListOrder, callback: (bundle: Bundle?, error: NSError?) -> Void) {
		if isDone {
			callback(bundle: nil, error: nil)
			return
		}
		
		let cb: (bundle: Bundle?, error: NSError?) -> Void = { bundle, error in
			if nil != error || nil == bundle {
				callback(bundle: nil, error: error)
			}
			else {
				self.isDone = !self.search.hasMore
				callback(bundle: bundle, error: nil)
			}
		}
		
		// starting fresh, add sorting and page count URL parameters
		if !isDone && !search.hasMore {
			var sort = [(String, String)]()
			let parts = split(order.rawValue) { $0 == "," }
			for part in parts {
				let exp = split(part) { $0 == ":" }
				sort.append((exp[0], exp[1]))
			}
			search.sort = sort
			search.perform(server, callback: cb)
		}
		
		// get next page of results
		else {
			search.nextPage(server, callback: cb)
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
}

