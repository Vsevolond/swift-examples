//
//  KeychainManager.swift
//  IOSChatGPT
//
//  Created by Всеволод on 15.06.2023.
//

import Foundation
import Security


enum KeychainStatus {
    case success
    case error
}

protocol KeychainManagerDescription {
    func addApiKey(apiKey: String, completion: @escaping (KeychainStatus) -> Void)
    func getApiKey() -> String?
}


final class KeychainManager: KeychainManagerDescription {
    static let shared: KeychainManagerDescription = KeychainManager()
    
    private init() {}
    
    func addApiKey(apiKey: String, completion: @escaping (KeychainStatus) -> Void) {
        let keychainItemQuery: [CFString : Any] = [
            kSecValueData: apiKey.data(using: .utf8)!,
            kSecAttrService: "API-key",
            kSecAttrAccount: "ChatGPT",
            kSecClass: kSecClassGenericPassword
        ]
        
        let status = SecItemAdd(keychainItemQuery as CFDictionary, nil)
        guard status == errSecSuccess || status == errSecDuplicateItem else {
            completion(.error)
            return
        }
        
        completion(.success)
    }
    
    func getApiKey() -> String? {
        let keychainItemQuery: [CFString : Any] = [
            kSecAttrService: "API-key",
            kSecAttrAccount: "ChatGPT",
            kSecClass: kSecClassGenericPassword,
            kSecReturnData: true
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(keychainItemQuery as CFDictionary, &result)
        
        guard
            status == errSecSuccess,
            let apiKeyData = result as? Data,
            let apiKey = String(data: apiKeyData, encoding: .utf8)
        else {
            return nil
        }
        
        return apiKey
    }
}

