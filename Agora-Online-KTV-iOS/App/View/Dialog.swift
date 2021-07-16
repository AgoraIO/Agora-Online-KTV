//
//  Dialog.swift
//  app
//
//  Created by XC on 2021/6/28.
//

import Core
import Foundation
import UIKit

class ProcessingView: UIView {
    var message: String? {
        didSet {
            var animation = false
            if let message = message, !message.isEmpty {
                label.text = message
                if label.superview == nil {
                    if icon.superview != nil {
                        icon.removeAllConstraints()
                    } else {
                        addSubview(icon)
                        animation = true
                    }
                    addSubview(label)
                    icon.marginTop(anchor: topAnchor, constant: 16)
                        .marginBottom(anchor: bottomAnchor, constant: 16)
                        .marginLeading(anchor: leadingAnchor, constant: 16)
                        .active()
                    label.marginLeading(anchor: icon.trailingAnchor, constant: 6)
                        .marginTrailing(anchor: trailingAnchor, constant: 28)
                        .centerY(anchor: icon.centerYAnchor)
                        .active()
                }
            } else {
                if label.superview != nil {
                    label.removeFromSuperview()
                    if icon.superview != nil {
                        icon.removeAllConstraints()
                        icon.marginTop(anchor: topAnchor, constant: 16)
                            .marginBottom(anchor: bottomAnchor, constant: 16)
                            .marginLeading(anchor: leadingAnchor, constant: 16)
                            .marginTrailing(anchor: trailingAnchor, constant: 16)
                            .active()
                    }
                }
                if icon.superview == nil {
                    addSubview(icon)
                    animation = true
                    icon.marginTop(anchor: topAnchor, constant: 16)
                        .marginBottom(anchor: bottomAnchor, constant: 16)
                        .marginLeading(anchor: leadingAnchor, constant: 16)
                        .marginTrailing(anchor: trailingAnchor, constant: 16)
                        .active()
                }
            }
            if animation {
                let animation = CABasicAnimation(keyPath: "transform.rotation.z")
                animation.toValue = Double.pi * 2
                animation.duration = 1
                animation.isCumulative = true
                animation.repeatCount = .infinity
                icon.layer.add(animation, forKey: "transform.rotation.z")
            }
        }
    }

    private var icon: UIImageView = {
        let view = UIImageView(frame: CGRect(x: 0, y: 0, width: 16, height: 16))
        view.image = UIImage(named: "iconLoading", in: Utils.bundle, with: nil)
        view.width(constant: 16)
            .height(constant: 16)
            .active()

        return view
    }()

    private var label: UILabel = {
        let view = UILabel()
        view.textColor = .white
        view.font = UIFont.systemFont(ofSize: 14)
        return view
    }()

    init() {
        super.init(frame: .zero)
        backgroundColor = .black
        rounded(radius: 8)
        shadow(color: "#80000000", radius: 4, offset: CGSize(width: 0, height: 2), opacity: 1)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        Logger.log(self, message: "deinit", level: .info)
    }
}

extension Dialog {
    func show(processing: Bool, message: String? = nil) {
        DispatchQueue.main.async { [weak self] in
            if let self = self {
                var oldView = self.viewWithTag(235)
                if processing {
                    if oldView == nil {
                        oldView = UIView(frame: self.frame)
                    }
                    guard let backgroundView = oldView else {
                        return
                    }
                    backgroundView.tag = 235
                    let view = ProcessingView()
                    view.message = message
                    // view.center = backgroundView.center

                    backgroundView.addSubview(view)
                    view.centerY(anchor: backgroundView.centerYAnchor)
                        .centerX(anchor: backgroundView.centerXAnchor)
                        .active()
                    backgroundView.alpha = 0
                    self.addSubview(backgroundView)
                    backgroundView.fill(view: self).active()

                    UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseInOut, animations: {
                        backgroundView.alpha = 1
                    })
                } else if let backgroundView = oldView {
                    UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseInOut, animations: {
                        backgroundView.alpha = 0
                    }, completion: { _ in
                        backgroundView.removeFromSuperview()
                    })
                }
            }
        }
    }
}

extension BaseViewContoller {
    func show(loading: Bool, message: String? = nil) {
        DispatchQueue.main.async { [weak self] in
            if let self = self {
                let tag = 235
                var oldView = self.view.viewWithTag(tag)
                if loading {
                    if oldView == nil {
                        oldView = UIView(frame: self.view.frame)
                    }
                    guard let backgroundView = oldView else {
                        return
                    }
                    backgroundView.tag = tag
                    let view = ProcessingView()
                    view.message = message
                    // view.center = backgroundView.center

                    backgroundView.addSubview(view)
                    view.centerY(anchor: backgroundView.centerYAnchor, constant: -80)
                        .centerX(anchor: backgroundView.centerXAnchor)
                        .active()
                    backgroundView.alpha = 0
                    self.view.addSubview(backgroundView)
                    backgroundView.fill(view: self.view).active()

                    UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseInOut, animations: {
                        backgroundView.alpha = 1
                    })
                } else if let backgroundView = oldView {
                    UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseInOut, animations: {
                        backgroundView.alpha = 0
                    }, completion: { _ in
                        backgroundView.removeFromSuperview()
                    })
                }
            }
        }
    }
}
