//
//  DeviceManager.swift
//  LifehackApp
//
//  Created for handling iOS device selection and compatibility
//

import UIKit
import Foundation

struct DeviceInfo {
    let name: String
    let model: String
    let storageCapacity: String
    let identifier: String
    let isSupported: Bool
}

class DeviceManager {
    static let shared = DeviceManager()
    
    private init() {}
    
    // Comprehensive list of iPhone models including the ones mentioned in the problem statement
    private let supportedDevices: [DeviceInfo] = [
        // iPhone 13 Series
        DeviceInfo(name: "iPhone 13 mini", model: "iPhone13,1", storageCapacity: "128GB", identifier: "iPhone13,1", isSupported: true),
        DeviceInfo(name: "iPhone 13 mini", model: "iPhone13,1", storageCapacity: "256GB", identifier: "iPhone13,1", isSupported: true),
        DeviceInfo(name: "iPhone 13 mini", model: "iPhone13,1", storageCapacity: "512GB", identifier: "iPhone13,1", isSupported: true),
        
        DeviceInfo(name: "iPhone 13", model: "iPhone13,2", storageCapacity: "128GB", identifier: "iPhone13,2", isSupported: true),
        DeviceInfo(name: "iPhone 13", model: "iPhone13,2", storageCapacity: "256GB", identifier: "iPhone13,2", isSupported: true),
        DeviceInfo(name: "iPhone 13", model: "iPhone13,2", storageCapacity: "512GB", identifier: "iPhone13,2", isSupported: true),
        
        DeviceInfo(name: "iPhone 13 Pro", model: "iPhone13,3", storageCapacity: "128GB", identifier: "iPhone13,3", isSupported: true),
        DeviceInfo(name: "iPhone 13 Pro", model: "iPhone13,3", storageCapacity: "256GB", identifier: "iPhone13,3", isSupported: true),
        DeviceInfo(name: "iPhone 13 Pro", model: "iPhone13,3", storageCapacity: "512GB", identifier: "iPhone13,3", isSupported: true),
        DeviceInfo(name: "iPhone 13 Pro", model: "iPhone13,3", storageCapacity: "1TB", identifier: "iPhone13,3", isSupported: true),
        
        // iPhone 13 Pro Max - Specifically addressing the user's current device
        DeviceInfo(name: "iPhone 13 Pro Max", model: "iPhone13,4", storageCapacity: "128GB", identifier: "iPhone13,4", isSupported: true),
        DeviceInfo(name: "iPhone 13 Pro Max", model: "iPhone13,4", storageCapacity: "256GB", identifier: "iPhone13,4", isSupported: true),
        DeviceInfo(name: "iPhone 13 Pro Max", model: "iPhone13,4", storageCapacity: "512GB", identifier: "iPhone13,4", isSupported: true),
        DeviceInfo(name: "iPhone 13 Pro Max", model: "iPhone13,4", storageCapacity: "1TB", identifier: "iPhone13,4", isSupported: true),
        
        // iPhone 14 Series
        DeviceInfo(name: "iPhone 14", model: "iPhone14,7", storageCapacity: "128GB", identifier: "iPhone14,7", isSupported: true),
        DeviceInfo(name: "iPhone 14", model: "iPhone14,7", storageCapacity: "256GB", identifier: "iPhone14,7", isSupported: true),
        DeviceInfo(name: "iPhone 14", model: "iPhone14,7", storageCapacity: "512GB", identifier: "iPhone14,7", isSupported: true),
        
        DeviceInfo(name: "iPhone 14 Plus", model: "iPhone14,8", storageCapacity: "128GB", identifier: "iPhone14,8", isSupported: true),
        DeviceInfo(name: "iPhone 14 Plus", model: "iPhone14,8", storageCapacity: "256GB", identifier: "iPhone14,8", isSupported: true),
        DeviceInfo(name: "iPhone 14 Plus", model: "iPhone14,8", storageCapacity: "512GB", identifier: "iPhone14,8", isSupported: true),
        
        DeviceInfo(name: "iPhone 14 Pro", model: "iPhone15,2", storageCapacity: "128GB", identifier: "iPhone15,2", isSupported: true),
        DeviceInfo(name: "iPhone 14 Pro", model: "iPhone15,2", storageCapacity: "256GB", identifier: "iPhone15,2", isSupported: true),
        DeviceInfo(name: "iPhone 14 Pro", model: "iPhone15,2", storageCapacity: "512GB", identifier: "iPhone15,2", isSupported: true),
        DeviceInfo(name: "iPhone 14 Pro", model: "iPhone15,2", storageCapacity: "1TB", identifier: "iPhone15,2", isSupported: true),
        
        DeviceInfo(name: "iPhone 14 Pro Max", model: "iPhone15,3", storageCapacity: "128GB", identifier: "iPhone15,3", isSupported: true),
        DeviceInfo(name: "iPhone 14 Pro Max", model: "iPhone15,3", storageCapacity: "256GB", identifier: "iPhone15,3", isSupported: true),
        DeviceInfo(name: "iPhone 14 Pro Max", model: "iPhone15,3", storageCapacity: "512GB", identifier: "iPhone15,3", isSupported: true),
        DeviceInfo(name: "iPhone 14 Pro Max", model: "iPhone15,3", storageCapacity: "1TB", identifier: "iPhone15,3", isSupported: true),
        
        // iPhone 15 Series
        DeviceInfo(name: "iPhone 15", model: "iPhone15,4", storageCapacity: "128GB", identifier: "iPhone15,4", isSupported: true),
        DeviceInfo(name: "iPhone 15", model: "iPhone15,4", storageCapacity: "256GB", identifier: "iPhone15,4", isSupported: true),
        DeviceInfo(name: "iPhone 15", model: "iPhone15,4", storageCapacity: "512GB", identifier: "iPhone15,4", isSupported: true),
        
        DeviceInfo(name: "iPhone 15 Plus", model: "iPhone15,5", storageCapacity: "128GB", identifier: "iPhone15,5", isSupported: true),
        DeviceInfo(name: "iPhone 15 Plus", model: "iPhone15,5", storageCapacity: "256GB", identifier: "iPhone15,5", isSupported: true),
        DeviceInfo(name: "iPhone 15 Plus", model: "iPhone15,5", storageCapacity: "512GB", identifier: "iPhone15,5", isSupported: true),
        
        DeviceInfo(name: "iPhone 15 Pro", model: "iPhone16,1", storageCapacity: "128GB", identifier: "iPhone16,1", isSupported: true),
        DeviceInfo(name: "iPhone 15 Pro", model: "iPhone16,1", storageCapacity: "256GB", identifier: "iPhone16,1", isSupported: true),
        DeviceInfo(name: "iPhone 15 Pro", model: "iPhone16,1", storageCapacity: "512GB", identifier: "iPhone16,1", isSupported: true),
        DeviceInfo(name: "iPhone 15 Pro", model: "iPhone16,1", storageCapacity: "1TB", identifier: "iPhone16,1", isSupported: true),
        
        DeviceInfo(name: "iPhone 15 Pro Max", model: "iPhone16,2", storageCapacity: "256GB", identifier: "iPhone16,2", isSupported: true),
        DeviceInfo(name: "iPhone 15 Pro Max", model: "iPhone16,2", storageCapacity: "512GB", identifier: "iPhone16,2", isSupported: true),
        DeviceInfo(name: "iPhone 15 Pro Max", model: "iPhone16,2", storageCapacity: "1TB", identifier: "iPhone16,2", isSupported: true),
        
        // iPhone 16 Series
        DeviceInfo(name: "iPhone 16", model: "iPhone17,3", storageCapacity: "128GB", identifier: "iPhone17,3", isSupported: true),
        DeviceInfo(name: "iPhone 16", model: "iPhone17,3", storageCapacity: "256GB", identifier: "iPhone17,3", isSupported: true),
        DeviceInfo(name: "iPhone 16", model: "iPhone17,3", storageCapacity: "512GB", identifier: "iPhone17,3", isSupported: true),
        
        DeviceInfo(name: "iPhone 16 Plus", model: "iPhone17,4", storageCapacity: "128GB", identifier: "iPhone17,4", isSupported: true),
        DeviceInfo(name: "iPhone 16 Plus", model: "iPhone17,4", storageCapacity: "256GB", identifier: "iPhone17,4", isSupported: true),
        DeviceInfo(name: "iPhone 16 Plus", model: "iPhone17,4", storageCapacity: "512GB", identifier: "iPhone17,4", isSupported: true),
        
        DeviceInfo(name: "iPhone 16 Pro", model: "iPhone17,1", storageCapacity: "128GB", identifier: "iPhone17,1", isSupported: true),
        DeviceInfo(name: "iPhone 16 Pro", model: "iPhone17,1", storageCapacity: "256GB", identifier: "iPhone17,1", isSupported: true),
        DeviceInfo(name: "iPhone 16 Pro", model: "iPhone17,1", storageCapacity: "512GB", identifier: "iPhone17,1", isSupported: true),
        DeviceInfo(name: "iPhone 16 Pro", model: "iPhone17,1", storageCapacity: "1TB", identifier: "iPhone17,1", isSupported: true),
        
        DeviceInfo(name: "iPhone 16 Pro Max", model: "iPhone17,2", storageCapacity: "256GB", identifier: "iPhone17,2", isSupported: true),
        DeviceInfo(name: "iPhone 16 Pro Max", model: "iPhone17,2", storageCapacity: "512GB", identifier: "iPhone17,2", isSupported: true),
        DeviceInfo(name: "iPhone 16 Pro Max", model: "iPhone17,2", storageCapacity: "1TB", identifier: "iPhone17,2", isSupported: true),
        
        // iPhone 17 Series (Future devices as mentioned in problem statement)
        DeviceInfo(name: "iPhone 17", model: "iPhone18,3", storageCapacity: "256GB", identifier: "iPhone18,3", isSupported: true),
        DeviceInfo(name: "iPhone 17", model: "iPhone18,3", storageCapacity: "512GB", identifier: "iPhone18,3", isSupported: true),
        DeviceInfo(name: "iPhone 17", model: "iPhone18,3", storageCapacity: "1TB", identifier: "iPhone18,3", isSupported: true),
        
        DeviceInfo(name: "iPhone 17 Plus", model: "iPhone18,4", storageCapacity: "256GB", identifier: "iPhone18,4", isSupported: true),
        DeviceInfo(name: "iPhone 17 Plus", model: "iPhone18,4", storageCapacity: "512GB", identifier: "iPhone18,4", isSupported: true),
        DeviceInfo(name: "iPhone 17 Plus", model: "iPhone18,4", storageCapacity: "1TB", identifier: "iPhone18,4", isSupported: true),
        
        DeviceInfo(name: "iPhone 17 Pro", model: "iPhone18,1", storageCapacity: "256GB", identifier: "iPhone18,1", isSupported: true),
        DeviceInfo(name: "iPhone 17 Pro", model: "iPhone18,1", storageCapacity: "512GB", identifier: "iPhone18,1", isSupported: true),
        DeviceInfo(name: "iPhone 17 Pro", model: "iPhone18,1", storageCapacity: "1TB", identifier: "iPhone18,1", isSupported: true),
        DeviceInfo(name: "iPhone 17 Pro", model: "iPhone18,1", storageCapacity: "2TB", identifier: "iPhone18,1", isSupported: true),
        
        // iPhone 17 Pro Max - Specifically addressing the user's desired device
        DeviceInfo(name: "iPhone 17 Pro Max", model: "iPhone18,2", storageCapacity: "256GB", identifier: "iPhone18,2", isSupported: true),
        DeviceInfo(name: "iPhone 17 Pro Max", model: "iPhone18,2", storageCapacity: "512GB", identifier: "iPhone18,2", isSupported: true),
        DeviceInfo(name: "iPhone 17 Pro Max", model: "iPhone18,2", storageCapacity: "1TB", identifier: "iPhone18,2", isSupported: true),
        DeviceInfo(name: "iPhone 17 Pro Max", model: "iPhone18,2", storageCapacity: "2TB", identifier: "iPhone18,2", isSupported: true),
    ]
    
    // Get current device information
    func getCurrentDevice() -> DeviceInfo? {
        let identifier = getDeviceIdentifier()
        return supportedDevices.first { $0.identifier == identifier }
    }
    
    // Get all supported devices for dropdown selection
    func getAllSupportedDevices() -> [DeviceInfo] {
        return supportedDevices.filter { $0.isSupported }
    }
    
    // Get devices by specific model name (e.g., "iPhone 13 Pro Max")
    func getDeviceVariants(for modelName: String) -> [DeviceInfo] {
        return supportedDevices.filter { $0.name == modelName && $0.isSupported }
    }
    
    // Check if a specific device configuration is supported
    func isDeviceSupported(name: String, storageCapacity: String) -> Bool {
        return supportedDevices.contains { device in
            device.name == name && 
            device.storageCapacity == storageCapacity && 
            device.isSupported
        }
    }
    
    // Get formatted device display name including storage
    func getDeviceDisplayName(for device: DeviceInfo) -> String {
        return "\(device.name) (\(device.storageCapacity))"
    }
    
    // Get grouped devices for better dropdown organization
    func getGroupedDevices() -> [String: [DeviceInfo]] {
        let grouped = Dictionary(grouping: supportedDevices.filter { $0.isSupported }) { device in
            device.name
        }
        return grouped
    }
    
    // Validate device compatibility with current iOS version
    func validateDeviceCompatibility(for device: DeviceInfo) -> Bool {
        // Add specific compatibility checks here
        // For now, all devices in the list are considered compatible
        return device.isSupported
    }
    
    private func getDeviceIdentifier() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value))!)
        }
        return identifier
    }
    
    // Helper method to find user's specific devices mentioned in problem statement
    func findUserDevices() -> (current: DeviceInfo?, desired: DeviceInfo?) {
        let current = supportedDevices.first { device in
            device.name == "iPhone 13 Pro Max" && device.storageCapacity == "1TB"
        }
        
        let desired = supportedDevices.first { device in
            device.name == "iPhone 17 Pro Max" && device.storageCapacity == "2TB"
        }
        
        return (current: current, desired: desired)
    }
}
