//
//  Log.swift
//  Sigfood
//
//  Created by Kett, Oliver on 25.11.15.
//  Copyright © 2015 Kett, Oliver. All rights reserved.
//

import Foundation

func Log(message: AnyObject, filename: StaticString = __FILE__, function: StaticString = __FUNCTION__, line: UInt = __LINE__) {
    #if DEBUG
        let file = NSURL(fileURLWithPath: String(filename)).lastPathComponent ?? String()
        NSLog("[\(file):\(line)] \(function) - \(message)")
    #endif
}