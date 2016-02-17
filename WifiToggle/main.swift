//
//  main.swift
//  WifiToggle
//
//  Created by Kett, Oliver on 06.11.15.
//  Copyright © 2015 Kett, Oliver. All rights reserved.
//

import Foundation
import SystemConfiguration
import CoreWLAN

func set_wifi_power(power: Bool) -> Bool {
    // on Yosemite and later, we use CoreWLAN WifiClient
    if #available(OSX 10.10, *) {
        if let interfaces = CWWiFiClient.interfaceNames() {
            for interface in interfaces {
                if let interface = CWWiFiClient()?.interfaceWithName(interface) {
                    do {
                        try interface.setPower(power)
                        NSLog("set Wifi Power for \(interface.interfaceName!) to \(power)")
                    } catch {
                        NSLog("error: \(error)")
                        return false
                    }
                }
            }
        }
    } else {
        // we use CWInterface for older OS X releases
        if let interfaces = CWInterface.interfaceNames() {
            for interface in interfaces {
                // entitlement com.apple.wifi.set_power is required, so no sandboxing is allowed
                do {
                    try CWInterface(name: interface).setPower(power)
                    NSLog("set Wifi Power for \(interface) to \(power)")
                } catch {
                    NSLog("error: \(error)")
                    return false
                }
            }
        }
    }
    return true
}

func NetworkInterfaceCopyMediaOptions(interface: SCNetworkInterfaceRef) -> (NSDictionary, NSDictionary, NSArray)? {
    var ptrActive = Unmanaged<CFDictionary>?()
    var ptrCurrent = Unmanaged<CFDictionary>?()
    var ptrAvailable = Unmanaged<CFArray>?()
    SCNetworkInterfaceCopyMediaOptions(interface, &ptrActive, &ptrCurrent, &ptrAvailable, false)
    if let active = ptrActive?.takeRetainedValue(),
        let current = ptrCurrent?.takeRetainedValue(),
        let available = ptrAvailable?.takeRetainedValue() {
            return (active as NSDictionary, current as NSDictionary, available as NSArray)
    }
    return nil
}

func check_media_status() {
    
    var ethernet = false
    var wifi = false
    
    let interfaces = SCNetworkInterfaceCopyAll() as Array
    for i in 0..<interfaces.count {
        let interface = interfaces[i] as! SCNetworkInterface
        if let interface_type = SCNetworkInterfaceGetInterfaceType(interface) {
            if interface_type == "Ethernet" {
                if let (_, current, _) = NetworkInterfaceCopyMediaOptions(interface) {
                    if let mediaType = current["MediaSubType"] as! String? {
                        if mediaType.rangeOfString("baseT") != nil {
                            // we have a ethernet link
                            ethernet = true
                        }
                    }
                }
            } else if interface_type == "IEEE80211" {
                if NetworkInterfaceCopyMediaOptions(interface) == nil {
                    // wifi is disabled
                    wifi = false
                } else {
                    wifi = true
                }
            }
        }
    }
    
    if ethernet == true && wifi == true {
        set_wifi_power(false)
    }
    if ethernet == false && wifi == false {
        set_wifi_power(true)
    }
    // on ethernet == true && wifi == false we don't need to change anything
    // on ethernet == false && wifi == true we don't need to change anything
}

func updateKeys(store: SCDynamicStore) -> Array<String> {
    guard let interfaces = SCDynamicStoreCopyValue(store, "State:/Network/Interface") as! NSDictionary?,
        let interface_array = interfaces["Interfaces"] as! NSArray? else {
            NSLog("Error: could not find any network interfaces")
            exit(2)
    }
    var keys = [
        "State:/Network/Global/IPv6",
        "State:/Network/Global/IPv4",
        "State:/Network/Interface"
    ]
    for interface in interface_array {
        if interface as! String == "lo0" {
            continue
        }
        if let _ = SCDynamicStoreCopyValue(store, "State:/Network/Interface/\(interface)/Link") {
            keys.append("State:/Network/Interface/\(interface)/Link")
        }
        if let _ = SCDynamicStoreCopyValue(store, "State:/Network/Interface/\(interface)/AirPort") {
            keys.append("State:/Network/Interface/\(interface)/AirPort")
        }
    }
    return keys
}

func callback(store: SCDynamicStoreRef, changedKeys: CFArrayRef, info: UnsafeMutablePointer<Void>) {
    Log(changedKeys)
    for key in changedKeys as Array {
        if key as! String == "State:/Network/Interface" {
            Log("Network hardware changed, restart CFRunLoop")
            CFRunLoopStop(CFRunLoopGetCurrent())
        }
    }
    check_media_status()
}

func start(pidfile: String) {
    // get a callback on every network change: https://github.com/chetan51/sidestep/blob/master/NetworkNotifier.m
    // https://developer.apple.com/library/mac/documentation/Networking/Reference/SCDynamicStore/#//apple_ref/c/tdef/SCDynamicStoreContext
    
    let pid = String(NSProcessInfo().processIdentifier)
    do {
        try pid.writeToFile(pidfile, atomically: true, encoding: NSASCIIStringEncoding)
    } catch {
        NSLog("error writing pid to \(pidfile)")
    }
    
    let bundleIdentifier = NSBundle.mainBundle().bundleIdentifier ?? "WifiToggle"
    guard let store = SCDynamicStoreCreate(nil, bundleIdentifier, callback, nil) else {
        NSLog("Error: cannot create SCDynamicStore!")
        exit(1)
    }
    
    // CFRunLoop is stopped in the callback function and here restarted with the updated keys
    while true {
        SCDynamicStoreSetNotificationKeys(store, updateKeys(store), nil)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), SCDynamicStoreCreateRunLoopSource(nil, store, 0), kCFRunLoopDefaultMode)
        CFRunLoopRun()
    }
}

func stop(pidfile: String) {
    do {
        if let oldpid = try Int32(String(contentsOfFile: pidfile)) {
            kill(oldpid, SIGKILL)
        }
    } catch {
        Log("can't read pid file at \(pidfile)")
    }
    if NSFileManager.defaultManager().fileExistsAtPath(pidfile) {
        do {
            try NSFileManager.defaultManager().removeItemAtPath(pidfile)
        } catch {
            Log("error removing \(pidfile)")
        }
    }
}

if getuid() != 0 {
    print("error: run me as root!")
    exit(1)
}

let pidfile = "/var/run/WifiToggle.pid"

switch Process.arguments[1] {
    case "--start":
        stop(pidfile)
        start(pidfile)
    case "--stop":
        stop(pidfile)
    case "--version":
        print("WifiToggle 1.0.0")
    default:
        // print usage
        print("usage: WifiToggle COMMAND")
        print("\nAvailable commands (there must be exactly one):")
        print("\t--start")
        print("\t\t starts this program in daemon mode. You should use launchd(8) to start automatically.")
        print("\t--stop")
        print("\t\tend daemon")
        print("\nThis tools monitors all network interfaces connected and disables the Wifi interface if a wired connection is established.")
}

