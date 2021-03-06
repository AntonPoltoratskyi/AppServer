//
//  AuthenticationMiddleware.swift
//  AppServer
//
//  Created by Anton Poltoratskyi on 06.11.16.
//
//

import Foundation

import Vapor
import HTTP

final class AuthenticationMiddleware: Middleware {
    
    func respond(to request: Request, chainingTo next: Responder) throws -> Response {
        
        guard let token = request.auth.header?.bearer else {
            throw Abort.custom(status: .badRequest, message: "Token is missing")
        }
        
        do {
            let user = try request.auth.user() as? User
            if user?.token != token.string {
                throw Abort.custom(status: .badRequest, message: "Invalid token")
            }
            
        } catch {
            do {
                try request.auth.login(token)
            } catch {
                throw Abort.custom(status: .badRequest, message: "Invalid token")
            }
        }
        
        do {
            return try next.respond(to: request)

//            let response = try next.respond(to: request)
            
//            response.headers["Access-Control-Allow-Origin"] = "*"
            
//            return response
            
        } catch CustomerAuthError.loginExists {
            throw Abort.custom(status: .conflict, message: "Customer login already exists")
            
        } catch MerchantAuthError.loginExists {
            throw Abort.custom(status: .conflict, message: "Merchant login already exists")
            
        } catch CustomerAuthError.invalidCredentials {
            throw Abort.custom(status: .badRequest, message: "Invalid credentials")
            
        } catch MerchantAuthError.invalidCredentials {
            throw Abort.custom(status: .badRequest, message: "Invalid credentials")
        }
    }
}
