//
//  PatientList.swift
//  SMART-on-FHIR
//
//  Created by Pascal Pfiffner on 2/4/15.
//  Copyright (c) 2015 SMART Platforms. All rights reserved.
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
public class PatientList
{
	/// Current list status
	public var status: PatientListStatus = .Unknown {
		didSet {
			onStatusUpdate?(lastStatusError)
			lastStatusError = nil
		}
	}
	private var lastStatusError: NSError? = nil
	
	/// A block executed whenever the receiver's status changes.
	public var onStatusUpdate: (NSError? -> Void)?
	
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
	
	private(set) public var expectedNumberOfPatients: Int = 0
	
	/// The number of patients currently in the list
	public var actualNumberOfPatients: Int {
		return (nil != patients) ? countElements(patients!) : 0
	}
	
	var sections: [PatientListSection] = []
	
	public var numSections: Int {
		return countElements(sections)
	}
	
	internal(set) public var sectionIndexTitles: [String] = []
	
	/// How to order the list
	public var order = PatientListOrder.NameFamilyASC
	
	/// The query used to create the list.
	public let query: PatientListQuery
	
	/// Indicating whether not all patients have yet been loaded
	public var hasMore: Bool {
		return query.search.hasMore
	}
	
	
	public init(query: PatientListQuery) {
		self.query = query
		self.status = .Initialized
	}
	
	
	// MARK: - Patients & Sections
	
	subscript(index: Int) -> PatientListSection? {
		if countElements(sections) > index {
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
			var lastTitle = "XX"
			var lastSection = PatientListSection(title: "")
			for patient in patients {
				var pre = patient.displayNameFamilyGiven			// TODO: use another method depending on current ordering
				pre = pre[pre.startIndex..<advance(pre.startIndex, 1)]
				if pre != lastTitle {
					lastTitle = pre
					lastSection = PatientListSection(title: lastTitle)
					lastSection.offset = n
					sections.append(lastSection)
					sectionIndexTitles.append(lastSection.title)
				}
				lastSection.addPatient(patient)
				n++
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
					this.lastStatusError = error
					callOnMainThread() {
						this.status = .Ready
					}
				}
				else {
					var patients: [Patient]? = nil
					var expTotal: Int? = nil
					
					// extract patient resources from the search result bundle
					if let bndle = bundle {
						if let total = bndle.total {
							expTotal = total
						}
						
						if let entries = bndle.entry {
							let newPatients = entries
								.filter() { $0.resource is Patient }
								.map() { $0.resource as Patient }
							
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

public class PatientListAll: PatientList
{
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
public class PatientListSection
{
	public var title: String
	var patients: [Patient]?
	var numPatients: Int {
		return (nil != patients) ? countElements(patients!) : 0
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
		if nil != patients && countElements(patients!) > index {
			return patients![index]
		}
		return nil
	}
}

class PatientListSectionPlaceholder: PatientListSection
{
	override var numPatients: Int {
		return holdingForNumPatients
	}
	var holdingForNumPatients: Int = 0
}

