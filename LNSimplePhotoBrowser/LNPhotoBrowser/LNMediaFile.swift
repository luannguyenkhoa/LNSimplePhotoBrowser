//
//  LNMediaFile.swift
//  LNSimplePhotoBrowser
//
//  Created by Luan Nguyen on 8/12/16.
//  Copyright © 2016 Luan Nguyen. All rights reserved.
//

import UIKit

// MARK: Media file
protocol LNMediaFile {
  
  var videoURL: String? {get set}
  var imageURL: String? {get set}
  var image: UIImage? {get set}
  var isVideo: Bool {get}
  var videoType: LNOnlVideoType {get set}
  var isLocalFile: String? -> Bool {get}
}

struct LNFile: LNMediaFile {
  
  var videoURL: String?
  var image: UIImage?
  var imageURL: String?
  var isVideo: Bool {
    get {
      return videoURL != nil
    }
  }
  var videoType: LNOnlVideoType = .Other
  let isLocalFile: String? -> Bool = { url in
    guard let path = url else { return false }
    return NSFileManager.defaultManager().fileExistsAtPath(path)
  }
  
  init() {}
  
  init(videoURL: String) {
    self.init()
    self.videoURL = videoURL
  }
  
  init(videoURL: String, imageURL: String?, videoType: LNOnlVideoType) {
    self.init(videoURL: videoURL)
    self.imageURL = imageURL
    self.videoType = videoType
  }
  
  init(imageURL: String) {
    self.init()
    self.imageURL = imageURL
  }
  
  init(image: UIImage) {
    self.init()
    self.image = image
  }
}
