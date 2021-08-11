//
//  ViewController.swift
//  Base58
//
//  Created by adolph.suntao@gmail.com on 08/11/2021.
//  Copyright (c) 2021 adolph.suntao@gmail.com. All rights reserved.
//

import UIKit
import Base58

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        
        Base58.decodeStringToData("132123132")
        
        // Do any additional setup after loading the view, typically from a nib.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

}

