//
//  LNMediaProcessing.swift
//  LNSimplePhotoBrowser
//
//  Created by Luan Nguyen on 7/25/16.
//  Copyright © 2016 Luan Nguyen. All rights reserved.
//

import UIKit
import Haneke
import AVKit
import AVFoundation
import MediaPlayer

let kYoutubePrefixVideoURL = "https://www.youtube.com/watch?v="

struct LNMediaProcessing {
  
  static let singleton = LNMediaProcessing()
  
  typealias Rendering = (UIImage?) -> ()
  typealias Converting = (URL?) -> UIImage?
  typealias Checking = (String?) -> Bool
  
  fileprivate let cache: Cache = Cache<UIImage>(name: "thumnails")
  
  func loadImage(_ item: LNMediaFile, render: @escaping Rendering) {
    // Check type of media file and retrieve image
    if let img = item.image {
      // Always rendering image to view on main thread
      DispatchQueue.main.async(execute: { 
        render(img)
      })
      return
    }
    // Retrieve image from url
    if let imageURL = item.imageURL {
      retrieveImage(render) |> imageURL
      return
    }
    
    // Retrieve video thumbnail image from video url
    if let urlStr = item.videoURL {
      videoThumbnailFromFile(urlStr, render: render, isLocal: item.isLocalFile)
      return
    }
  }
  
  fileprivate func retrieveImage(_ g: @escaping Rendering) -> (String) -> ()? {
    return { url in
      self.retrieveImageFromURL(url, f: { urlStr in
        guard let urlStr = urlStr, let url = URL(string: urlStr) else { return nil }
        // Load image from url link
        let fetcher: NetworkFetcher = NetworkFetcher<UIImage>(URL: url)
        // Fetching image from url with caching data
        Shared.imageCache.fetch(fetcher: fetcher).onSuccess({ img in
          g(img)
        })
        return nil
      })
    }
  }
  
  fileprivate func videoThumbnailFromFile(_ urlStr: String?, render: @escaping Rendering, isLocal: @escaping Checking) {
    guard let urlStr = urlStr else { return }
    // Loading image from caching data as the first
    cache.fetch(key: urlStr).onSuccess { img in
      DispatchQueue.main.async(execute: {
        render(img)
      })
    }.onFailure { err in
      self.fetchImageFromVideoURL(urlStr, render: render, isLocal: isLocal)
    }
  }
  
  fileprivate func fetchImageFromVideoURL(_ urlStr: String, render: @escaping Rendering, isLocal: @escaping Checking) {
    // Perform retrieving image in background thread
    DispatchQueue.global().async {
      var avasset: AVAsset?
      if isLocal(urlStr) {
        // Using avasset for thumbnail image generation
        avasset = AVAsset(url: URL(fileURLWithPath: urlStr))
      } else {
        if let url = URL(string: urlStr) {
          avasset = AVPlayer(url: url).currentItem?.asset
        }
      }
      guard let asset = avasset else { return }
      self.imageFromAsset(asset, urlStr: urlStr, render: render)
    }
  }
  /**
   Getting image from avasset
   
   - parameter asset:  avasset that was created from url
   - parameter urlStr: url string
   - parameter render: rendering image closure
   */
  fileprivate func imageFromAsset(_ asset: AVAsset, urlStr: String, render: @escaping Rendering) {
    let imgGenerator = AVAssetImageGenerator(asset: asset)
    imgGenerator.maximumSize = CGSize(width: 750, height: 1334)
    
    // This will helps to fixing thumbnail image is rotated issue
    imgGenerator.appliesPreferredTrackTransform = true
    let time = CMTime(seconds: 3, preferredTimescale: 1)
    
    do {
      let imgRef = try imgGenerator.copyCGImage(at: time, actualTime: nil)
      // Caching image
      let img = UIImage(cgImage: imgRef)
      self.cache.set(value: img, key: urlStr)
      // Move up to main thread for data rendering
      DispatchQueue.main.async(execute: {
        render(img)
      })
    } catch let err {
      print(err)
      // Using default image if getting image from avasset is failed
      self.renderImageAsset(render) |> "Video-Streaming"
    }
  }
  
  /**
   Retrieving image from asset by image name and rendering it to view
   
   - parameter render: rendering image to view closure
   */
  fileprivate func renderImageAsset(_ render: @escaping Rendering) -> (String) -> () {
    return { imgName in
      DispatchQueue.global().async {
        // Retrieving image from asset on background thread
        let img = UIImage(named: imgName)
        DispatchQueue.main.async {
          // Rendering image to view on main thread
          render(img)
        }
      }
    }
  }
  
  // A functional for retrieving image and redering data
  fileprivate func retrieveImageFromURL<T, V>(_ url: T?, f: (T?) -> V?) -> V? {
    return f(url)
  }
  
}
