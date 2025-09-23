//
//  ViewController.swift
//  LifehackApp
//
//  Main view controller for device selection and app functionality
//

import UIKit

class ViewController: UIViewController {
    
    @IBOutlet weak var deviceSelectionButton: UIButton!
    @IBOutlet weak var currentDeviceLabel: UILabel!
    @IBOutlet weak var statusLabel: UILabel!
    @IBOutlet weak var compatibilityLabel: UILabel!
    
    private let deviceManager = DeviceManager.shared
    private var selectedDevice: DeviceInfo?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        updateCurrentDeviceInfo()
        checkUserSpecificDevices()
    }
    
    private func setupUI() {
        title = "LifehackApp Device Manager"
        
        // Configure device selection button
        deviceSelectionButton?.configuration = UIButton.Configuration.filled()
        deviceSelectionButton?.configuration?.title = "Select Device"
        deviceSelectionButton?.configuration?.cornerStyle = .medium
        
        // Setup labels
        currentDeviceLabel?.numberOfLines = 0
        statusLabel?.numberOfLines = 0
        compatibilityLabel?.numberOfLines = 0
        
        // Add button action
        deviceSelectionButton?.addTarget(self, action: #selector(deviceSelectionTapped), for: .touchUpInside)
    }
    
    private func updateCurrentDeviceInfo() {
        let currentDevice = deviceManager.getCurrentDevice()
        
        if let device = currentDevice {
            currentDeviceLabel?.text = "Current Device: \(deviceManager.getDeviceDisplayName(for: device))"
            
            let isCompatible = deviceManager.validateDeviceCompatibility(for: device)
            compatibilityLabel?.text = "Compatibility: \(isCompatible ? "✅ Supported" : "❌ Not Supported")"
        } else {
            currentDeviceLabel?.text = "Current Device: Unknown"
            compatibilityLabel?.text = "Compatibility: Unknown"
        }
    }
    
    private func checkUserSpecificDevices() {
        let userDevices = deviceManager.findUserDevices()
        
        var statusText = "Device Status:\n"
        
        if let currentDevice = userDevices.current {
            statusText += "• Your iPhone 13 Pro Max (1TB): ✅ Available in dropdown\n"
            statusText += "  Model: \(currentDevice.model)\n"
        } else {
            statusText += "• iPhone 13 Pro Max (1TB): ❌ Not found\n"
        }
        
        if let desiredDevice = userDevices.desired {
            statusText += "• iPhone 17 Pro Max (2TB): ✅ Available for future use\n"
            statusText += "  Model: \(desiredDevice.model)\n"
        } else {
            statusText += "• iPhone 17 Pro Max (2TB): ❌ Not found\n"
        }
        
        statusLabel?.text = statusText
    }
    
    @objc private func deviceSelectionTapped() {
        showDeviceSelectionMenu()
    }
    
    private func showDeviceSelectionMenu() {
        let alertController = UIAlertController(
            title: "Select Device", 
            message: "Choose your iPhone model and storage capacity", 
            preferredStyle: .actionSheet
        )
        
        // Group devices by model for better organization
        let groupedDevices = deviceManager.getGroupedDevices()
        let sortedKeys = groupedDevices.keys.sorted()
        
        // Add actions for each device model
        for modelName in sortedKeys {
            if let devices = groupedDevices[modelName] {
                // Sort devices by storage capacity
                let sortedDevices = devices.sorted { device1, device2 in
                    let storage1 = extractStorageValue(from: device1.storageCapacity)
                    let storage2 = extractStorageValue(from: device2.storageCapacity)
                    return storage1 < storage2
                }
                
                // Create submenu for each device model with different storage options
                if sortedDevices.count > 1 {
                    let deviceAction = UIAlertAction(title: modelName, style: .default) { [weak self] _ in
                        self?.showStorageOptions(for: modelName, devices: sortedDevices)
                    }
                    alertController.addAction(deviceAction)
                } else if let device = sortedDevices.first {
                    let displayName = deviceManager.getDeviceDisplayName(for: device)
                    let deviceAction = UIAlertAction(title: displayName, style: .default) { [weak self] _ in
                        self?.selectDevice(device)
                    }
                    alertController.addAction(deviceAction)
                }
            }
        }
        
        // Add cancel action
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
        alertController.addAction(cancelAction)
        
        // Configure for iPad
        if let popover = alertController.popoverPresentationController {
            popover.sourceView = deviceSelectionButton
            popover.sourceRect = deviceSelectionButton.bounds
        }
        
        present(alertController, animated: true)
    }
    
    private func showStorageOptions(for modelName: String, devices: [DeviceInfo]) {
        let alertController = UIAlertController(
            title: modelName, 
            message: "Select storage capacity", 
            preferredStyle: .actionSheet
        )
        
        for device in devices {
            let displayName = "\(device.storageCapacity)"
            let storageAction = UIAlertAction(title: displayName, style: .default) { [weak self] _ in
                self?.selectDevice(device)
            }
            alertController.addAction(storageAction)
        }
        
        let backAction = UIAlertAction(title: "Back", style: .cancel) { [weak self] _ in
            self?.showDeviceSelectionMenu()
        }
        alertController.addAction(backAction)
        
        // Configure for iPad
        if let popover = alertController.popoverPresentationController {
            popover.sourceView = deviceSelectionButton
            popover.sourceRect = deviceSelectionButton.bounds
        }
        
        present(alertController, animated: true)
    }
    
    private func selectDevice(_ device: DeviceInfo) {
        selectedDevice = device
        let displayName = deviceManager.getDeviceDisplayName(for: device)
        
        // Update button title
        deviceSelectionButton?.configuration?.title = displayName
        
        // Show selection confirmation
        let alertController = UIAlertController(
            title: "Device Selected", 
            message: "You have selected: \(displayName)\n\nThis device is \(device.isSupported ? "supported" : "not supported") for the LifehackApp.", 
            preferredStyle: .alert
        )
        
        let okAction = UIAlertAction(title: "OK", style: .default)
        alertController.addAction(okAction)
        
        present(alertController, animated: true)
    }
    
    private func extractStorageValue(from storageString: String) -> Int {
        let numbers = storageString.compactMap { $0.wholeNumberValue }
        let numberString = numbers.map { String($0) }.joined()
        
        if let value = Int(numberString) {
            // Convert TB to GB for proper comparison
            if storageString.contains("TB") {
                return value * 1000
            }
            return value
        }
        return 0
    }
}

// MARK: - Device Testing Methods
extension ViewController {
    
    // Method to test device compatibility - useful for debugging
    private func testDeviceCompatibility() {
        let testDevices = [
            ("iPhone 13 Pro Max", "1TB"),
            ("iPhone 17 Pro Max", "2TB")
        ]
        
        for (name, storage) in testDevices {
            let isSupported = deviceManager.isDeviceSupported(name: name, storageCapacity: storage)
            print("Testing \(name) (\(storage)): \(isSupported ? "Supported" : "Not Supported")")
        }
    }
    
    // Method to print all available devices - useful for debugging
    private func printAllAvailableDevices() {
        let devices = deviceManager.getAllSupportedDevices()
        print("All supported devices:")
        for device in devices {
            print("- \(deviceManager.getDeviceDisplayName(for: device))")
        }
    }
}