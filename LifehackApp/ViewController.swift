//
//  ViewController.swift
//  LifehackApp
//
//  Created on 2024.
//

import UIKit

class ViewController: UIViewController {

    @IBOutlet weak var welcomeLabel: UILabel!
    @IBOutlet weak var lifehackButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        setupUI()
    }
    
    private func setupUI() {
        welcomeLabel.text = "Welcome to LifehackApp!"
        welcomeLabel.textAlignment = .center
        welcomeLabel.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        
        lifehackButton.setTitle("Get Daily Lifehack", for: .normal)
        lifehackButton.backgroundColor = UIColor.systemBlue
        lifehackButton.setTitleColor(.white, for: .normal)
        lifehackButton.layer.cornerRadius = 10
        lifehackButton.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .medium)
    }
    
    @IBAction func lifehackButtonTapped(_ sender: UIButton) {
        let lifehacks = [
            "🧠 Use the 2-minute rule: If something takes less than 2 minutes, do it now!",
            "📱 Put your phone in another room when working to avoid distractions",
            "💧 Drink a glass of water first thing in the morning to kickstart your metabolism",
            "⏰ Use the Pomodoro Technique: 25 minutes work, 5 minutes break",
            "🧘 Take 5 deep breaths before making important decisions"
        ]
        
        let randomLifehack = lifehacks.randomElement() ?? "Stay productive!"
        
        let alert = UIAlertController(title: "Daily Lifehack", message: randomLifehack, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Thanks!", style: .default))
        present(alert, animated: true)
    }
}