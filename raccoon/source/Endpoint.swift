//
//  Endpoint.swift
//  raccoon
//
//  Created by Manuel García-Estañ on 8/10/16.
//  Copyright © 2016 manuege. All rights reserved.
//

import Foundation
import Alamofire

/* An Endpoint is just an instance that can build a `DataRequest` from a base url.
 Use it to enqueue request in a client
 */
public protocol Endpoint {
    var info: EndpointInfo { get }
    func headers() -> HTTPHeaders?
}

// MARK: - Internal Functions
extension Endpoint {
    func url(withBaseURL baseURL: URL) -> URLConvertible {
        return URL(string: info.path, relativeTo: baseURL) ?? baseURL
    }
}

// MARK: - Base Endpoint Info

/// A struct encapsulating all required info needed for building requests from an endpoint.
public struct EndpointInfo {
    
    // MARK: - Public Instance Attributes
    public let path: String
    public let method: Alamofire.HTTPMethod
    public let parameters: Parameters?
    public let encoding: Alamofire.ParameterEncoding
    public let requiresAuthorization: Bool
    
    
    // MARK: - Initializers
    public init(path: String,
                method: HTTPMethod,
                parameters: Parameters?,
                encoding: ParameterEncoding?,
                requiresAuthorization: Bool) {
        self.path = path
        self.method = method
        self.parameters = parameters
        if let encoding = encoding {
            self.encoding = encoding
        } else {
            switch self.method {
            case .get:
                self.encoding = URLEncoding.queryString
            default:
                self.encoding = JSONEncoding.default
            }
        }
        self.requiresAuthorization = requiresAuthorization
    }
    
    public init(pathComponents: Any...,
        method: HTTPMethod,
        parameters: Parameters?,
        encoding: ParameterEncoding?,
        requiresAuthorization: Bool) {
        self.init(
            path: pathComponents.joined(by: "/"),
            method: method,
            parameters: parameters,
            encoding: encoding,
            requiresAuthorization: requiresAuthorization
        )
    }
    
    public init(pathComponents: [Any],
                method: HTTPMethod,
                parameters: Parameters?,
                encoding: ParameterEncoding?,
                requiresAuthorization: Bool) {
        self.init(
            path: pathComponents.joined(by: "/"),
            method: method,
            parameters: parameters,
            encoding: encoding,
            requiresAuthorization: requiresAuthorization
        )
    }
}
