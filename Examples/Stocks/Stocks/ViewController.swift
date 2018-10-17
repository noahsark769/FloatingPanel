//
//  ViewController.swift
//  Stocks
//
//  Created by Shin Yamamoto on 2018/10/12.
//  Copyright © 2018 scenee. All rights reserved.
//

import UIKit
import FloatingPanel

class ViewController: UIViewController, FloatingPanelControllerDelegate {
    @IBOutlet var topBannerView: UIImageView!
    @IBOutlet weak var labelStackView: UIStackView!
    @IBOutlet weak var bottomToolView: UIView!

    var fpc: FloatingPanelController!
    var newsVC: NewsViewController!

    var initialColor: UIColor = .black
    override func viewDidLoad() {
        super.viewDidLoad()
        initialColor = view.backgroundColor!
        // Initialize FloatingPanelController
        fpc = FloatingPanelController()
        fpc.delegate = self

        // Initialize FloatingPanelController and add the view
        fpc.surfaceView.backgroundColor = UIColor(displayP3Red: 30.0/255.0, green: 30.0/255.0, blue: 30.0/255.0, alpha: 1.0)
        fpc.surfaceView.cornerRadius = 24.0
        fpc.surfaceView.shadowHidden = true
        fpc.surfaceView.borderWidth = 1.0 / traitCollection.displayScale
        fpc.surfaceView.borderColor = UIColor.black.withAlphaComponent(0.2)

        newsVC = storyboard?.instantiateViewController(withIdentifier: "News") as? NewsViewController

        // Add a content view controller
        fpc.show(newsVC, sender: self)
        fpc.track(scrollView: newsVC.scrollView)

        fpc.add(toParent: self, belowView: bottomToolView, animated: false)

        topBannerView.frame = .zero
        topBannerView.alpha = 0.0
        view.addSubview(topBannerView)
        topBannerView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            topBannerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 0.0),
            topBannerView.leftAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leftAnchor, constant: 0.0),
            ])
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }

    // MARK: FloatingPanelControllerDelegate

    func floatingPanel(_ vc: FloatingPanelController, layoutFor newCollection: UITraitCollection) -> FloatingPanelLayout? {
        return FloatingPanelStocksLayout()
    }

    func floatingPanel(_ vc: FloatingPanelController, behaviorFor newCollection: UITraitCollection) -> FloatingPanelBehavior? {
        return FloatingPanelStocksBehavior()
    }

    func floatingPanelWillBeginDragging(_ vc: FloatingPanelController) {
        if vc.position == .full {
            // Dimiss top bar with dissolve animation
            UIView.animate(withDuration: 0.25) {
                self.topBannerView.alpha = 0.0
                self.labelStackView.alpha = 1.0
                self.view.backgroundColor = self.initialColor
            }
        }
    }
    func floatingPanelDidEndDragging(_ vc: FloatingPanelController, withVelocity velocity: CGPoint, targetPosition: FloatingPanelPosition) {
        if targetPosition == .full {
            // Present top bar with dissolve animation
            UIView.animate(withDuration: 0.25) {
                self.topBannerView.alpha = 1.0
                self.labelStackView.alpha = 0.0
                self.view.backgroundColor = .black
            }
        }
    }
}

class NewsViewController: UIViewController {
    @IBOutlet weak var scrollView: UIScrollView!
}


// MARK: My custom layout

class FloatingPanelStocksLayout: FloatingPanelLayout {
    public var supportedPositions: [FloatingPanelPosition] {
        return [.full, .half, .tip]
    }

    public var initialPosition: FloatingPanelPosition {
        return .tip
    }

    public func insetFor(position: FloatingPanelPosition) -> CGFloat? {
        switch position {
        case .full: return 56.0
        case .half: return 262.0
        case .tip: return 85.0 + 44.0 // Visible + ToolView
        }
    }

    public func prepareLayout(surfaceView: UIView, in view: UIView) -> [NSLayoutConstraint] {
        return [
            surfaceView.leftAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leftAnchor, constant: 0.0),
            surfaceView.rightAnchor.constraint(equalTo: view.safeAreaLayoutGuide.rightAnchor, constant: 0.0),
        ]
    }

    var backdropAlpha: CGFloat = 0.0
}

// MARK: My custom behavior

class FloatingPanelStocksBehavior: FloatingPanelBehavior {
    var velocityThreshold: CGFloat {
        return 15.0
    }

    func interactionAnimator(to targetPosition: FloatingPanelPosition, with velocity: CGVector) -> UIViewPropertyAnimator {
        let damping = self.damping(with: velocity)
        let springTiming = UISpringTimingParameters(dampingRatio: damping,
                                                    initialVelocity: velocity)
        let duration = getDuration(with: velocity)
        return UIViewPropertyAnimator(duration: duration, timingParameters: springTiming)
    }

    private func getDuration(with velocity: CGVector) -> TimeInterval {
        let dy = abs(velocity.dy)
        switch dy {
        case ..<1.0:
            return 0.5
        case 1.0..<velocityThreshold:
            let a = ((dy - 1.0) / (velocityThreshold - 1.0))
            return TimeInterval(0.5 - (0.25 * a))
        case velocityThreshold...:
            return 0.25
        default:
            fatalError()
        }
    }

    private func damping(with velocity: CGVector) -> CGFloat {
        switch velocity.dy {
        case ...(-velocityThreshold):
            return 0.7
        case velocityThreshold...:
            return 0.7
        default:
            return 1.0
        }
    }
}