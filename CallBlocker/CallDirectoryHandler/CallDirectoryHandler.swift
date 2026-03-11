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
        
        // 1. 检查是否为增量更新 (Apple 推荐，但我们目前使用全量更新方案)
        if context.isIncremental {
            // 如果是增量更新，我们可以选择只添加差异部分。这里为了简单先强制全量刷新。
            context.removeAllBlockingEntries()
            context.removeAllIdentificationEntries()
        }
        
        do {
            try addBlockingPhoneNumbers(to: context)
        } catch {
            NSLog("CallBlocker: Error adding blocking entries: \(error)")
            let err = NSError(domain: "CallDirectoryHandler", code: 1, userInfo: nil)
            context.cancelRequest(withError: err)
            return
        }
        
        do {
            try addIdentificationPhoneNumbers(to: context)
        } catch {
            NSLog("CallBlocker: Error adding identification entries: \(error)")
            let err = NSError(domain: "CallDirectoryHandler", code: 2, userInfo: nil)
            context.cancelRequest(withError: err)
            return
        }
        
        context.completeRequest()
    }
    
    private func addBlockingPhoneNumbers(to context: CXCallDirectoryExtensionContext) throws {
        let patterns = self.getBlockedContacts()
        NSLog("CallBlocker: Extension reading data, count: \(patterns.count)")
        
        var allNumbers: Set<Int64> = []
        
        // --- 强制加入一个硬编码号码用于验证系统拦截是否开启 ---
        // 这里的号码可以设为您用来拨打测试的号码
        allNumbers.insert(8615196505644) 
        
        // 使用 autoreleasepool 处理大批量通配符展开
        autoreleasepool {
            for pattern in patterns {
                let expanded = expandPattern(pattern)
                allNumbers.formUnion(expanded)
            }
        }
        
        // 必须按数值升序排列
        let sortedNumbers = allNumbers.sorted()
        
        for phoneNumber in sortedNumbers {
            context.addBlockingEntry(withNextSequentialPhoneNumber: phoneNumber)
        }
        
        NSLog("CallBlocker: Successfully added \(sortedNumbers.count) blocking entries.")
    }
    
    private func addIdentificationPhoneNumbers(to context: CXCallDirectoryExtensionContext) throws {
        let patterns = self.getBlockedContacts()
        var allNumbers: Set<Int64> = []
        
        autoreleasepool {
            for pattern in patterns {
                let expanded = expandPattern(pattern)
                allNumbers.formUnion(expanded)
            }
        }

        let sortedNumbers = allNumbers.sorted()
        
        for phoneNumber in sortedNumbers {
            // 提交识别标签，例如显示为 "自定义拦截"
            context.addIdentificationEntry(withNextSequentialPhoneNumber: phoneNumber, label: "已拦截号码")
        }
        
        NSLog("CallBlocker: Successfully added \(sortedNumbers.count) identification entries.")
    }
    
    private func expandPattern(_ pattern: String) -> [Int64] {
        var cleanPattern = pattern.trimmingCharacters(in: .whitespacesAndNewlines)
        cleanPattern = cleanPattern.replacingOccurrences(of: "+", with: "")
        cleanPattern = cleanPattern.filter { "0123456789*".contains($0) }
        
        if cleanPattern.isEmpty { return [] }
        
        var results: [String] = [cleanPattern]
        
        while results.count > 0 && results.first!.contains("*") {
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
            
            // Apple 对内存有限制（一般建议 5MB 以内），通配符不能无限展开
            if results.count > 20000 { 
                NSLog("CallBlocker: Warning - Pattern too broad, capped at 20,000")
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
