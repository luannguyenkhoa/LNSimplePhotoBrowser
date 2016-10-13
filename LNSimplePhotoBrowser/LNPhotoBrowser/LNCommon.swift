//
//  LNCommon.swift
//  LNSimplePhotoBrowser
//
//  Created by Luan Nguyen on 8/10/16.
//  Copyright © 2016 Luan Nguyen. All rights reserved.
//

import UIKit

// MARK: Enums
enum LNOnlVideoType {
  case youtube
  case vimeo
  case stream
  case other
}


// MARK: Button extensions
extension UIButton {
  fileprivate func actionHandleBlock(_ action: (()->Void)? = nil) {
    struct __ {
      static var action: (()->Void)?
    }
    if let action = action {
      __.action = action
    } else {
      __.action?()
    }
  }
  
  @objc fileprivate func triggerActionHandleBlock() {
    self.actionHandleBlock()
  }
  
  func actionHandler(controlEvents control: UIControlEvents, forAction action: @escaping () -> Void) {
    self.actionHandleBlock(action)
    self.addTarget(self, action: #selector(triggerActionHandleBlock), for: control)
  }
}

// MARK: String extension

extension String {
  // Seperate a string by a component, then return last object
  func suffix(_ component: String) -> String? {
    return self.components(separatedBy: component).last
  }
}

// Suffle array
extension Collection {
  /// Return a copy of `self` with its elements shuffled
  func shuffle() -> [Iterator.Element] {
    var list = Array(self)
    list.shuffleInPlace()
    return list
  }
}

extension MutableCollection where Index == Int {
  /// Shuffle the elements of `self` in-place.
  mutating func shuffleInPlace() {
    // empty and single-element collections don't shuffle
    if count < 2 { return }
    let counter = self.count.hashValue
    for i in 0..<counter-1 {
      let j = Int(arc4random_uniform(UInt32(counter - i))) + i
      guard i != j else { continue }
      swap(&self[i], &self[j])
    }
  }
}

// MARK: Operator overloading
infix operator |>: AdditionPrecedence

func |><A, B> (f: (A)->B, arg: A) -> B {
  return f(arg)
}

func |> <A, B, C> (f: @escaping (A)-> B, g: @escaping (B)->C) -> (A) -> C {
  return { g(f($0)) }
}

func |><A> (f: (A)->(), arg: A){
  f(arg)
}
