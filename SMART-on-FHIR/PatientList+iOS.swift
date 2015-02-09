//
//  PatientList+iOS.swift
//  SMART-on-FHIR
//
//  Created by Pascal Pfiffner on 2/4/15.
//  Copyright (c) 2015 SMART Platforms. All rights reserved.
//

import UIKit
import SwiftFHIR


public class PatientListViewController: UITableViewController
{
	/// The patient list to display.
	var patientList: PatientList?
	
	/// The server from which to retrieve the patient list.
	var server: FHIRServer?
	
	/// Block to execute when a patient has been selected.
	var onPatientSelect: ((patient: Patient?) -> Void)?
	
	var didSelectPatient = false
	
	var runningOutOfPatients: Bool = false {
		didSet {
			loadMorePatientsIfNeeded()
		}
	}
	
	lazy var activity = UIActivityIndicatorView(activityIndicatorStyle: .Gray)
	
	
	public init(list: PatientList, server srv: FHIRServer) {
		patientList = list
		server = srv
		super.init(nibName: nil, bundle: nil)
	}
	
	public required init(coder aDecoder: NSCoder) {
	    super.init(coder: aDecoder)
	}
	
	
	// MARK: - View Tasks
	
	public override func viewDidLoad() {
		self.tableView.registerClass(PatientTableViewCell.self, forCellReuseIdentifier: "PatientCell")
		
		// show an activity indicator whenever the list's status is "loading"
		patientList?.onStatusUpdate = { [weak self] in
			if let this = self {
				if nil != this.patientList && .Loading == this.patientList!.status {
					this.navigationItem.leftBarButtonItem = UIBarButtonItem(customView: this.activity!)
					this.activity!.startAnimating()
				}
				else {
					this.activity!.stopAnimating()
					this.navigationItem.leftBarButtonItem = nil
				}
			}
		}
		
		// reload the table whenever the list updates
		patientList?.onPatientUpdate = { [weak self] in
			if let this = self {
				this.tableView.reloadData()
				dispatch_async(dispatch_get_main_queue()) {
					this.loadMorePatientsIfNeeded()
				}
			}
		}
	}
	
	public override func viewWillAppear(animated: Bool) {
		super.viewWillAppear(animated)
		if 0 == patientList?.actualNumberOfPatients {
			patientList?.retrieve(server!)
		}
	}
	
	public override func viewWillDisappear(animated: Bool) {
		super.viewWillDisappear(animated)
		if !didSelectPatient {
			onPatientSelect?(patient: nil)
		}
	}
	
	public func dismissFromModal(sender: AnyObject?) {
		presentingViewController?.dismissViewControllerAnimated(nil != sender, completion: nil)
	}
	
	
	// MARK: - Patient Loading
	
	func loadMorePatientsIfNeeded() {
		if runningOutOfPatients && nil != patientList && patientList!.hasMore {
			loadMorePatients()
		}
	}
	
	func loadMorePatients() {
		if let srv = server {
			patientList?.retrieveMore(srv)
		}
	}
	
	
	// MARK: - Table View
	
	public override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
		return patientList?.numSections ?? 0
	}
	
	public override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		if let section = patientList?[section] {
			return section.numPatients
		}
		return 0
	}
	
	public override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCellWithIdentifier("PatientCell", forIndexPath: indexPath) as PatientTableViewCell
		if let section = patientList?[indexPath.section] {
			cell.represent(section[indexPath.row])
			
			let marker = min(patientList!.expectedNumberOfPatients, section.offset + indexPath.row + 10)
			runningOutOfPatients = (marker > patientList!.actualNumberOfPatients)
		}
		return cell
	}
	
	public override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
		if let patient = patientList?[indexPath] {
			didSelectPatient = true
			onPatientSelect?(patient: patient)
		}
		tableView.deselectRowAtIndexPath(indexPath, animated: true)
	}
	
	
	// MARK: - Table View Sections
	
	public override func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
		if let section = patientList?[section] {
			return section.title
		}
		return nil
	}
	
	public override func sectionIndexTitlesForTableView(tableView: UITableView) -> [AnyObject]! {
		return patientList?.sectionIndexTitles
	}
}


extension Patient
{
	var genderSymbol: String {
		return ("male" == gender) ? "♂" : "♀"
	}
}


class PatientTableViewCell: UITableViewCell
{
	override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
		super.init(style: .Subtitle, reuseIdentifier: reuseIdentifier)
	}

	required init(coder aDecoder: NSCoder) {
		super.init(coder: aDecoder)
	}
	
	func represent(patient: Patient?) {
		textLabel?.text = patient?.displayNameFamilyGiven
		detailTextLabel?.text = patient?.birthDate?.description
		
		if let pat = patient {
			let gender = accessoryView as? UILabel ?? UILabel(frame: CGRectMake(0, 0, 38, 38))
			gender.font = UIFont.systemFontOfSize(22.0)
			gender.textAlignment = .Center
			gender.text = pat.genderSymbol
			accessoryView = gender
		}
		else {
			accessoryView = nil
		}
	}
}

