//
//  CallDirectoryHandler.swift
//  CallDirectoryHandler
//
//  Created by Brian on 29/03/17.
//  Copyright © 2017 BCS. All rights reserved.
//

import Foundation
import CallKit

class CallDirectoryHandler: CXCallDirectoryProvider {
    
    override func beginRequest(with context: CXCallDirectoryExtensionContext) {
        context.delegate = self
        
        do {
            try addBlockingPhoneNumbers(to: context)
        } catch {
            NSLog("Unable to add blocking phone numbers")
            let error = NSError(domain: "CallDirectoryHandler", code: 1, userInfo: nil)
            context.cancelRequest(withError: error)
            return
        }
        
        do {
            try addIdentificationPhoneNumbers(to: context)
        } catch {
            NSLog("Unable to add identification phone numbers")
            let error = NSError(domain: "CallDirectoryHandler", code: 2, userInfo: nil)
            context.cancelRequest(withError: error)
            return
        }
        
        context.completeRequest()
    }
    
    private func addBlockingPhoneNumbers(to context: CXCallDirectoryExtensionContext) throws {
        let patterns = self.getBlockedContacts()
        NSLog("CallBlocker: Found \(patterns.count) patterns to block.")
        
        var allNumbers: Set<Int64> = []
        
        for pattern in patterns {
            let expanded = expandPattern(pattern)
            for num in expanded {
                allNumbers.insert(num)
            }
        }
        
        // CallKit 要求号码必须是升序排列
        let sortedNumbers = allNumbers.sorted()
        NSLog("CallBlocker: Adding \(sortedNumbers.count) total unique numbers to blocking database.")
        
        for phoneNumber in sortedNumbers {
            context.addBlockingEntry(withNextSequentialPhoneNumber: phoneNumber)
        }
    }
    
    private func addIdentificationPhoneNumbers(to context: CXCallDirectoryExtensionContext) throws {
        // 暂时留空，防止与拦截逻辑冲突。待拦截生效后再添加。
        NSLog("CallBlocker: Skipping identification for now.")
    }
    
    // 辅助函数：将 "1519650****" 展开为具体数字列表
    private func expandPattern(_ pattern: String) -> [Int64] {
        // 移除所有非数字字符（除了 *）
        var cleanPattern = pattern.trimmingCharacters(in: .whitespacesAndNewlines)
        cleanPattern = cleanPattern.replacingOccurrences(of: "+", with: "")
        cleanPattern = cleanPattern.filter { "0123456789*".contains($0) }
        
        if cleanPattern.isEmpty { return [] }
        
        var results: [String] = [cleanPattern]
        
        // 循环替换每个 '*'
        while let _ = results.first(where: { $0.contains("*") }) {
            var nextBatch: [String] = []
            for p in results {
                if let starRange = p.range(of: "*") {
                    for i in 0...9 {
                        let newP = p.replacingCharacters(in: starRange, with: "\(i)")
                        nextBatch.append(newP)
                    }
                } else {
                    nextBatch.append(p)
                }
            }
            results = nextBatch
            
            // 安全限制：防止展开过多号码导致扩展崩溃
            if results.count > 10000 { 
                NSLog("CallBlocker: Pattern too broad, limiting to 10,000 entries.")
                break 
            }
        }
        
        return results.compactMap { Int64($0) }
    }
    
    func updateBlockedContactsList(contacts: [String]) {
        let defaults = UserDefaults(suiteName: "group.com.incomingBlocker")
        defaults?.removeObject(forKey: "blockList")
        defaults?.set(contacts, forKey: "blockList")
        defaults?.synchronize()
    }
    
    func getBlockedContacts() -> [String] {
        let defaults = UserDefaults(suiteName: "group.com.incomingBlocker")
        let blockedContacts = defaults?.value(forKey: "blockList")
        return (blockedContacts as? [String]) ?? []
    }
    
}

extension CallDirectoryHandler: CXCallDirectoryExtensionContextDelegate {

    func requestFailed(for extensionContext: CXCallDirectoryExtensionContext, withError error: Error) {
        // An error occurred while adding blocking or identification entries, check the NSError for details.
        // For Call Directory error codes, see the CXErrorCodeCallDirectoryManagerError enum in <CallKit/CXError.h>.
        //
        // This may be used to store the error details in a location accessible by the extension's containing app, so that the
        // app may be notified about errors which occured while loading data even if the request to load data was initiated by
        // the user in Settings instead of via the app itself.
        print(error)
    }

}
