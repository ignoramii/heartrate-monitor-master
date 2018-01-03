//
//  HeartRatePeripheral.swift
//  heartrate-monitor
//
//  Created by kosuke miyoshi on 2015/07/02.
//  Copyright (c) 2015年 kosuke miyoshi. All rights reserved.
//

import Foundation
import CoreBluetooth

struct HeartRateFlags {
	// 1bit
	var hr_format: UInt8
	// 2bit
	var sensor_contact: UInt8
	// 1bit
	var energy_expended: UInt8
	// 1bit
	var rr_interval: UInt8

	init(flag: UInt8) {
		hr_format = flag & 0x1;
		sensor_contact = (flag >> 1) & 0x3;
		energy_expended = (flag >> 3) & 0x1;
		rr_interval = (flag >> 4) & 0x1;
	}

	/**
	* get byte size of hr value
	*/
	func getHRSize() -> Int {
		return Int(hr_format) + 1;
	}
}

class HeartRatePerihepral: NSObject, CBPeripheralDelegate {
	let HEART_RATE_SERVICE: String = "180D"
	let HEART_RATE_MEASUREMENT: String = "2A37"

	weak var delegate: HeartRateDelegate!

	init(delegate: HeartRateDelegate) {
		self.delegate = delegate
	}

	func setup(_ peripheral: CBPeripheral) {
		peripheral.delegate = self;
		// NOTE you might only discover HR service, but on this example we discover all services
		peripheral.discoverServices(nil)
	}

	func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {

		print("didDiscoverServices")

		if error != nil {
			return;
		}

		for service in peripheral.services! {
			if service.uuid == CBUUID(string: HEART_RATE_SERVICE) {
				let service: CBService = service as CBService;
				peripheral.discoverCharacteristics(nil, for: service);
			}
		}
	}

	func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService,
					error: Error?) {

		print("didDiscoverCharacteristicsForService")

		if error != nil {
			return;
		}

		if service.uuid == CBUUID(string: HEART_RATE_SERVICE) {
			for character in service.characteristics! {
				let ch: CBCharacteristic = character as CBCharacteristic;
				if ch.uuid == CBUUID(string: HEART_RATE_MEASUREMENT) {
					peripheral.setNotifyValue(true, for: ch)
				}
			}
		}
	}

    func getUInt16Value(_ dataPtr: UnsafePointer<UInt8>, offset: Int) -> UInt16 {
		let value0: UInt32 = UInt32(dataPtr[offset + 1])
		let value1: UInt32 = UInt32(dataPtr[offset])
		return UInt16(value0 << 8 + value1)
	}

    var previousDate: Date = Date()
    var nextDate: Date = Date()
    var count = 0
    
	func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic,
					error: Error?) {

		if error != nil {
			return;
		}

		if characteristic.uuid == CBUUID(string: HEART_RATE_MEASUREMENT) {
			let value: Data? = characteristic.value
            nextDate = Date()
			let dataPtr: UnsafePointer<UInt8> = (value! as NSData).bytes.bindMemory(to: UInt8.self, capacity: value!.count)
			let dataSize: Int = value!.count

			let flags: UInt8 = dataPtr[0]
			let heartRateFlags = HeartRateFlags(flag: flags)

            let df = DateFormatter()
            df.dateFormat = "HH:mm:ss.SSS"
            
			// hr value
			var offset: Int = 1
            var hrValue8: UInt8 = 0
            let hrValue16: UInt16
            let timeInterval: Double
            
            if count == 0 {
                print ("Count, HeartRate, Time, TimeInterval")
            }
            
			if heartRateFlags.getHRSize() == 2 {
				// 2byte
				hrValue16 = getUInt16Value(dataPtr, offset: offset)
                timeInterval = nextDate.timeIntervalSince(previousDate)
				print("\(count), \(hrValue16), \(df.string(from: Date())), \(timeInterval)")
				offset += 2
			} else {
				// 1byte
				hrValue8 = dataPtr[offset];
                timeInterval = nextDate.timeIntervalSince(previousDate)
                
				offset += 1
			}
            
            previousDate = nextDate
            count += 1
            
            // RR interval value
            if heartRateFlags.rr_interval != 0 {
                while offset < dataSize {
                    // 2byte
                    let rrValue: UInt16 = getUInt16Value(dataPtr, offset: offset)
                    let rr: Double = (Double(rrValue) / 1024.0) * 1000.0
                    print("\(count), \(hrValue8), \(df.string(from: Date())), \(timeInterval), \(rr)")
                    
                    //print("rr=\(rr)")
                    delegate.heartRateRRDidArrive(rr)
                    offset += 2
                }
            }
            
            
			// energy value
			if heartRateFlags.energy_expended != 0 {
				// 2byte
				let energyValue: UInt16 = getUInt16Value(dataPtr, offset: offset)
				print("energy=\(energyValue)")
				offset += 2
			}

			// RR interval value
			if heartRateFlags.rr_interval != 0 {
				while offset < dataSize {
					// 2byte
					let rrValue: UInt16 = getUInt16Value(dataPtr, offset: offset)
					let rr: Double = (Double(rrValue) / 1024.0) * 1000.0
					print("rr=\(rr)")
					delegate.heartRateRRDidArrive(rr)
					offset += 2
				}
			}
		}
	}
}
