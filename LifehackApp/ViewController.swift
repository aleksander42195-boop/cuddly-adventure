import UIKit

/// Simple UIKit view that lists user devices (optional demo alongside SwiftUI).
final class ViewController: UITableViewController {
    private let appState = AppState()
    private var devices: [Device] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Devices"
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
        refreshControl = UIRefreshControl()
        refreshControl?.addTarget(self, action: #selector(reloadDevices), for: .valueChanged)
        reloadDevices()
    }

    @objc private func reloadDevices() {
        devices = appState.findUserDevices()
        tableView.reloadData()
        refreshControl?.endRefreshing()
    }

    // MARK: - Table

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        devices.count
    }

    override func tableView(_ tableView: UITableView,
                            cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let device = devices[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        var config = cell.defaultContentConfiguration()
        config.text = device.model
        config.secondaryText = "\(device.capacity) · \(device.available ? "Available" : "Unavailable")"
        cell.contentConfiguration = config
        cell.accessoryType = device.available ? .checkmark : .none
        return cell
    }
}
