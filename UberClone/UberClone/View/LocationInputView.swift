//
//  LocationInputView.swift
//  UberClone
//
//  Created by Ronan Mak on 23/4/2022.
//

import UIKit

protocol LocationInputViewDelegate: AnyObject {
    func dismissLocationInputView()
}

class LocationInputView: UIView {

    // MARK: - Properties
    
    var user: User? {
        didSet { titleLabel.text = user?.fullname }
    }
    
    weak var delegate: LocationInputViewDelegate?
    
    lazy var backButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(named: "baseline_arrow_back_black_36dp"), for: .normal)
        button.addTarget(self, action: #selector(handleBackTapped), for: .touchUpInside)
        return button
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = .darkGray
        label.font = UIFont.systemFont(ofSize: 16)
        return label
    }()
    
    private let startLocationIndicatorView: UIView = {
        let view = UIView()
        view.backgroundColor = .lightGray
        return view
    }()
    
    private let linkingView: UIView = {
        let view = UIView()
        view.backgroundColor = .darkGray
        return view
    }()
    
    private let destinationIndicatorView: UIView = {
        let view = UIView()
        view.backgroundColor = .black
        return view
    }()
    
    lazy var startingLocationTextField: UITextField = {
        let tf = UITextField()
        tf.placeholder = "Current Location"
        tf.backgroundColor = .groupTableViewBackground
        tf.isEnabled = false
        tf.font = UIFont.systemFont(ofSize: 14)
        
        let paddingView = UIView()
        paddingView.setDimensions(height: 30, width: 8)
        tf.leftView = paddingView
        tf.leftViewMode = .always

        return tf
    }()
    
    lazy var destinationTextField: UITextField = {
        let tf = UITextField()
        tf.placeholder = "Enter a destination"
        tf.backgroundColor = UIColor.rgb(red: 215, green: 215, blue: 215)
        tf.returnKeyType = .search
        tf.font = UIFont.systemFont(ofSize: 14)
        
        let paddingView = UIView()
        paddingView.setDimensions(height: 30, width: 8)
        tf.leftView = paddingView
        tf.leftViewMode = .always
//
        return tf
    }()
    
    // MARK: - Lifecycle
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        configureUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Styles
    
    func configureUI() {
        backgroundColor = .white
        addShadow()
        
        addSubview(backButton)
        backButton.anchor(top: topAnchor, left: leftAnchor, paddingTop: 44,
                          paddingLeft: 12, width: 25, height: 25)
        
        addSubview(titleLabel)
        titleLabel.centerY(inView: backButton)
        titleLabel.centerX(inView: self)
        
        addSubview(startingLocationTextField)
        startingLocationTextField.anchor(top: backButton.bottomAnchor, left: leftAnchor,
                                           right: rightAnchor, paddingTop: 4, paddingLeft: 40,
                                           paddingRight: 40,height: 30)
        
        addSubview(destinationTextField)
        destinationTextField.anchor(top: startingLocationTextField.bottomAnchor, left: leftAnchor,
                                    right: rightAnchor, paddingTop: 12, paddingLeft: 40,
                                    paddingRight: 40,height: 30)
        
        addSubview(startLocationIndicatorView)
        startLocationIndicatorView.centerY(inView: startingLocationTextField, leftAnchor: leftAnchor, paddingLeft: 20)
        startLocationIndicatorView.setDimensions(height: 6, width: 6)
        startLocationIndicatorView.layer.cornerRadius = 6 / 2
        
        addSubview(destinationIndicatorView)
        destinationIndicatorView.centerY(inView: destinationTextField, leftAnchor: leftAnchor, paddingLeft: 20)
        destinationIndicatorView.setDimensions(height: 6, width: 6)
        
        addSubview(linkingView)
        linkingView.centerX(inView: startLocationIndicatorView)
        linkingView.anchor(top: startLocationIndicatorView.bottomAnchor,
                           bottom: destinationIndicatorView.topAnchor, paddingTop: 4,
                           paddingBottom: 4, paddingLeft: 0, width: 0.5)
    }
    
    // MARK: - Selector
    
    @objc func handleBackTapped() {
        delegate?.dismissLocationInputView()
    }
}