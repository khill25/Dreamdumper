//
//  main.swift
//  dreamdumper64
//
//  Created by Kaili Hill on 1/31/23.
//

import Foundation

print("Opening serial port...")

let enableDebugPrint = false
let expectedBytesToReceive = 12 * 1024 * 1024
let serialPort: SerialPort = SerialPort(path: "/dev/cu.usbmodem14101")

main()

func main() {
    
// Swift is dumb and makes me cast the 8bit ints to 16 before they can be bit shifted
//    let b1: UInt8 = 0x80
//    let b2: UInt8 = 0x37
//    let c1: UInt16 = UInt16((UInt16(b1) << 8) | UInt16(b2))
//    print(String(format: "%04X", c1))
    
    var success = openSerialPort()
    if success {
        print("Reading data...")
        readData()
    } else {
        print("Unable to read data because the serial port was not opened")
    }
}

func openSerialPort() -> Bool {
    do {
        try serialPort.openPort(toReceive: true, andTransmit: false)
        serialPort.setSettings(receiveRate: .baud115200, transmitRate: .baud0, minimumBytesToRead: 1)
        
        print("DONE!")
        return true
    } catch {
        print("Error opening serial port: ")
        print(error)
        return false
    }
}

func readData() {
    
    // get URL to the the documents directory in the sandbox
    let documentsUrl = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0] as NSURL
    // add a filename
    let fileUrl = documentsUrl.appendingPathComponent("rom.dump")
    print("Dump will be written to: '\(fileUrl?.absoluteString ?? "error!")'")
    
    let one_megabyte = 1024 * 1024
    do {
        let byte: UnsafeMutablePointer<UInt8> = UnsafeMutablePointer<UInt8>.allocate(capacity: 12 * 1024 * 1024) // 16MB
        var bytesRead = 0
        let startTime = CFAbsoluteTimeGetCurrent()
        var lastEndTime = startTime
        while bytesRead < expectedBytesToReceive {
            do {
                // Print a memory address header
                if enableDebugPrint {
                    if (bytesRead % 8) == 0 {
                        print("")
                        print(String(format:"[%08X]: ", (bytesRead + 0x80)), terminator: " ")
                    }
                }
                
                // Read data
                let b: UInt8 = try serialPort.readByte()
                byte[bytesRead] = b
                bytesRead += 1
                
                // Print out the data
                if enableDebugPrint {
                    if bytesRead % 2 == 0 && bytesRead > 0 {
                        let t: UInt16 = UInt16(UInt16(byte[bytesRead-2]) << 8 | UInt16(byte[bytesRead-1]))
                        print(String(format: "%04X", t), terminator: " ")
                    }
                }
                
                if (bytesRead % one_megabyte == 0 && bytesRead != 0) {
                    let endTime = CFAbsoluteTimeGetCurrent()
                    print("Read ", String(bytesRead) + " bytes in \(endTime - lastEndTime) seconds.")
                    lastEndTime = endTime
                }
            } catch PortError.deviceNotConnected {
//                bytesRead = 0
            } catch {
                print("Error reading byte: ")
                print(error)
            }
        }
        let endTime = CFAbsoluteTimeGetCurrent()
        print("")
        print("Read " + String(expectedBytesToReceive) + " bytes in \(endTime - startTime) seconds.")
        
        let data = Data(bytes: byte, count: expectedBytesToReceive)
        try data.write(to: fileUrl!)
        
    } catch {
        print("Error reading data: ")
        print(error)
    }
}

