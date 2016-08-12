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
  case Youtube
  case Vimeo
  case Stream
  case Other
}


// MARK: Button extensions
extension UIButton {
  private func actionHandleBlock(action: (()->Void)? = nil) {
    struct __ {
      static var action: (()->Void)?
    }
    if let action = action {
      __.action = action
    } else {
      __.action?()
    }
  }
  
  @objc private func triggerActionHandleBlock() {
    self.actionHandleBlock()
  }
  
  func actionHandler(controlEvents control: UIControlEvents, forAction action: () -> Void) {
    self.actionHandleBlock(action)
    self.addTarget(self, action: #selector(triggerActionHandleBlock), forControlEvents: control)
  }
}

// MARK: String extension

extension String {
  // Seperate a string by a component, then return last object
  func suffix(component: String) -> String? {
    return self.componentsSeparatedByString(component).last
  }
}

// Suffle array
extension CollectionType {
  /// Return a copy of `self` with its elements shuffled
  func shuffle() -> [Generator.Element] {
    var list = Array(self)
    list.shuffleInPlace()
    return list
  }
}

extension MutableCollectionType where Index == Int {
  /// Shuffle the elements of `self` in-place.
  mutating func shuffleInPlace() {
    // empty and single-element collections don't shuffle
    if count < 2 { return }
    
    for i in 0..<count - 1 {
      let j = Int(arc4random_uniform(UInt32(count - i))) + i
      guard i != j else { continue }
      swap(&self[i], &self[j])
    }
  }
}

// MARK: Operator overloading
infix operator |> {associativity left}

func |><A, B> (f: A->B, arg: A) -> B {
  return f(arg)
}

func |> <A, B, C> (f: A-> B, g: B->C) -> A -> C {
  return { g(f($0)) }
}

func |><A> (f: (A)->(), arg: A){
  f(arg)
}