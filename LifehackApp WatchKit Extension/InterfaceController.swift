//
//  InterfaceController.swift
//  LifehackApp WatchKit Extension
//
//  Created on 2024.
//

import WatchKit
import Foundation

class InterfaceController: WKInterfaceController {

    @IBOutlet weak var titleLabel: WKInterfaceLabel!
    @IBOutlet weak var dailyTipButton: WKInterfaceButton!
    @IBOutlet weak var tipLabel: WKInterfaceLabel!
    
    override func awake(withContext context: Any?) {
        super.awake(withContext: context)
        
        // Configure interface objects here.
        setupInterface()
    }
    
    override func willActivate() {
        // This method is called when watch view controller is about to be visible to user
        super.willActivate()
    }
    
    override func didDeactivate() {
        // This method is called when watch view controller is no longer visible
        super.didDeactivate()
    }
    
    private func setupInterface() {
        titleLabel.setText("LifehackApp")
        dailyTipButton.setTitle("Daily Tip")
        tipLabel.setText("Tap for productivity tips!")
    }
    
    @IBAction func dailyTipButtonTapped() {
        let tips = [
            "💧 Drink water!",
            "🧘 Take deep breaths",
            "📱 Phone in airplane mode for focus",
            "⏰ Use 25min work blocks",
            "🚶 Walk breaks boost creativity",
            "📝 Write tomorrow's tasks today",
            "🌅 Morning sunlight = better sleep"
        ]
        
        let randomTip = tips.randomElement() ?? "Stay productive!"
        
        // Update the tip label with animation
        animate(withDuration: 0.3) {
            self.tipLabel.setText(randomTip)
        }
        
        // Provide haptic feedback
        WKInterfaceDevice.current().play(.click)
    }
}