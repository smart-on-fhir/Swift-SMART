//
//  PatientList.swift
//  SMART-on-FHIR
//
//  Created by Pascal Pfiffner on 2/4/15.
//  Copyright (c) 2015 SMART Health IT. All rights reserved.
//

import Foundation


public enum PatientListStatus: Int {
	case unknown
	case initialized
	case loading
	case ready
}


/**
 *  A class to hold a list of patients, created from a query performed against a FHIRServer.
 *
 *  The `retrieve` method must be called at least once so the list can start retrieving patients from the server. Use
 *  the `onStatusUpdate` and `onPatientUpdate` blocks to keep informed about status changes.
 *
 *  You can use subscript syntax to safely retrieve a patient from the list: patientList[5]
 */
open class PatientList {
	
	/// Current list status.
	open var status: PatientListStatus = .unknown {
		didSet {
			onStatusUpdate?(lastStatusError)
			lastStatusError = nil
		}
	}
	fileprivate var lastStatusError: FHIRError? = nil
	
	/// A block executed whenever the receiver's status changes.
	open var onStatusUpdate: ((FHIRError?) -> Void)?
	
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
	open var onPatientUpdate: ((Void) -> Void)?
	
	fileprivate(set) open var expectedNumberOfPatients: UInt = 0
	
	/// The number of patients currently in the list.
	open var actualNumberOfPatients: UInt {
		return UInt(patients?.count ?? 0)
	}
	
	var sections: [PatientListSection] = []
	
	open var numSections: Int {
		return sections.count
	}
	
	open internal(set) var sectionIndexTitles: [String] = []
	
	/// How to order the list.
	open var order = PatientListOrder.nameFamilyASC
	
	/// The query used to create the list.
	open let query: PatientListQuery
	
	/// Indicating whether not all patients have yet been loaded.
	open var hasMore: Bool {
		return query.search.hasMore
	}
	
	
	public init(query: PatientListQuery) {
		self.query = query
		self.status = .initialized
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
				lastSection.add(patient: patient)
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
	
	- parameter fromServer: A FHIRServer instance to query the patients from
	*/
	open func retrieve(fromServer server: FHIRServer) {
		patients = nil
		expectedNumberOfPatients = 0
		query.reset()
		retrieveBatch(fromServer: server)
	}
	
	/**
	Attempts to retrieve the next batch of patients. You should check `hasMore` before calling this method.
	
	- parameter fromServer: A FHIRServer instance to retrieve the batch from
	*/
	open func retrieveMore(fromServer server: FHIRServer) {
		retrieveBatch(fromServer: server, appendPatients: true)
	}
	
	func retrieveBatch(fromServer server: FHIRServer, appendPatients: Bool = false) {
		status = .loading
		query.execute(onServer: server, order: order) { [weak self] bundle, error in
			if let this = self {
				if let error = error {
					print("ERROR running patient query: \(error)")
					this.lastStatusError = error
					callOnMainThread() {
						this.status = .ready
					}
				}
				else {
					var patients: [Patient]? = nil
					var expTotal: Int32? = nil
					
					// extract patient resources from the search result bundle
					if let bndle = bundle {
						if let total = bndle.total?.int32 {
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
							this.expectedNumberOfPatients = UInt(total)
						}
						// when patients is nil, only set this.patients to nil if appendPatients is false
						// otherwise we might reset the list to no patients when hitting a 404 or a timeout
						if nil != patients || !appendPatients {
							this.patients = patients
						}
						this.status = .ready
					}
				}
			}
		}
	}
}


/**
A patient list holding all available patients.
*/
open class PatientListAll: PatientList {
	
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
open class PatientListSection {
	
	open var title: String
	var patients: [Patient]?
	var numPatients: UInt {
		return UInt(patients?.count ?? 0)
	}
	
	/// How many patients are in sections coming before this one. Only valid in context of a PatientList.
	open var offset: Int = 0
	
	public init(title: String) {
		self.title = title
	}
	
	func add(patient: Patient) {
		if nil == patients {
			patients = [Patient]()
		}
		patients!.append(patient)
	}
	
	subscript(index: Int) -> Patient? {
		if let patients = patients, patients.count > index {
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

