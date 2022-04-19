//
//  SignUpController.swift
//  UberClone
//
//  Created by Ronan Mak on 18/4/2022.
//

import UIKit
import Firebase

class SignUpController: UIViewController {
    
    // MARK: - Properties
    
    private let titleLabel = UILabel().logoLabel()
    
    private let emailTextField: UITextField = {
        return UITextField().textField(withPlaceholder: "Email", isSecureTextEntry: false)
    }()
    
    private let fullNameTextField: UITextField = {
        return UITextField().textField(withPlaceholder: "Full Name", isSecureTextEntry: false)
    }()
    
    private let passwordTextField: UITextField = {
        return UITextField().textField(withPlaceholder: "Password", isSecureTextEntry: true)
    }()
    
    private lazy var emailContainerView: UIView = {
        let view = UIView().inputContainerView(image: UIImage(named: "ic_mail_outline_white_2x") ?? UIImage(), textField: emailTextField)
        view.heightAnchor.constraint(equalToConstant: 50).isActive = true
        return view
    }()
    
    private lazy var fullnameContainerView: UIView = {
        let view = UIView().inputContainerView(image: UIImage(named: "ic_person_outline_white_2x") ?? UIImage(), textField: fullNameTextField)
        view.heightAnchor.constraint(equalToConstant: 50).isActive = true
        return view
    }()
    
    private lazy var passwordContainerView: UIView = {
        let view = UIView().inputContainerView(image: UIImage(named: "ic_lock_outline_white_2x") ?? UIImage(), textField: passwordTextField)
        view.heightAnchor.constraint(equalToConstant: 50).isActive = true
        return view
    }()
    
    private let accountTypeSegmentedControl: UISegmentedControl = {
        let segmentedControl = UISegmentedControl(items: ["Rider", "Driver"])
        segmentedControl.backgroundColor = .backgroundColor
        segmentedControl.tintColor = UIColor(white: 1, alpha: 0.87)
        segmentedControl.selectedSegmentIndex = 0
        return segmentedControl
    }()
    
    private lazy var accountTypeContainerView: UIView = {
        let view = UIView().inputContainerView(image: UIImage(named: "ic_account_box_white_2x") ?? UIImage(), segmentedControl: accountTypeSegmentedControl)
        view.heightAnchor.constraint(equalToConstant: 80).isActive = true
        return view
    }()
    
    private let signUpButton: UIButton = {
        let button = UIButton().authButton(withText: "Sign up")
        button.addTarget(self, action: #selector(handleSignup), for: .touchUpInside)
        return button
    }()
    
    private lazy var alreadyHaveAccountButton: UIButton = {
        let button = UIButton().textAttributesButton(withAttributesText: "Already have an account?  ", text: "Login")
        button.addTarget(self, action: #selector(handleShowLogin), for: .touchUpInside)
        return button
    }()
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        configureUI()
    }
    
    // MARK: - Actions
    
    @objc func handleSignup() {
        guard let email = emailTextField.text else { return }
        guard let password = passwordTextField.text else { return }
        guard let fullname = fullNameTextField.text else { return }
        let accountTypeIndex = accountTypeSegmentedControl.selectedSegmentIndex
        
        let credentials = AuthCredentials(email: email, password: password, fullname: fullname, accountType: accountTypeIndex)
        
        AuthService.registerUser(withCredentials: credentials) { error in
            if let error = error {
                print("register failed \(error.localizedDescription)")
            } else {
                guard let viewController = UIApplication.shared.keyWindow?.rootViewController as? HomeController else { return }
                viewController.configureUI()
                
                self.dismiss(animated: true)
            }
        }
    }
    
    @objc func handleShowLogin() {
        navigationController?.popViewController(animated: true)
    }
    
    // MARK: - Style
    
    func configureUI() {
        view.backgroundColor = .backgroundColor
        
        view.addSubview(titleLabel)
        titleLabel.anchor(top: view.safeAreaLayoutGuide.topAnchor)
        titleLabel.centerX(inView: view)
        
        let stackView = UIStackView(arrangedSubviews: [
            emailContainerView,
            fullnameContainerView,
            passwordContainerView,
            accountTypeContainerView,
            signUpButton
        ])
        
        view.addSubview(stackView)
        stackView.axis = .vertical
        stackView.distribution = .fillProportionally
        stackView.spacing = 24
        stackView.anchor(top: titleLabel.bottomAnchor, left: view.leftAnchor, right: view.rightAnchor, paddingLeft: 16, paddingRight: 16)
        
        view.addSubview(alreadyHaveAccountButton)
        alreadyHaveAccountButton.centerX(inView: view)
        alreadyHaveAccountButton.anchor(bottom: view.safeAreaLayoutGuide.bottomAnchor, height: 32)
    }
}
