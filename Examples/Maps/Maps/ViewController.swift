//
//  Copyright © 2018 Shin Yamamoto. All rights reserved.
//

import UIKit
import SwiftUI
import MapKit
import FloatingPanel

final class HostingCell<Content: View>: UITableViewCell {
    private let hostingController = UIHostingController<Content?>(rootView: nil)

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        hostingController.view.backgroundColor = .clear
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func set(rootView: Content, parentController: UIViewController) {
        self.hostingController.rootView = rootView
        self.hostingController.view.invalidateIntrinsicContentSize()

        let requiresControllerMove = hostingController.parent != parentController
        if requiresControllerMove {
            parentController.addChild(hostingController)
        }

        if !self.contentView.subviews.contains(hostingController.view) {
            self.contentView.addSubview(hostingController.view)
            hostingController.view.translatesAutoresizingMaskIntoConstraints = false
            hostingController.view.leadingAnchor.constraint(equalTo: self.contentView.leadingAnchor).isActive = true
            hostingController.view.trailingAnchor.constraint(equalTo: self.contentView.trailingAnchor).isActive = true
            hostingController.view.topAnchor.constraint(equalTo: self.contentView.topAnchor).isActive = true
            hostingController.view.bottomAnchor.constraint(equalTo: self.contentView.bottomAnchor).isActive = true
        }

        if requiresControllerMove {
            hostingController.didMove(toParent: parentController)
        }
    }
}

class ViewController: UIViewController, MKMapViewDelegate, UISearchBarDelegate, FloatingPanelControllerDelegate {
    var fpc: FloatingPanelController!
    var searchVC: SearchPanelViewController!

    @IBOutlet weak var mapView: MKMapView!

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        // Initialize FloatingPanelController
        fpc = FloatingPanelController()
        fpc.delegate = self

        // Initialize FloatingPanelController and add the view
        fpc.surfaceView.backgroundColor = .clear
        if #available(iOS 11, *) {
            fpc.surfaceView.cornerRadius = 9.0
        } else {
            fpc.surfaceView.cornerRadius = 0.0
        }
        fpc.surfaceView.shadowHidden = false

        searchVC = storyboard?.instantiateViewController(withIdentifier: "SearchPanel") as? SearchPanelViewController

        // Set a content view controller
        fpc.set(contentViewController: searchVC)
        fpc.track(scrollView: searchVC.tableView)

        setupMapView()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        //  Add FloatingPanel to a view with animation.
        fpc.addPanel(toParent: self, animated: true)

        // Must be here
        searchVC.searchBar.delegate = self
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        teardownMapView()
    }

    func setupMapView() {
        let center = CLLocationCoordinate2D(latitude: 37.623198015869235,
                                            longitude: -122.43066818432008)
        let span = MKCoordinateSpan(latitudeDelta: 0.4425100023575723,
                                    longitudeDelta: 0.28543697435880233)
        let region = MKCoordinateRegion(center: center, span: span)
        mapView.region = region
        mapView.showsCompass = true
        mapView.showsUserLocation = true
        mapView.delegate = self
    }

    func teardownMapView() {
        // Prevent a crash
        mapView.delegate = nil
        mapView = nil
    }

    // MARK: UISearchBarDelegate

    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
        searchBar.showsCancelButton  = false
        searchVC.hideHeader()
        fpc.move(to: .half, animated: true)
    }

    func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
        searchBar.showsCancelButton = true
        searchVC.showHeader()
        searchVC.tableView.alpha = 1.0
        fpc.move(to: .full, animated: true)
    }

    // MARK: FloatingPanelControllerDelegate
    
    func floatingPanel(_ vc: FloatingPanelController, layoutFor newCollection: UITraitCollection) -> FloatingPanelLayout? {
        switch newCollection.verticalSizeClass {
        case .compact:
            fpc.surfaceView.borderWidth = 1.0 / traitCollection.displayScale
            fpc.surfaceView.borderColor = UIColor.black.withAlphaComponent(0.2)
            return SearchPanelLandscapeLayout()
        default:
            fpc.surfaceView.borderWidth = 0.0
            fpc.surfaceView.borderColor = nil
            return nil
        }
    }

    func floatingPanelDidMove(_ vc: FloatingPanelController) {
        let y = vc.surfaceView.frame.origin.y
        let tipY = vc.originYOfSurface(for: .tip)
        if y > tipY - 44.0 {
            let progress = max(0.0, min((tipY  - y) / 44.0, 1.0))
            self.searchVC.tableView.alpha = progress
        }
        debugPrint("NearbyPosition : ",vc.nearbyPosition)
    }

    func floatingPanelWillBeginDragging(_ vc: FloatingPanelController) {
        if vc.position == .full {
            searchVC.searchBar.showsCancelButton = false
            searchVC.searchBar.resignFirstResponder()
        }
    }

    func floatingPanelDidEndDragging(_ vc: FloatingPanelController, withVelocity velocity: CGPoint, targetPosition: FloatingPanelPosition) {
        if targetPosition != .full {
            searchVC.hideHeader()
        }

        UIView.animate(withDuration: 0.25,
                       delay: 0.0,
                       options: .allowUserInteraction,
                       animations: {
                        if targetPosition == .tip {
                            self.searchVC.tableView.alpha = 0.0
                        } else {
                            self.searchVC.tableView.alpha = 1.0
                        }
        }, completion: nil)
    }
}

class SearchPanelViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var searchBar: UISearchBar!
    @IBOutlet weak var visualEffectView: UIVisualEffectView!

    // For iOS 10 only
    private lazy var shadowLayer: CAShapeLayer = CAShapeLayer()

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.dataSource = self
        tableView.delegate = self
        searchBar.placeholder = "Search for a place or address"
        searchBar.setSearchText(fontSize: 15.0)
        tableView.register(HostingCell<Text>.self, forCellReuseIdentifier: "HostingCell<Text>")
        hideHeader()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if #available(iOS 11, *) {
        } else {
            // Exmaple: Add rounding corners on iOS 10
            visualEffectView.layer.cornerRadius = 9.0
            visualEffectView.clipsToBounds = true

            // Exmaple: Add shadow manually on iOS 10
            view.layer.insertSublayer(shadowLayer, at: 0)
            let rect = visualEffectView.frame
            let path = UIBezierPath(roundedRect: rect,
                                    byRoundingCorners: [.topLeft, .topRight],
                                    cornerRadii: CGSize(width: 9.0, height: 9.0))
            shadowLayer.frame = visualEffectView.frame
            shadowLayer.shadowPath = path.cgPath
            shadowLayer.shadowColor = UIColor.black.cgColor
            shadowLayer.shadowOffset = CGSize(width: 0.0, height: 1.0)
            shadowLayer.shadowOpacity = 0.2
            shadowLayer.shadowRadius = 3.0
        }
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 100
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "HostingCell<Text>", for: indexPath)
        (cell as? HostingCell<Text>)?.set(rootView: Text("Hello"), parentController: self)
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)
    }

    func showHeader() {
        changeHeader(height: 116.0)
    }

    func hideHeader() {
        changeHeader(height: 0.0)
    }

    func changeHeader(height: CGFloat) {
        tableView.beginUpdates()
        if let headerView = tableView.tableHeaderView  {
            UIView.animate(withDuration: 0.25) {
                var frame = headerView.frame
                frame.size.height = height
                self.tableView.tableHeaderView?.frame = frame
            }
        }
        tableView.endUpdates()
    }
}

public class SearchPanelLandscapeLayout: FloatingPanelLayout {
    public var initialPosition: FloatingPanelPosition {
        return .tip
    }
    
    public var supportedPositions: Set<FloatingPanelPosition> {
        return [.full, .tip]
    }

    public func insetFor(position: FloatingPanelPosition) -> CGFloat? {
        switch position {
        case .full: return 16.0
        case .tip: return 69.0
        default: return nil
        }
    }

    public func prepareLayout(surfaceView: UIView, in view: UIView) -> [NSLayoutConstraint] {
        if #available(iOS 11.0, *) {
            return [
                surfaceView.leftAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leftAnchor, constant: 8.0),
                surfaceView.widthAnchor.constraint(equalToConstant: 291),
            ]
        } else {
            return [
                surfaceView.leftAnchor.constraint(equalTo: view.leftAnchor, constant: 8.0),
                surfaceView.widthAnchor.constraint(equalToConstant: 291),
            ]
        }
    }

    public func backdropAlphaFor(position: FloatingPanelPosition) -> CGFloat {
        return 0.0
    }
}

class SearchCell: UITableViewCell {
    @IBOutlet weak var iconImageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var subTitleLabel: UILabel!
}

class SearchHeaderView: UIView {
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.clipsToBounds = true
    }
}

extension UISearchBar {
    func setSearchText(fontSize: CGFloat) {
        #if swift(>=5.1) // Xcode 11 or later
            let font = searchTextField.font
            searchTextField.font = font?.withSize(fontSize)
        #else
            let textField = value(forKey: "_searchField") as! UITextField
            textField.font = textField.font?.withSize(fontSize)
        #endif
    }
}
