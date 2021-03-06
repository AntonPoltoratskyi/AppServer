//
//  MenuCategory.swift
//  AppServer
//
//  Created by Anton Poltoratskyi on 27.11.16.
//
//

import Foundation
import Vapor
import Fluent
import HTTP

final class MenuCategory: Model {
    
    var id: Node?
    var name: String
    var description: String
    var merchantId: Node
    var photoUrl: String?
    
    var exists: Bool = false
    
    
    init(name: String, description: String, merchantId: Node, photoUrl: String? = nil) {
        self.name = name
        self.description = description
        self.merchantId = merchantId
        self.photoUrl = photoUrl
    }
    
    
    //MARK: - NodeConvertible
    
    init(node: Node, in context: Context) throws {
        id = try node.extract("_id")
        name = try node.extract("name")
        description = try node.extract("description")
        photoUrl = try node.extract("photo_url")
        merchantId = try node.extract("merchant_id")
    }
    
    func makeNode(context: Context) throws -> Node {
        return try Node(node: [
            "_id": id,
            "name": name,
            "description": description,
            "photo_url": photoUrl,
            "merchant_id": merchantId
            ])
    }
}


//MARK: - Preparation
extension MenuCategory {
    
    static func prepare(_ database: Database) throws {
        try database.create("menu_categories") { users in
            users.id("_id")
            users.string("name")
            users.string("description")
            users.string("photo_url")
            users.id("merchant_id")
        }
    }
    
    static func revert(_ database: Database) throws {
        try database.delete("menu_categories")
    }
}


//MARK: - DB Relations
extension MenuCategory {
    
    func merchant() throws -> Parent<Merchant> {
        return try parent(merchantId)
    }
    
    func menuItems() -> Children<MenuItem> {
        return children("menu_category_id", MenuItem.self)
    }
}


//MARK: - Request
extension Request {
    
    func menuCategory() throws -> MenuCategory {
        
        guard let categoryId = data["category_id"]?.string else {
            throw Abort.custom(status: .badRequest, message: "Category id required")
        }
        
        guard let menuCategory = try MenuCategory.find(categoryId) else {
            throw Abort.custom(status: .badRequest, message: "Category not found")
        }
        return menuCategory
    }
}





