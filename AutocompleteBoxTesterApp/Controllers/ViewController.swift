//
//  ViewController.swift
//  AutocompleteBoxTesterApp
//
//  Created by sphota on 1/13/20.
//  Copyright © 2020 alevkov. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
  
  @IBOutlet weak var box: AutocompleteBox!

  override func viewDidLoad() {
    super.viewDidLoad()
    box.clipsToBounds = true
    box.layer.borderWidth = 1.5
    box.layer.borderColor = UIColor.black.cgColor
  }
}

