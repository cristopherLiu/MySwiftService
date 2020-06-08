//
//  台灣身分證認證.swift
//  SomeService
//
//  Created by 劉紘任 on 2020/6/8.
//  Copyright © 2020 劉紘任. All rights reserved.
//

import Foundation

//A 台北市 J 新竹縣 S 高雄縣
//B 台中市 K 苗栗縣 T 屏東縣
//C 基隆市 L 台中縣 U 花蓮縣
//D 台南市 M 南投縣 V 台東縣
//E 高雄市 N 彰化縣 W 金門縣
//F 台北縣 O 新竹市 X 澎湖縣
//G 宜蘭縣 P 雲林縣 Y 陽明山
//H 桃園縣 Q 嘉義縣 Z 連江縣
//I 嘉義市 R 台南縣

// 驗證身分證
public func checkID(source: String) -> Bool {
  
  /// 檢查格式，是否符合 開頭是英文字母＋後面9個數字
  func validateFormat(str: String) -> Bool {
    let regex: String = "^[a-z]{1}[1-2]{1}[0-9]{8}$"
    let predicate: NSPredicate = NSPredicate(format: "SELF MATCHES[c] %@", regex)
    return predicate.evaluate(with: str)
  }
  
  /// 轉成小寫字母
  let lowercaseSource = source.lowercased()
  
  if validateFormat(str: lowercaseSource) {
    
    /// 判斷是不是真的，規則在這邊(http://web.htps.tn.edu.tw/cen/other/files/pp/)
    let cityAlphabets: [String: Int] =
      ["a":10,"b":11,"c":12,"d":13,"e":14,"f":15,"g":16,"h":17,"i":34,"j":18,
       "k":19,"l":20,"m":21,"n":22,"o":35,"p":23,"q":24,"r":25,"s":26,"t":27,
       "u":28,"v":29,"w":32,"x":30,"y":31,"z":33]
    
    /// 把 [Character] 轉換成 [Int] 型態
    let ints = lowercaseSource.compactMap{ Int(String($0)) }
    
    /// 拿取身分證第一位英文字母所對應當前城市的
    guard let key = lowercaseSource.first,
      let cityNumber = cityAlphabets[String(key)] else {
        return false
    }
    
    /// 經過公式計算出來的總和
    let firstNumberConvert = (cityNumber / 10) + ((cityNumber % 10) * 9)
    let section1 = (ints[0] * 8) + (ints[1] * 7) + (ints[2] * 6)
    let section2 = (ints[3] * 5) + (ints[4] * 4) + (ints[5] * 3)
    let section3 = (ints[6] * 2) + (ints[7] * 1) + (ints[8] * 1)
    let total = firstNumberConvert + section1 + section2 + section3
    
    /// 總和如果除以10是正確的那就是真的
    if total % 10 == 0 { return true }
  }
  
  return false
}

// 驗證身分證與居留證
public func checkIDAndRC(source: String) -> Bool {
  
  /// 身分證 檢查格式，是否符合 開頭是英文字母＋後面9個數字
  func validate身分證(str: String) -> Bool {
    let regex: String = "^[a-z]{1}[1-2]{1}[0-9]{8}$"
    let predicate: NSPredicate = NSPredicate(format: "SELF MATCHES[c] %@", regex)
    return predicate.evaluate(with: str)
  }
  
  /// 居留證 檢查格式，是否符合 開頭是英文字母＋A~D＋後面8個數字
  func validate居留證(str: String) -> Bool {
    let regex: String = "^[a-z]{1}[a-d]{1}[0-9]{8}$"
    let predicate: NSPredicate = NSPredicate(format: "SELF MATCHES[c] %@", regex)
    return predicate.evaluate(with: str)
  }
  
  // 英文字轉換
  let cityAlphabets: [String: Int] =
    ["a":10,"b":11,"c":12,"d":13,"e":14,"f":15,"g":16,"h":17,"i":34,"j":18,
     "k":19,"l":20,"m":21,"n":22,"o":35,"p":23,"q":24,"r":25,"s":26,"t":27,
     "u":28,"v":29,"w":32,"x":30,"y":31,"z":33]
  
  /// 轉成小寫字母
  let lowercaseSource = source.lowercased()
  
  if validate身分證(str: lowercaseSource) {
    
    /// 拿取身分證第一位英文字母所對應當前城市的
    guard let firstkey = lowercaseSource.first, let firstNumber = cityAlphabets[String(firstkey)] else {
        return false
    }
    
    // 身分證英文轉換成兩位數字 第1位*1 第2位*9 相加
    let firstNumberConvert = ((firstNumber / 10) * 1) + ((firstNumber % 10) * 9)
    
    // 提取後面九碼 把 [Character] 轉換成 [Int] 型態
    let ints = lowercaseSource.compactMap{ Int(String($0)) }
    
    let section1 = (ints[0] * 8) + (ints[1] * 7) + (ints[2] * 6)
    let section2 = (ints[3] * 5) + (ints[4] * 4) + (ints[5] * 3)
    let section3 = (ints[6] * 2) + (ints[7] * 1) + (ints[8] * 1)
    let total = firstNumberConvert + section1 + section2 + section3
    
    /// 總和如果除以10是正確的那就是真的
    return total % 10 == 0
  }
  
  if validate居留證(str: lowercaseSource) {
    
    let strs = lowercaseSource.compactMap{ String($0) } // 轉成字元陣列
    
    // 拿取身分證第一英文字母
    guard let firstkey = strs.first, let firstNumber = cityAlphabets[firstkey] else {
        return false
    }
    
    // 第一英文轉換成兩位數字 十位數字*1 個位數字*9 相加
    let firstNumberConvert = ((firstNumber / 10) * 1) + ((firstNumber % 10) * 9)
    
    // 拿取身分證第二英文字母
    guard let secNumber = cityAlphabets[strs[1]] else {
        return false
    }
    
    // 第二英文轉換成兩位數字 個位數字*8
    let secNumberConvert = (secNumber % 10) * 8
    
    // 提取後面八碼 把 [Character] 轉換成 [Int] 型態
    let ints = lowercaseSource.compactMap{ Int(String($0)) }
    
    let section1 = (ints[0] * 7) + (ints[1] * 6)
    let section2 = (ints[2] * 5) + (ints[3] * 4) + (ints[4] * 3)
    let section3 = (ints[5] * 2) + (ints[6] * 1) + (ints[7] * 1)
    let total = firstNumberConvert + secNumberConvert + section1 + section2 + section3
    
    /// 總和如果除以10是正確的那就是真的
    return total % 10 == 0
  }
  
  return false
}
