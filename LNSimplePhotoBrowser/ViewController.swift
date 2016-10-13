//
//  ViewController.swift
//  LNSimplePhotoBrowser
//
//  Created by Luan Nguyen on 7/24/16.
//  Copyright © 2016 Luan Nguyen. All rights reserved.
//

import UIKit

let kMaxItemsNumber: Int = 12
let kHalfMaxItemsNumber: Int = kMaxItemsNumber/2

class ViewController: UIViewController {
  
  var items: [LNMediaFile]?
  // Lazy initialize properties
  fileprivate lazy var browserContainerView: LNPhotoBrowsering? = {
    let browserContainerView = LNPhotoBrowser()
    browserContainerView.datasource = self
    browserContainerView.delegate = self
    browserContainerView.translatesAutoresizingMaskIntoConstraints = false
    browserContainerView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    
    // Add subview and constraints
    self.view.addSubview(browserContainerView)
    self.createConstraints(browserContainerView)
    
    return browserContainerView
  }()
  fileprivate lazy var dispatch_queue: DispatchQueue = DispatchQueue(label: "mapping", attributes: DispatchQueue.Attributes.concurrent)
  fileprivate lazy var dispatch_request_group = DispatchGroup()
  
  fileprivate var defaultSession: URLSession?
  fileprivate var processingRotation: Bool = true
  
  override func viewDidLoad() {
    super.viewDidLoad()
    // Do any additional setup after loading the view, typically from a nib.
    browserContainerView?.setupCollectionView()
    
    // Initial list items
    var images = [LNMediaFile]()
    var videos = [LNMediaFile]()
    
    // Get list images url
    generateImages { res in
      images.append(contentsOf: res)
    }
    // Get list videos url from youtube
    requestListVideosFromYoutube { res in
      videos.append(contentsOf: res)
      videos += ["http://www36.online-convert.com/download-file/3c9e6da27b5e9f98a981054b4c61639b/converted-56ff85d7.mp4",
                 "http://www11.online-convert.com/download-file/cf8bdad18a7e59860ce3bc5d00c11877/converted-1a5041d2.mp4",
                 "http://www30.online-convert.com/download-file/68d7d7b9ab9dd5afecb876aec0211b27/converted-daed38ac.mp4"]
                  .map({ LNFile(videoURL: $0) })
      videos += ["http://qthttp.apple.com.edgesuite.net/1010qwoeiuryfg/sl.m3u8",
                 "http://vevoplaylist-live.hls.adaptive.level3.net/vevo/ch1/appleman.m3u8"]
                .map({ LNFile(videoURL: $0, imageURL: nil, videoType: .stream) })
      if let docs = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first {
        videos += ["/intro01.mp4","/intro02.mp4"].flatMap({docs + $0}).map({ LNFile(videoURL: $0) })
      }
    }
    
    // Waiting for all requests are completed, then intialize items list property by zipping 2 images and videos arrays
    // the items list will be suffled after zipping and mapping two arrays to one.
    dispatch_request_group.notify(queue: dispatch_queue) { [weak self] in
      // Hide network activity indicator on status bar
      UIApplication.shared.isNetworkActivityIndicatorVisible = false
      // Zipping
      self?.items = zip(images, videos).flatMap({ [$0.0, $0.1] }).shuffle()
      // Refresh collectionview on main thread
      DispatchQueue.main.async(execute: {
        self?.browserContainerView?.refresh()
      })
    }
    self.title = "Photos & Videos"
  }
  
  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    processingRotation = false
  }
  
  override func viewWillLayoutSubviews() {
    super.viewWillLayoutSubviews()
    if !processingRotation {
      processingRotation = true
      browserContainerView?.willRotation()
      DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + Double(Int64(0.175 * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC)) { [weak self] in
        self?.browserContainerView?.didRotation()
      }
    }
  }
  
  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    // Dispose of any resources that can be recreated.
  }
  
  // FIXME: Just hack for now, these functions should be in another space like networkManager class,...
  /**
   Sending request to get list of video from youtube,
   
   - parameter completion: handle closure as a param
   */
  fileprivate func requestListVideosFromYoutube(_ completion: @escaping ([LNMediaFile]) -> ()) {
    let yourGoogleApiKey = "AIzaSyDBzUttT6ocPpE-jURkFEr-wEW_vzsDbpM"
    let urlStr = "https://www.googleapis.com/youtube/v3/playlistItems?part=snippet&maxResults=10&playlistId=LLGWpjrgMylyGVRIKQdazrPA&key=\(yourGoogleApiKey)"
    guard let url = URL(string: urlStr) else { return }
    
    var request = URLRequest(url: url)
    request.httpMethod = "GET"
    
    dispatch_request_group.enter()
    let dataTask = defaultSession?.dataTask(with: request) { [weak self] data,res,err in
      
      // Parsing response data
      let ids = self?.parsingResponseData(data)
      DispatchQueue.main.async(execute: {
        if let ids = ids {
          // Send back the results list
          completion(ids)
        }
        if let wSelf = self {
          wSelf.dispatch_request_group.leave()
        }
        
      })
    }
    dataTask?.resume()
  }
  
  /**
   Generating images url list from a site
   
   - parameter completion: handle closure as a param
   */
  fileprivate func generateImages(_ completion: @escaping ([LNMediaFile]) -> ()) {
    
    defaultSession = URLSession(configuration: .default, delegate: nil, delegateQueue: OperationQueue.main)
    // Show network activity indicator on status bar
    UIApplication.shared.isNetworkActivityIndicatorVisible = true
    
    if let url = URL(string: "https://api.imgflip.com/get_memes") {
      var request = URLRequest(url: url)
      request.httpMethod = "GET"
      
      dispatch_request_group.enter()
      let dataTask = defaultSession?.dataTask(with: request, completionHandler: { [weak self] data, res, err in
        let imgs = self?.parsingImageJSON(data)
        DispatchQueue.main.async(execute: { 
          if let imgs = imgs {
            completion(imgs)
          }
          // Leave group
          if let wSelf = self {
            wSelf.dispatch_request_group.leave()
          }
        })
      }) 
      dataTask?.resume()
      print(dataTask?.originalRequest)
    }
  }
  
  /**
   Parsing response data from youtube videos requesting
   
   - parameter data: response data
   
   - returns: list of videos url and thumbnails url
   */
  fileprivate func parsingResponseData(_ data: Data?) -> [LNMediaFile] {
    let parsing: ([String: AnyObject]) -> [LNMediaFile] = { jsonSerialize in
      // Parsing json
      if let items = jsonSerialize["items"] as? Array<[String: AnyObject]> , items.count > 0 {
        return items[0..<(items.count > kHalfMaxItemsNumber ? kHalfMaxItemsNumber : items.count)].flatMap({ res in
          let snippet = res["snippet"] as? [String: AnyObject]
          let resourceId = snippet?["resourceId"] as? [String: AnyObject]
          let mediumThumb = snippet?["thumbnails"]?["medium"] as? [String: AnyObject]
          if let vidId = resourceId?["videoId"] as? String {
            return LNFile(videoURL: kYoutubePrefixVideoURL + vidId, imageURL: mediumThumb?["url"] as? String, videoType: .youtube)
          }
          return nil
        })
      }
      return []
    }
    return parsingJSONFromData(parsing) |> data
  }
  
  /**
   Parsing reponse data from image generation reqesting
   
   - parameter data: reponse data
   
   - returns: list of images url
   */
  fileprivate func parsingImageJSON(_ data: Data?) -> [LNMediaFile] {
    let parsing: ([String: AnyObject]) -> [LNMediaFile] = { jsonSerialize in
      if let items = jsonSerialize["data"]?["memes"] as? Array<[String: AnyObject]> , items.count > 0 {
        // Mapping as well as getting rid of nil objects from list of Dictionaries to list of strings
        return items[0..<(items.count > kMaxItemsNumber ? kMaxItemsNumber : items.count)].flatMap({$0["url"] as? String}).map({ LNFile(imageURL: $0) })
      }
      return []
    }
    return parsingJSONFromData(parsing) |> data
  }
  
  /**
  A common parse data to object function
   
   - parameter f: parsing closure handler
   
   - returns: functional object
   */
  fileprivate func parsingJSONFromData(_ f: @escaping ([String: AnyObject]) -> [LNMediaFile]) -> (Data?) -> [LNMediaFile] {
    return { data in
      guard let data = data else { return [] }
      do {
        if let jsonSerialize = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String: AnyObject] {
          return f(jsonSerialize)
        }
      } catch let err { print(err) }
      return []
    }
  }
  /**
   Adding views constraints
   
   - parameter view: subview
   */
  fileprivate func createConstraints(_ view: UIView) {
    let views: [String: AnyObject] = ["browserContainerView": view, "topLayoutGuide": topLayoutGuide]
    let horizontalConstraints = NSLayoutConstraint.constraints(withVisualFormat: "H:|[browserContainerView]|", options: [], metrics: nil, views: views)
    self.view.addConstraints(horizontalConstraints)
    
    let verticalConstraints = NSLayoutConstraint.constraints(withVisualFormat: "V:[topLayoutGuide]-[browserContainerView]|", options: [], metrics: nil, views: views)
    self.view.addConstraints(verticalConstraints)
  }
  
  override func willRotate(to toInterfaceOrientation: UIInterfaceOrientation, duration: TimeInterval) {
    processingRotation = true
    browserContainerView?.willRotation()
  }
  override func didRotate(from fromInterfaceOrientation: UIInterfaceOrientation) {
    browserContainerView?.didRotation()
    processingRotation = false
  }
}

extension ViewController: LNPhotoBrowserDatasource {
  
  func numberOfItems() -> Int {
    guard let items = items else { return 0 }
    return items.count
  }
  
  func itemAtIndex(_ index: Int) -> LNMediaFile {
    return items![index]
  }
}

extension ViewController: LNPhotoBrowserDelegate {
  func willDisplayItem(_ item: LNMediaFile) {
    
  }
  
  func didSelectAtIndex(_ index: Int) {
    
  }
}

