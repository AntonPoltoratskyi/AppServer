//
//  MerchantController.swift
//  AppServer
//
//  Created by Anton Poltoratskyi on 20.11.16.
//
//

import Foundation
import Vapor
import Auth
import Cookies
import BCrypt
import HTTP

class MerchantController {
    
    weak var drop: Droplet?
    
    init(droplet: Droplet) {
        self.drop = droplet
    }
    
    func setup() {
        guard drop != nil else {
            debugPrint("Drop is nil")
            return
        }
        setupAuth()
        setupRoutes()
    }
    
    private func setupAuth() {
        
        let auth = AuthMiddleware(user: Merchant.self) { value in
            return Cookie(
                name: "vapor-auth",
                value: value,
                expires: Date().addingTimeInterval(60 * 60 * 5), // 5 hours
                secure: true,
                httpOnly: true
            )
        }
        drop?.addConfigurable(middleware: auth, name: "auth")
    }
    
    private func setupRoutes() {
        
        guard let drop = drop else {
            debugPrint("Drop is nil")
            return
        }
        
        let merchantGroup = drop.grouped("merchant").grouped("auth")
        merchantGroup.post("register", handler: register)
        merchantGroup.post("login", handler: login)
        
        let protectedGroup = merchantGroup.grouped(AuthenticationMiddleware())
        protectedGroup.post("logout", handler: logout)
        protectedGroup.post("edit", handler: edit)
        
        let passwordGroup = protectedGroup.grouped("password")
        passwordGroup.post("change", handler: changePassword)
        //passwordGroup.post("forgot", handler: forgotPassword)
    }
    
    
    //MARK: - Auth
    
    func register(_ req: Request) throws -> ResponseRepresentable {
        
        guard let login = req.data["login"]?.string,
                let password = req.data["password"]?.string,
                let businessName = req.data["business_name"]?.string,
                let country = req.data["country"]?.string,
                let city = req.data["city"]?.string,
                let address = req.data["address"]?.string,
                let latitude = req.data["latitude"]?.double,
                let longitude = req.data["longitude"]?.double
            else {
                throw Abort.badRequest
        }
        
        if let _ = try Merchant.query().filter("login", login).first() {
            throw Abort.custom(status: .conflict, message: "User already exist")
        }
        
        var merchant = Merchant(login: login,
                                password: password,
                                businessName: businessName,
                                country: country,
                                city: city,
                                address: address,
                                latitude: latitude,
                                longitude: longitude)
        
        merchant.token = self.token(for: merchant)
        try merchant.save()
        
        return try merchant.makeJSON()
    }
    
    func login(_ req: Request) throws -> ResponseRepresentable {
        
        guard let login = req.data["login"]?.string,
            let password = req.data["password"]?.string else {
                throw Abort.badRequest
        }
        
        let credentials = APIKey(id: login, secret: password)
        try req.auth.login(credentials)
        
        guard let merchantId = try req.auth.user().id, var merchant = try Merchant.find(merchantId) else {
            throw Abort.custom(status: .notFound, message: "User not found")
        }
        
        merchant.token = self.token(for: merchant)
        do {
            try merchant.save()
        } catch {
            print(error)
        }
        
        return try JSON(node: ["message": "Logged in",
                               "access_token" : merchant.token])
    }
    
    func logout(_ req: Request) throws -> ResponseRepresentable {
        
        if var merchant = try req.auth.user() as? Merchant {
            
            do {
                merchant.token = ""
                try merchant.save()
                try req.auth.logout()
                
            } catch {
                print(error)
            }
            
            return try JSON(node: ["error": false,
                                   "message": "Logout succeded"])
        }
        throw Abort.badRequest
    }
    
    
    //MARK: - Edit
    
    func edit(_ req: Request) throws -> ResponseRepresentable {
        
        guard var merchant = try req.auth.user() as? Merchant else {
            throw Abort.custom(status: .badRequest, message: "Invalid credentials")
        }
        
        var isChanged = false
        
        if let newName = req.data["business_name"]?.string {
            merchant.businessName = newName
            isChanged = true
        }
        
        if let newLogin = req.data["login"]?.string {
            
            if (try Merchant.query().filter("login", newLogin).first()) != nil {
                throw Abort.custom(status: .badRequest, message: "Login already exist")
            }
            merchant.login = newLogin
            isChanged = true
        }
        if isChanged {
            try merchant.save()
            return try merchant.makeJSON()
        }
        throw Abort.custom(status: .badRequest, message: "No parameters")
    }
    
    func changePassword(_ req: Request) throws -> ResponseRepresentable {
        
        guard var merchant = try req.auth.user() as? Merchant else {
            throw Abort.custom(status: .badRequest, message: "Invalid credentials")
        }
        
        guard let oldPassword = req.data["old_password"]?.string,
            let newPassword = req.data["new_password"]?.string else {
                throw Abort.custom(status: .badRequest, message: "Old and new passwords required")
        }
        
        //TODO: Validate password with regex.
        
        if merchant.isHashEqual(to: oldPassword) {
            
            merchant.updateHash(from: newPassword)
            try merchant.save()
            
            return try merchant.makeJSON()
        }
        throw Abort.custom(status: .badRequest, message: "Wrong password")
    }
    
    
    //MARK: - Token
    
    func token(for merchant: Merchant) -> String {
        
        let startDate = Date().toString()
        let endDate = Date().addingTimeInterval(24 * 60 * 60).toString()
        
        if let startDate = startDate, let endDate = endDate {
            return encode(["start": startDate, "end": endDate],
                          algorithm: .hs256(merchant.hash.data(using: .utf8)!))
        } else {
            debugPrint("wrong dates")
            return ""
        }
    }
    
    
}