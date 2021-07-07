//
//  AlamofireSessionManager+Raccoon.swift
//  raccoon
//
//  Created by Pat Sluth on 2019-11-14.
//  Copyright © 2019 Pat Sluth. All rights reserved.
//

import Alamofire
import Foundation


extension Alamofire.SessionManager {
    func request(for endpoint: Endpoint, baseURL: URL) -> DataRequest {
        return request(
            endpoint.url(withBaseURL: baseURL),
            method: endpoint.info.method,
            parameters: endpoint.info.parameters,
            encoding: endpoint.info.encoding,
            headers: endpoint.headers()
        )
    }
}
