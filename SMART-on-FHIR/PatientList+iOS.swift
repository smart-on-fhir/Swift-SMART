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
	var patientList: PatientList?
	
	var server: FHIRServer?
	
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
		patientList?.onStatusUpdate = {
			if nil != self.patientList && .Loading == self.patientList!.status {
				let activity = UIActivityIndicatorView(activityIndicatorStyle: .Gray)
				self.navigationItem.leftBarButtonItem = UIBarButtonItem(customView: activity)
				activity.startAnimating()
			}
			else {
				self.navigationItem.leftBarButtonItem = nil
			}
		}
		
		// reload the table whenever the list updates
		patientList?.onPatientUpdate = {
			self.tableView.reloadData()
		}
	}
	
	public override func viewWillAppear(animated: Bool) {
		super.viewWillAppear(animated)
		patientList?.retrieve(server!)
	}
	
	
	// MARK: - Table View
	
	public override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
		return 1
	}
	
	public override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return (0 == section && nil != patientList) ? patientList!.numberOfPatients : 0
	}
	
	public override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCellWithIdentifier("PatientCell", forIndexPath: indexPath) as PatientTableViewCell
		if 0 == indexPath.section {
			if let patient = patientList?.patients?[indexPath.row] {
				cell.represent(patient)
			}
		}
		return cell
	}
}


extension Patient
{
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
	
	func represent(patient: Patient) {
		textLabel?.text = patient.displayNameFamilyGiven
		detailTextLabel?.text = patient.birthDate?.description
		
		let gender = accessoryView as? UILabel ?? UILabel(frame: CGRectMake(0, 0, 38, 38))
		gender.font = UIFont.systemFontOfSize(22.0)
		gender.textAlignment = .Center
		gender.text = patient.genderSymbol
		accessoryView = gender
	}
}

