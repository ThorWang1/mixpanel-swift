//
//  Network.swift
//  Mixpanel
//
//  Created by Yarden Eitan on 6/2/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

import Foundation

public enum Reason {
  case parseError
  case noData
  case notOKStatusCode(statusCode: Int)
  case other(Error)
}

struct BasePath {
    static let DefaultMixpanelAPI = "https://api.mixpanel.com"
    static var namedBasePaths = [String:String]()
    static var namedEventPaths = [String:String]()

    static func buildURL(base: String, path: String, queryItems: [URLQueryItem]?) -> URL? {
        guard let url = URL(string: base) else {
            return nil
        }
        var components = URLComponents(url: url, resolvingAgainstBaseURL: true)
        components?.path = path
        components?.queryItems = queryItems
        return components?.url
    }

    static func getServerURL(identifier: String) -> String {
        return namedBasePaths[identifier] ?? DefaultMixpanelAPI
    }
  
    static func getEventPath(identifier: String) -> String {
      return namedEventPaths[identifier] ?? FlushType.events.rawValue
    }
}

public enum RequestMethod: String {
    case get
    case post
}

public struct Resource<A> {
    public let path: String
    public let method: RequestMethod
    public let requestBody: Data?
    public let queryItems: [URLQueryItem]?
    public let headers: [String:String]
    public let parse: (Data) -> A?
}

class Network {

    let basePathIdentifier: String

    required init(basePathIdentifier: String) {
        self.basePathIdentifier = basePathIdentifier
    }

    class func apiRequest<A>(base: String,
                          resource: Resource<A>,
                          failure: @escaping (Reason, Data?, URLResponse?) -> (),
                          success: @escaping (A, URLResponse?) -> ()) {
        guard let request = buildURLRequest(base, resource: resource) else {
            return
        }
        if let delegate = Mixpanel.trackingDelegate {
          delegate.executeRequest(request, resource: resource, success: success, failure: failure)
        }
    }

    private class func buildURLRequest<A>(_ base: String, resource: Resource<A>) -> URLRequest? {
        guard let url = BasePath.buildURL(base: base,
                                          path: resource.path,
                                          queryItems: resource.queryItems) else {
            return nil
        }

        var request = URLRequest(url: url)
        request.httpMethod = resource.method.rawValue
        request.httpBody = resource.requestBody

        for (k, v) in resource.headers {
            request.setValue(v, forHTTPHeaderField: k)
        }
        return request as URLRequest
    }

    class func buildResource<A>(path: String,
                             method: RequestMethod,
                             requestBody: Data? = nil,
                             queryItems: [URLQueryItem]? = nil,
                             headers: [String: String],
                             parse: @escaping (Data) -> A?) -> Resource<A> {
        return Resource(path: path,
                        method: method,
                        requestBody: requestBody,
                        queryItems: queryItems,
                        headers: headers,
                        parse: parse)
    }

    class func trackIntegration(apiToken: String, serverURL: String, completion: @escaping (Bool) -> ()) {
        let requestData = JSONHandler.encodeAPIData([["event": "Integration",
                                                      "properties": ["token": "85053bf24bba75239b16a601d9387e17",
                                                                     "mp_lib": "swift",
                                                                     "version": "3.0",
                                                                     "distinct_id": apiToken,
                                                                     "$lib_version": AutomaticProperties.libVersion()]]])

        let responseParser: (Data) -> Int? = { data in
            let response = String(data: data, encoding: String.Encoding.utf8)
            if let response = response {
                return Int(response) ?? 0
            }
            return nil
        }

        if let requestData = requestData {
            let requestBody = "ip=1&data=\(requestData)"
                .data(using: String.Encoding.utf8)

            let resource = Network.buildResource(path: FlushType.events.rawValue,
                                                 method: .post,
                                                 requestBody: requestBody,
                                                 headers: ["Accept-Encoding": "gzip"],
                                                 parse: responseParser)

            Network.apiRequest(base: serverURL,
                               resource: resource,
                               failure: { (reason, data, response) in
                                Logger.debug(message: "failed to track integration")
                                completion(false)
                },
                               success: { (result, response) in
                                Logger.debug(message: "integration tracked")
                                completion(true)
                }
            )
        }
    }
}
