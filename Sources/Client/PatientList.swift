//
//  PatientList.swift
//  SMART-on-FHIR
//
//  Created by Pascal Pfiffner on 2/4/15.
//  Copyright (c) 2015 SMART Health IT. All rights reserved.
//

import Foundation


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
public class PatientList {
	
	/// Current list status.
	public var status: PatientListStatus = .Unknown {
		didSet {
			onStatusUpdate?(lastStatusError)
			lastStatusError = nil
		}
	}
	private var lastStatusError: FHIRError? = nil
	
	/// A block executed whenever the receiver's status changes.
	public var onStatusUpdate: (FHIRError? -> Void)?
	
	/// The patients currently in this list.
	var patients: [Patient]? {
		didSet {
			// make sure the expected number of patients is at least as high as the number of patients we have
			expectedNumberOfPatients = max(expectedNumberOfPatients, actualNumberOfPatients)
			createSections()
			onPatientUpdate?()
		}
	}
	
	/// A block to be called when the `patients` property changes.
	public var onPatientUpdate: (Void -> Void)?
	
	private(set) public var expectedNumberOfPatients: UInt = 0
	
	/// The number of patients currently in the list.
	public var actualNumberOfPatients: UInt {
		return UInt(patients?.count ?? 0)
	}
	
	var sections: [PatientListSection] = []
	
	public var numSections: Int {
		return sections.count
	}
	
	internal(set) public var sectionIndexTitles: [String] = []
	
	/// How to order the list.
	public var order = PatientListOrder.NameFamilyASC
	
	/// The query used to create the list.
	public let query: PatientListQuery
	
	/// Indicating whether not all patients have yet been loaded.
	public var hasMore: Bool {
		return query.search.hasMore
	}
	
	
	public init(query: PatientListQuery) {
		self.query = query
		self.status = .Initialized
	}
	
	
	// MARK: - Patients & Sections
	
	subscript(index: Int) -> PatientListSection? {
		if sections.count > index {
			return sections[index]
		}
		return nil
	}
	
	/**
	Create sections from our patients. On iOS we could use UILocalizedCollection, but it's cumbersome on
	non-NSObject subclasses. Assumes that the patient list is already ordered
	*/
	func createSections() {
		if let patients = self.patients {
			sections = [PatientListSection]()
			sectionIndexTitles = [String]()
			
			var n = 0
			var lastTitle: Character = "$"
			var lastSection = PatientListSection(title: "")
			for patient in patients {
				let pre: Character = patient.displayNameFamilyGiven.characters.first ?? "$"    // TODO: use another method depending on current ordering
				if pre != lastTitle {
					lastTitle = pre
					lastSection = PatientListSection(title: String(lastTitle))
					lastSection.offset = n
					sections.append(lastSection)
					sectionIndexTitles.append(lastSection.title)
				}
				lastSection.addPatient(patient)
				n += 1
			}
			
			// not all patients fetched yet?
			if actualNumberOfPatients < expectedNumberOfPatients {
				let sham = PatientListSectionPlaceholder(title: "↓")
				sham.holdingForNumPatients = expectedNumberOfPatients - actualNumberOfPatients
				sections.append(sham)
				sectionIndexTitles.append(sham.title)
			}
		}
		else {
			sections = []
			sectionIndexTitles = []
		}
	}
	
	
	// MARK: - Patient Loading
	
	/**
	Executes the patient query against the given FHIR server and updates the receiver's `patients` property when done.
	
	- parameter server: A FHIRServer instance to query the patients from
	*/
	public func retrieve(server: FHIRServer) {
		patients = nil
		expectedNumberOfPatients = 0
		query.reset()
		retrieveBatch(server)
	}
	
	/**
	Attempts to retrieve the next batch of patients. You should check `hasMore` before calling this method.
	
	- parameter server: A FHIRServer instance to retrieve the batch from
	*/
	public func retrieveMore(server: FHIRServer) {
		retrieveBatch(server, appendPatients: true)
	}
	
	func retrieveBatch(server: FHIRServer, appendPatients: Bool = false) {
		status = .Loading
		query.execute(server, order: order) { [weak self] bundle, error in
			if let this = self {
				if let error = error {
					print("ERROR running patient query: \(error)")
					this.lastStatusError = error
					callOnMainThread() {
						this.status = .Ready
					}
				}
				else {
					var patients: [Patient]? = nil
					var expTotal: UInt? = nil
					
					// extract patient resources from the search result bundle
					if let bndle = bundle {
						if let total = bndle.total {
							expTotal = total
						}
						
						if let entries = bndle.entry {
							let newPatients = entries
								.filter() { $0.resource is Patient }
								.map() { $0.resource as! Patient }
							
							let append = appendPatients && nil != this.patients
							patients = this.order.ordered(append ? this.patients! + newPatients : newPatients)
						}
					}
					
					callOnMainThread() {
						if let total = expTotal {
							this.expectedNumberOfPatients = total
						}
						// when patients is nil, only set this.patients to nil if appendPatients is false
						// otherwise we might reset the list to no patients when hitting a 404 or a timeout
						if nil != patients || !appendPatients {
							this.patients = patients
						}
						this.status = .Ready
					}
				}
			}
		}
	}
}


/**
A patient list holding all available patients.
*/
public class PatientListAll: PatientList {
	
	public init() {
		let search = FHIRSearch(query: [])
		search.pageCount = 50
		
		super.init(query: PatientListQuery(search: search))
	}
}


/**
Patients are divided into sections, e.g. by first letter of their family name. This class holds patients belonging
to one section.
*/
public class PatientListSection {
	
	public var title: String
	var patients: [Patient]?
	var numPatients: UInt {
		return UInt(patients?.count ?? 0)
	}
	
	/// How many patients are in sections coming before this one. Only valid in context of a PatientList.
	public var offset: Int = 0
	
	public init(title: String) {
		self.title = title
	}
	
	func addPatient(patient: Patient) {
		if nil == patients {
			patients = [Patient]()
		}
		patients!.append(patient)
	}
	
	subscript(index: Int) -> Patient? {
		if let patients = patients where patients.count > index {
			return patients[index]
		}
		return nil
	}
}

class PatientListSectionPlaceholder: PatientListSection {
	
	override var numPatients: UInt {
		return holdingForNumPatients
	}
	var holdingForNumPatients: UInt = 0
}

