//
//  Client.swift
//  raccoon
//
//  Created by Manuel García-Estañ on 8/10/16.
//  Copyright © 2016 manuege. All rights reserved.
//

import Foundation
import CoreData
import AlamofireCoreData
import PromiseKit
import CancelForPromiseKit
import Alamofire
import baseapp_ios_core_v1

/**
 Clients are instances that can send network requests. The requests are built using `Endpoints`.
 The responses of this endpoints will be inserted in the given managed object context.
 */
public protocol Client {
    /// The base url which will be used to build the reqeusts
    var baseURL: URL { get }
    
    /// The managed object context where all the responses will be inserted.
    var context: NSManagedObjectContext { get }
    
    /// The default session manager
    var sessionManager: Alamofire.SessionManager { get }
    
    /// The background session manager (ex for uploading large files while app is inactive)
    var backgroundSessionManager: Alamofire.SessionManager { get }
    
    /**
     The DataResponseSerializer<Any> which will transform the original response to the JSON which will be used to insert the responses.
     By default it is `DataRequest.jsonResponseSerializer()`
     */
    var jsonSerializer: DataResponseSerializer<Any> { get }
    
    /**
     The `JSONEncoder` which will encode `NSDecodableManagedObject`
     */
    var jsonEncoder: JSONEncoder { get }
    
    /**
     The `JSONDecoder` which will decode `NSDecodableManagedObject`
     */
    var jsonDecoder: JSONDecoder { get }
    
    /**
     Use this method to perform any last minute changes on the DataRequest to send.
     Here you can add some validations, log the requests, or whatever thing you need.
     By default, it returns the request itself, without any addition
     
     - parameter request: The request that will be sent
     - parameter endpoint: The endpoint which launched the reqeust
     
     - returns: the modified request
     */
    func prepare<T>(_ request: T, for endpoint: Endpoint) -> T
        where T: Request
    
    /**
     Use this method to perform any last minute changes on the Promise created when a request is sent.
     Here you can add some common `recover` or `then` to all the promise
     By default, it returns the promise itself, without any addition
     
     - parameter request: The `Promise`
     - parameter endpoint: The `Endpoint` that launched the request
     
     - returns: the modified request
     */
    func process<T>(_ promise: CancellablePromise<T>, for endpoint: Endpoint) -> CancellablePromise<T>
    
    typealias PrepareUploadBlock = (MultipartFormData) throws -> Void
    typealias PrepareUploadResult = SessionManager.MultipartFormDataEncodingResult
}

// MARK: - Defaults

public extension Client {
    var jsonSerializer: DataResponseSerializer<Any> {
        return DataRequest.jsonResponseSerializer()
    }
    
    var jsonEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .formatted(DateFormatter.properISO8601)
        encoder.outputFormatting = .prettyPrinted
        return encoder
    }
    
    var jsonDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .formatted(DateFormatter.properISO8601)
        decoder.userInfo[.managedObjectContext] = context
        return decoder
    }
    
    func prepare<T>(
        _ request: T,
        for endpoint: Endpoint
    ) -> T where T: Request {
        return request
    }
    
    func process<T>(
        _ promise: CancellablePromise<T>,
        for endpoint: Endpoint
    ) -> CancellablePromise<T> {
        return promise
    }
}

// MARK: - Private Instance Functions
private extension Client {
    func preprocess(_ request: Request) -> CancellablePromise<Data> {
        if let dataRequest = request as? DataRequest {
            return dataRequest
                .responseDataCC()
                .map({
                    $0.data
                })
        }
        if let downloadRequest = request as? DownloadRequest {
            return downloadRequest
                .responseDataCC()
                .map({ response -> Data in
                    switch response.result {
                    case .success(let data):
                        return data
                    case .failure(let error):
                        throw error
                    }
                })
        }
        // Will never hit this
        return CancellablePromise(resolver: {
            $0.reject(PMKError.cancelled)
        })
    }
    
    func preprocess<T>(
        _ dataRequest: DataRequest,
        type: T.Type
    ) -> CancellablePromise<T> where T: Insertable {
        let (promise, resolver) = CancellablePromise<T>.pending()
        
        promise.appendCancellableTask(
            task: dataRequest.responseInsert(
                queue: nil,
                jsonSerializer: jsonSerializer,
                context: context,
                type: type,
                completionHandler: { response in
                    switch response.result {
                    case let .success(value):
                        resolver.fulfill(value)
                    case let .failure(error):
                        resolver.reject(error)
                    }
            }),
            reject: nil
        )
        
        return promise
    }
    
    func preprocess<T>(
        _ dataRequest: DataRequest,
        type: T.Type
    ) -> CancellablePromise<T> where T: Decodable {
        return preprocess(dataRequest)
            .map({
                try self.jsonDecoder.decode(type, from: $0)
            })
    }
}

// MARK: - Public Instance Functions

public extension Client {
    /**
     Enqueues the request generated by the endpoint.
     It returns a Cancellable to inform if the request has finished succesfully or not
     
     The request can be cancelled at any time by calling `cancel()` in the cancellable object.
     
     - parameter endpoint: The endpoint
     
     - returns: The cancellable object
     */
    func enqueue(_ endpoint: Endpoint) -> CancellablePromise<Data> {
        return process(
            prepare(sessionManager.request(for: endpoint, baseURL: baseURL), for: endpoint)
                .responseDataCC()
                .map({
                    $0.data
                }),
            for: endpoint
        )
    }
    
    /**
     Enqueues the request generated by the endpoint and insert it using the generic type.
     It returns a Cancellable to inform if the request has finished succesfully or not.
     
     The request can be cancelled at any time by calling `cancel()` in the cancellable object.
     
     - parameter endpoint: The endpoint
     
     - returns: The Cancellable object
     */
    func enqueue<T>(
        _ endpoint: Endpoint
    ) -> CancellablePromise<T> where T: Insertable {
        return process(
            preprocess(
                prepare(sessionManager.request(for: endpoint, baseURL: baseURL), for: endpoint),
                type: T.self
            ),
            for: endpoint
        )
    }
    
    
    /**
     Enqueues the request generated by the endpoint and insert it using the process function.
     It returns a Cancellable to inform if the request has finished succesfully or not.
     
     The request can be cancelled at any time by calling `cancel()` in the cancellable object.
     
     - parameter endpoint: The endpoint
     
     - returns: The Cancellable object
     */
    func enqueue<T>(
        _ endpoint: Endpoint,
        _ type: T.Type
    ) -> CancellablePromise<T> where T: Decodable {
        return process(
            preprocess(
                prepare(sessionManager.request(for: endpoint, baseURL: baseURL), for: endpoint),
                type: T.self
            ),
            for: endpoint
        )
    }
    
    /**
     Prepares a `MultipartFormData` request generated by the `endpoint`.
     
     - parameter endpoint: `Endpoint`
     - parameter prepare: `(MultipartFormData) -> Void`
     - parameter encodingMemoryThreshold: `UInt64`
     
     - returns: `CancellablePromise<T>`
     */
    func prepareUpload(
        _ endpoint: Endpoint,
        prepare: @escaping PrepareUploadBlock,
        usingThreshold encodingMemoryThreshold: UInt64 = SessionManager.multipartFormDataEncodingMemoryThreshold
    ) -> CancellablePromise<PrepareUploadResult> {
        let (promise, resolver) = CancellablePromise<PrepareUploadResult>.pending()
        backgroundSessionManager.upload(
            multipartFormData: {
                do {
                    try prepare($0)
                } catch {
                    resolver.reject(error)
                }
        },
            usingThreshold: encodingMemoryThreshold,
            to: endpoint.url(withBaseURL: baseURL),
            method: endpoint.info.method,
            headers: endpoint.headers(),
            encodingCompletion: { result in
                resolver.fulfill(result)
        })
        return promise
    }
    
    /**
     Enqueues a `MultipartFormData` request generated by the `endpoint`.
     
     - parameter endpoint: `Endpoint`
     - parameter prepare: `(MultipartFormData) -> Void`
     - parameter encodingMemoryThreshold: `UInt64`
     - parameter onProgress: `(Progress) -> Void`
     
     - returns: `CancellablePromise<UploadRequest>`
     */
    func enqueueUpload(
        _ endpoint: Endpoint,
        prepare: @escaping PrepareUploadBlock,
        usingThreshold encodingMemoryThreshold: UInt64 = SessionManager.multipartFormDataEncodingMemoryThreshold,
        onProgress: UploadRequest.ProgressHandler? = nil
    ) -> CancellablePromise<UploadRequest> {
        return prepareUpload(endpoint, prepare: prepare, usingThreshold: encodingMemoryThreshold)
            .map({ result -> (request: UploadRequest, streamingFromDisk: Bool, streamFileURL: URL?) in
                switch result {
                case .success(let request, let streamingFromDisk, let streamFileURL):
                    request.uploadProgress(closure: { progress in
                        onProgress?(progress)
                    })
                    return (request, streamingFromDisk, streamFileURL)
                case .failure(let error):
                    throw error
                }
            })
            .map({ result in
                result.request
            })
    }
    
    /**
     Enqueues a `MultipartFormData` request generated by the `endpoint`.
     
     - parameter endpoint: `Endpoint`
     - parameter prepare: `(MultipartFormData) -> Void`
     - parameter encodingMemoryThreshold: `UInt64`
     - parameter onProgress: `(Progress) -> Void`
     
     - returns: `CancellablePromise<Data>`
     */
    func enqueueUpload(
        _ endpoint: Endpoint,
        prepare: @escaping PrepareUploadBlock,
        usingThreshold encodingMemoryThreshold: UInt64 = SessionManager.multipartFormDataEncodingMemoryThreshold,
        onProgress: UploadRequest.ProgressHandler? = nil
    ) -> CancellablePromise<Data> {
        return enqueueUpload(endpoint, prepare: prepare, usingThreshold: encodingMemoryThreshold, onProgress: onProgress)
            .then({ uploadRequest in
                self.process(
                    self.preprocess(
                        self.prepare(uploadRequest, for: endpoint)
                    ),
                    for: endpoint
                )
            })
    }
    
    /**
     Enqueues a file download request generated by the `endpoint`.
     
     - parameter endpoint: `Endpoint`
     - parameter fileURL: `URL` A fileURL where the downloaded file should be saved to
     - parameter overwriteExisting: `Bool` Delete existing file if it exists
     - parameter onProgress: `(Progress) -> Void`
     
     - returns: `CancellablePromise<URL>` The fileURL where the downloaded file was saved
     */
    func enqueueDownload(
        _ endpoint: Endpoint,
        andSaveTo fileURL: URL,
        overwriteExisting: Bool = false,
        onProgress: DownloadRequest.ProgressHandler? = nil
    ) -> CancellablePromise<URL> {
        return process(
            FileDownloader.shared.download(
                prepare(
                    backgroundSessionManager.download(
                        endpoint.url(withBaseURL: baseURL),
                        method: endpoint.info.method,
                        parameters: endpoint.info.parameters,
                        encoding: endpoint.info.encoding,
                        headers: endpoint.headers(),
                        to: { _, _ in
                            return (fileURL, [
                                DownloadRequest.DownloadOptions.createIntermediateDirectories
                            ])
                    }),
                    for: endpoint
                ),
                andSaveTo: fileURL,
                overwriteExisting: overwriteExisting,
                onProgress: onProgress
            ),
            for: endpoint
        )
    }
}
