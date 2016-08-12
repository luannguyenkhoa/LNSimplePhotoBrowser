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
  private lazy var browserContainerView: LNPhotoBrowsering? = {
    let browserContainerView = LNPhotoBrowser()
    browserContainerView.datasource = self
    browserContainerView.delegate = self
    browserContainerView.translatesAutoresizingMaskIntoConstraints = false
    browserContainerView.autoresizingMask = [.FlexibleWidth, .FlexibleHeight]
    
    // Add subview and constraints
    self.view.addSubview(browserContainerView)
    self.createConstraints(browserContainerView)
    
    return browserContainerView
  }()
  private lazy var dispatch_queue: dispatch_queue_t = dispatch_queue_create("mapping", DISPATCH_QUEUE_CONCURRENT)
  private lazy var dispatch_request_group = dispatch_group_create()
  
  private var defaultSession: NSURLSession?
  private var processingRotation: Bool = true
  
  override func viewDidLoad() {
    super.viewDidLoad()
    // Do any additional setup after loading the view, typically from a nib.
    browserContainerView?.setupCollectionView()
    
    // Initial list items
    var images = [LNMediaFile]()
    var videos = [LNMediaFile]()
    
    // Get list images url
    generateImages { res in
      images.appendContentsOf(res)
    }
    // Get list videos url from youtube
    requestListVideosFromYoutube { res in
      videos.appendContentsOf(res)
      videos += ["http://www36.online-convert.com/download-file/3c9e6da27b5e9f98a981054b4c61639b/converted-56ff85d7.mp4",
                 "http://www11.online-convert.com/download-file/cf8bdad18a7e59860ce3bc5d00c11877/converted-1a5041d2.mp4",
                 "http://www30.online-convert.com/download-file/68d7d7b9ab9dd5afecb876aec0211b27/converted-daed38ac.mp4"]
                  .map({ LNFile(videoURL: $0) })
      videos += ["http://qthttp.apple.com.edgesuite.net/1010qwoeiuryfg/sl.m3u8",
                 "http://vevoplaylist-live.hls.adaptive.level3.net/vevo/ch1/appleman.m3u8"]
                .map({ LNFile(videoURL: $0, imageURL: nil, videoType: .Stream) })
      if let docs = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true).first {
        videos += ["/intro01.mp4","/intro02.mp4"].flatMap({docs + $0}).map({ LNFile(videoURL: $0) })
      }
    }
    
    // Waiting for all requests are completed, then intialize items list property by zipping 2 images and videos arrays
    // the items list will be suffled after zipping and mapping two arrays to one.
    dispatch_group_notify(dispatch_request_group, dispatch_queue) { [weak self] in
      // Hide network activity indicator on status bar
      UIApplication.sharedApplication().networkActivityIndicatorVisible = false
      // Zipping
      self?.items = zip(images, videos).flatMap({ [$0.0, $0.1] }).shuffle()
      // Refresh collectionview on main thread
      dispatch_async(dispatch_get_main_queue(), {
        self?.browserContainerView?.refresh()
      })
    }
    self.title = "Photos & Videos"
  }
  
  override func viewWillDisappear(animated: Bool) {
    super.viewWillDisappear(animated)
    processingRotation = false
  }
  
  override func viewWillLayoutSubviews() {
    super.viewWillLayoutSubviews()
    if !processingRotation {
      processingRotation = true
      browserContainerView?.willRotation()
      dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(0.175 * Double(NSEC_PER_SEC))), dispatch_get_main_queue()) { [weak self] in
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
  private func requestListVideosFromYoutube(completion: ([LNMediaFile]) -> ()) {
    let yourGoogleApiKey = "AIzaSyDBzUttT6ocPpE-jURkFEr-wEW_vzsDbpM"
    let urlStr = "https://www.googleapis.com/youtube/v3/playlistItems?part=snippet&maxResults=10&playlistId=LLGWpjrgMylyGVRIKQdazrPA&key=\(yourGoogleApiKey)"
    guard let url = NSURL(string: urlStr) else { return }
    
    let mulRequest = NSMutableURLRequest(URL: url)
    mulRequest.HTTPMethod = "GET"
    
    dispatch_group_enter(dispatch_request_group)
    let dataTask = defaultSession?.dataTaskWithRequest(mulRequest) { [weak self] data,res,err in
      
      // Parsing response data
      let ids = self?.parsingResponseData(data)
      dispatch_async(dispatch_get_main_queue(), {
        if let ids = ids {
          // Send back the results list
          completion(ids)
        }
        if let wSelf = self {
          dispatch_group_leave(wSelf.dispatch_request_group)
        }
        
      })
    }
    dataTask?.resume()
    print(dataTask?.originalRequest)
  }
  
  /**
   Generating images url list from a site
   
   - parameter completion: handle closure as a param
   */
  private func generateImages(completion: [LNMediaFile] -> ()) {
    
    defaultSession = NSURLSession(configuration: .defaultSessionConfiguration(), delegate: nil, delegateQueue: NSOperationQueue.mainQueue())
    // Show network activity indicator on status bar
    UIApplication.sharedApplication().networkActivityIndicatorVisible = true
    
    if let url = NSURL(string: "https://api.imgflip.com/get_memes") {
      let requet = NSMutableURLRequest(URL: url)
      requet.HTTPMethod = "GET"
      
      dispatch_group_enter(dispatch_request_group)
      let dataTask = defaultSession?.dataTaskWithRequest(requet) { [weak self] data, res, err in
        let imgs = self?.parsingImageJSON(data)
        dispatch_async(dispatch_get_main_queue(), { 
          if let imgs = imgs {
            completion(imgs)
          }
          // Leave group
          if let wSelf = self {
            dispatch_group_leave(wSelf.dispatch_request_group)
          }
        })
      }
      dataTask?.resume()
      print(dataTask?.originalRequest)
    }
  }
  
  /**
   Parsing response data from youtube videos requesting
   
   - parameter data: response data
   
   - returns: list of videos url and thumbnails url
   */
  private func parsingResponseData(data: NSData?) -> [LNMediaFile] {
    let parsing: [String: AnyObject] -> [LNMediaFile] = { jsonSerialize in
      // Parsing json
      if let items = jsonSerialize["items"] as? Array<[String: AnyObject]> where items.count > 0 {
        return items[0..<(items.count > kHalfMaxItemsNumber ? kHalfMaxItemsNumber : items.count)].flatMap({ res in
          let snippet = res["snippet"] as? [String: AnyObject]
          let resourceId = snippet?["resourceId"] as? [String: AnyObject]
          let mediumThumb = snippet?["thumbnails"]?["medium"] as? [String: AnyObject]
          if let vidId = resourceId?["videoId"] as? String {
            return LNFile(videoURL: kYoutubePrefixVideoURL + vidId, imageURL: mediumThumb?["url"] as? String, videoType: .Youtube)
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
  private func parsingImageJSON(data: NSData?) -> [LNMediaFile] {
    let parsing: [String: AnyObject] -> [LNMediaFile] = { jsonSerialize in
      if let items = jsonSerialize["data"]?["memes"] as? Array<[String: AnyObject]> where items.count > 0 {
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
  private func parsingJSONFromData(f: [String: AnyObject] -> [LNMediaFile]) -> NSData? -> [LNMediaFile] {
    return { data in
      guard let data = data else { return [] }
      do {
        if let jsonSerialize = try NSJSONSerialization.JSONObjectWithData(data, options: .AllowFragments) as? [String: AnyObject] {
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
  private func createConstraints(view: UIView) {
    let views: [String: AnyObject] = ["browserContainerView": view, "topLayoutGuide": topLayoutGuide]
    let horizontalConstraints = NSLayoutConstraint.constraintsWithVisualFormat("H:|[browserContainerView]|", options: [], metrics: nil, views: views)
    self.view.addConstraints(horizontalConstraints)
    
    let verticalConstraints = NSLayoutConstraint.constraintsWithVisualFormat("V:[topLayoutGuide]-[browserContainerView]|", options: [], metrics: nil, views: views)
    self.view.addConstraints(verticalConstraints)
  }
  
  override func willRotateToInterfaceOrientation(toInterfaceOrientation: UIInterfaceOrientation, duration: NSTimeInterval) {
    processingRotation = true
    browserContainerView?.willRotation()
  }
  override func didRotateFromInterfaceOrientation(fromInterfaceOrientation: UIInterfaceOrientation) {
    browserContainerView?.didRotation()
    processingRotation = false
  }
}

extension ViewController: LNPhotoBrowserDatasource {
  
  func numberOfItems() -> Int {
    guard let items = items else { return 0 }
    return items.count
  }
  
  func itemAtIndex(index: Int) -> LNMediaFile {
    return items![index]
  }
}

extension ViewController: LNPhotoBrowserDelegate {
  func willDisplayItem(item: LNMediaFile) {
    
  }
  
  func didSelectAtIndex(index: Int) {
    
  }
}

