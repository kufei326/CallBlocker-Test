//
//  ViewController.swift
//  CallBlocker
//
//  Created by Brian on 29/03/17.
//  Copyright © 2017 BCS. All rights reserved.
//

import UIKit
import Foundation
import CallKit

let appDelegate = UIApplication.shared.delegate as! AppDelegate

class ViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    @IBOutlet weak var phoneTextFld: UITextField!
    @IBOutlet weak var tblView: UITableView!
    var blockList: [String] = []

    // MARK: - System methods
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Do any additional setup after loading the view, typically from a nib.
        self.navigationItem.title = "Call blocklist";
        
        // 从本地存储加载已有的黑名单
        self.blockList = appDelegate.getBlockedContacts().sorted()
        self.tblView.reloadData()
        
        // 启动时检查系统开关状态
        self.checkExtensionStatus()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: - Button actions
    
    @IBAction func blockBtnAction(_ sender: Any) {
        
        var tel: String = self.phoneTextFld.text ?? ""
        if tel.isEmpty {
            print("tel is nil")
            return
        }
        
        // 移除空格和特殊字符，但保留 '*' 和 '+'
        tel = tel.replacingOccurrences(of: " ", with: "")
        
        self.phoneTextFld.text = ""
        self.view.endEditing(true)
        
        if self.blockList.contains(tel) {
            return
        }
        
        // 添加到列表
        self.blockList.append(tel)
        
        // 排序
        self.blockList.sort()
        
        // 刷新列表
        self.tblView.reloadData()
        
        // 同步到系统扩展
        self.syncUD()
    }
    
    
    // MARK: - User defined methods
    
    func checkExtensionStatus() {
        let mainBundleId = Bundle.main.bundleIdentifier ?? "com.bcs.incomingBlocker"
        let extensionId = "\(mainBundleId).CallDirectoryHandler"
        
        CXCallDirectoryManager.sharedInstance.getEnabledStatusForExtension(withIdentifier: extensionId) { (status, error) in
            DispatchQueue.main.async {
                var message = ""
                switch status {
                case .enabled:
                    print("CallBlocker: Extension is ENABLED")
                    return // 已开启，无需提醒
                case .disabled:
                    message = "拦截扩展已禁用，请前往：设置 -> 电话 -> 来电阻止与身份识别 中开启开关。"
                case .unknown:
                    message = "无法获取扩展状态，请确认 Bundle ID 是否正确。"
                @unknown default:
                    message = "未知的扩展状态。"
                }
                
                let alert = UIAlertController(title: "需要开启权限", message: message, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "确定", style: .default, handler: nil))
                self.present(alert, animated: true, completion: nil)
            }
        }
    }
    
    func syncUD() {
        // 保存黑名单到 UserDefaults (App Group)
        appDelegate.updateBlockedContactsList(contacts: self.blockList)
        
        // 获取当前 App 的 Bundle ID 并尝试拼接 Extension 的 ID
        let mainBundleId = Bundle.main.bundleIdentifier ?? "com.bcs.incomingBlocker"
        let extensionId = "\(mainBundleId).CallDirectoryHandler"
        
        print("CallBlocker: Attempting to reload extension: \(extensionId)")
        
        // 通知系统刷新拦截规则
        CXCallDirectoryManager.sharedInstance.reloadExtension(withIdentifier: extensionId) { error in
            DispatchQueue.main.async {
                if let error = error {
                    print("CallBlocker: Failed to reload extension: \(error.localizedDescription)")
                    let alert = UIAlertController(title: "同步失败", message: "系统拒绝刷新: \(error.localizedDescription)\n请检查 Bundle ID 和 App Group 配置。", preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "好的", style: .default, handler: nil))
                    self.present(alert, animated: true, completion: nil)
                } else {
                    print("CallBlocker: Successfully requested extension reload.")
                    let alert = UIAlertController(title: "同步成功", message: "拦截规则已提交给系统，请测试号码是否被拦截。", preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "确定", style: .default, handler: nil))
                    self.present(alert, animated: true, completion: nil)
                }
            }
        }
    }
    
    // MARK: - Table view delegates & datasources
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection: Int) -> Int {
        let number = self.blockList.count
        return number
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        cell.tintColor = UIColor(red: 255.0/255.0, green:102.0/255.0, blue:102.0/255.0, alpha:1.0)
        cell.accessoryType = cell.isSelected ? .checkmark : .none
        cell.selectionStyle = .none // to prevent cells from being "highlighted"
        
        let num = self.blockList[(indexPath as NSIndexPath).row]
        cell.textLabel!.text = num
        print("row \(indexPath.row) and item \(self.blockList[indexPath.row])")
        return cell
    }
    
    
    public func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == UITableViewCell.EditingStyle.delete {
            self.blockList.remove(at: indexPath.row)
            self.tblView.deleteRows(at: [indexPath], with: UITableView.RowAnimation.automatic)
            self.syncUD()
        }
    }
}
