//
//  OrderItem.swift
//  AppServer
//
//  Created by Anton Poltoratskyi on 27.11.16.
//
//

import Foundation
import Vapor
import Fluent

final class OrderItem: Model {
    
    var id: Node?
    var orderId: Node
    var menuItemId: Node
    var quantity: Int
    
    var exists: Bool = false
    
    init(orderId: Node, menuItemId: Node, quantity: Int) {
        self.orderId = orderId
        self.menuItemId = menuItemId
        self.quantity = quantity
    }
    
    //MARK: - NodeConvertible
    
    init(node: Node, in context: Context) throws {
        id = try node.extract("_id")
        orderId = try node.extract("order_id")
        menuItemId = try node.extract("menu_item_id")
        quantity = try node.extract("quantity")
    }
    
    func makeNode(context: Context) throws -> Node {
        return try Node(node: [
            "_id": id,
            "order_id": orderId,
            "menu_item_id": menuItemId,
            "quantity": quantity
            ])
    }
}


//MARK: - Preparation
extension OrderItem {
    
    static func prepare(_ database: Database) throws {
        try database.create("order_items") { users in
            users.id("_id")
            users.id("order_id")
            users.id("menu_item_id")
            users.int("quantity")
        }
    }
    
    static func revert(_ database: Database) throws {
        try database.delete("order_items")
    }
}


//MARK: - Public Response
extension OrderItem: PublicResponseRepresentable {
    
    func publicResponseNode() throws -> Node {
        
        let menuItem = try self.menuItem().get()!
        
        return try Node(node: [
            "_id": id,
            "order_id": orderId,
            "menu_item": menuItem.makeNode(),
            "quantity": quantity,
            "price": menuItem.price * Double(quantity)
            ])
    }
}


//MARK: - DB Relations
extension OrderItem {
    
    func order() throws -> Parent<Order> {
        return try parent(orderId)
    }
    
    func menuItem() throws -> Parent<MenuItem> {
        return try parent(menuItemId)
    }
}


