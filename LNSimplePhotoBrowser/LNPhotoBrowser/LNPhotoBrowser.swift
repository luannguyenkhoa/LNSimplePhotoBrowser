//
//  TSPhotoBrowser.swift
//  LNSimplePhotoBrowser
//
//  Created by Luan Nguyen on 7/24/16.
//  Copyright © 2016 Luan Nguyen. All rights reserved.
//

import UIKit
import AVKit
import AVFoundation
import Photos

// MARK: protocol oriented

protocol LNPhotoBrowsering {
  
  // Properties
  var currentIndex: Int? {get}
  var currentItem: LNMediaFile? {get}
  var startIndex: Int?{get set}
  
  // Functions
  func setupCollectionView()
  func refresh()
  func willRotation()
  func didRotation()
}

// MARK: Custom datasouce and delegate
protocol LNPhotoBrowserDatasource: class {
  
  func numberOfItems() -> Int
  func itemAtIndex(index: Int) -> LNMediaFile
  
}

protocol LNPhotoBrowserDelegate: class {
  
  func willDisplayItem(item: LNMediaFile)
  func didSelectAtIndex(index: Int)
}

// MARK: Main class
internal final class LNPhotoBrowser: UIView, LNPhotoBrowsering {
  
  let cellIdentifier: String = "mediaCell"
  
  var currentIndex: Int?
  var currentItem: LNMediaFile? {
    get {
      return currentCell?.cellItem
    }
  }
  var startIndex: Int?
  weak var delegate: LNPhotoBrowserDelegate?
  weak var datasource: LNPhotoBrowserDatasource?
  
  private var items: [LNMediaFile]?
  private var collectionView: UICollectionView?
  private var flowLayout: UICollectionViewFlowLayout?
  private var currentCell: LNMediaCollectionViewCell?
  private lazy var videoPlayerVC: AVPlayerViewController = self.initialMoviePlayer()
  private lazy var topViewController: UIViewController = self.getTopController()
  private lazy var youtubePlayerVC: LNYoutubePlayerViewController = self.initialYoutubePlayerViewController()

  private var currentIndexForRotation: Int?
  
  override func awakeFromNib() {
    super.awakeFromNib()
  }

  deinit {
    NSNotificationCenter.defaultCenter().removeObserver(self)
  }
  
  /**
   Setup collectionview
   */
  func setupCollectionView() {
    
    // Initialize collection view flow layout
    flowLayout = UICollectionViewFlowLayout()
    flowLayout?.scrollDirection = .Horizontal
    flowLayout?.minimumLineSpacing = 0.0
    
    // Initialize collection view
    collectionView = UICollectionView(frame: CGRectZero, collectionViewLayout: flowLayout!)
    collectionView?.backgroundColor = .clearColor()
    collectionView?.translatesAutoresizingMaskIntoConstraints = false
    addSubview(collectionView!)
    
    // Add constraints
    createConstraints(collectionView!, attributeName: "collectionView", superView: self)
    
    collectionView?.registerNib(UINib(nibName: "LNMediaCollectionViewCell", bundle: nil), forCellWithReuseIdentifier: cellIdentifier)
    collectionView?.delegate = self
    collectionView?.dataSource = self
    collectionView?.bounces = true
    collectionView?.showsVerticalScrollIndicator = false
    collectionView?.showsHorizontalScrollIndicator = false
    collectionView?.pagingEnabled = true
  }
  
  func refresh() {
    // Load datasource
    if let datasource = datasource {
      let numberOfItems = datasource.numberOfItems()
      items = (0..<numberOfItems).flatMap({ datasource.itemAtIndex($0) })
    }
    
    collectionView?.reloadData()
    // Initial start index with 0 if it's nil
    startIndex = startIndex == nil ? 0 : startIndex
    // Scrolling collectionView to a specific index path
    if let startIndex = startIndex where startIndex < items?.count {
      let indexPath = NSIndexPath(forRow: startIndex, inSection: 0)
      collectionView?.scrollToItemAtIndexPath(indexPath, atScrollPosition: .CenteredHorizontally, animated: false)
    }
  }
  /**
   Adjusting frame of all components when will rotating the device to another orientation
   */
  func willRotation() {
    // Animate show/hide collection view by alpha value while reloading its contents
    animateCollectionAlpha(0) |> (collectionView, false)
    flowLayout?.invalidateLayout()
    if let currentOffset = collectionView?.contentOffset {
      currentIndexForRotation = Int(currentOffset.x / (collectionView?.frame.size.width ?? 1))
    }
  }
  
  /**
   Adjust frames when did rotating the device
   */
  func didRotation() {
    if let currentSize = collectionView?.bounds.size {
      let offset = CGFloat(currentIndexForRotation ?? 0) * currentSize.width
      collectionView?.setContentOffset(CGPointMake(offset, 0), animated: false)
      animateCollectionAlpha(0.125) |> (collectionView, true)
    }
  }
  /**
   Animating show/hide collection view by alpha value
   */
  private func animateCollectionAlpha(duration: NSTimeInterval) -> (UIView?, Bool) -> () {
    return { cview, isShow in
      let alpha: CGFloat = isShow ? 1 : 0
      UIView.animateWithDuration(duration, animations: {
        cview?.alpha = alpha
      })
    }
  }
  
  private func createConstraints(view: UIView, attributeName: String, superView: UIView) {
    let views = [attributeName: view]
    let horizontalConstraints = NSLayoutConstraint.constraintsWithVisualFormat("H:|[\(attributeName)]|", options: [], metrics: nil, views: views)
    superView.addConstraints(horizontalConstraints)
    
    let verticalConstraints = NSLayoutConstraint.constraintsWithVisualFormat("V:|[\(attributeName)]|", options: [], metrics: nil, views: views)
    superView.addConstraints(verticalConstraints)
  }
  /**
   Initializing movie player view controller
   */
  private func initialMoviePlayer() -> AVPlayerViewController {
    let videoPlayerVC = AVPlayerViewController()
    if let window = UIApplication.sharedApplication().keyWindow {
      videoPlayerVC.view.frame = window.bounds
    }
    return videoPlayerVC
  }
  /**
   Presenting video player vc and playing video when presenting is done
   */
  private func presentingPlayer(vc: UIViewController, handler: (() -> ())?) {
    self.topViewController.presentViewController(vc, animated: true) { _ in
      handler?()
    }
  }
  /**
   Creating avplayer with initialization url string
   
   - parameter urlStr: url string
   
   - returns: avplayer
   */
  private func player(urlStr: String) -> AVPlayer? {
    let fm = NSFileManager.defaultManager()
    var url: NSURL?
    // for url string is a path of file in local, create url from file url with path
    if fm.fileExistsAtPath(urlStr) {
      url = NSURL(fileURLWithPath: urlStr)
    }
    // for url is a link
    if url == nil {
      url = NSURL(string: urlStr)
    }
    guard let fURL = url else { return nil }
    return AVPlayer(URL: fURL)
  }
  /**
   Initial player viewcontroller that contains the youtube video player
   - returns: UIViewController
   */
  private func initialYoutubePlayerViewController() -> LNYoutubePlayerViewController {
    return LNYoutubePlayerViewController()
  }
  
  /**
   Getting top viewcontroller that is the latest presented vc
   
   - returns: viewcontroller
   */
  private func getTopController() -> UIViewController {
    if let rootVC = UIApplication.sharedApplication().keyWindow?.rootViewController {
      var topViewController = rootVC
      while let presentedVC = topViewController.presentedViewController {
        topViewController = presentedVC
      }
      return topViewController
    }
    return UIViewController()
  }

}

extension LNPhotoBrowser: UICollectionViewDataSource {
  //MARK: UICollectionViewDataSource
  
  func numberOfSectionsInCollectionView(collectionView: UICollectionView) -> Int {
    return 1
  }
  
  func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
    guard let items = self.items else { return 0 }
    return items.count
  }
  
  func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
    let cell: LNMediaCollectionViewCell = collectionView.dequeueReusableCellWithReuseIdentifier(cellIdentifier, forIndexPath: indexPath) as! LNMediaCollectionViewCell
    configureCell(cell, forItemAtIndexPath: indexPath)
    return cell
  }
  
  func configureCell(cell: LNMediaCollectionViewCell, forItemAtIndexPath: NSIndexPath) {
    cell.renderContentToViews(self.items![forItemAtIndexPath.row])
    cell.delegate = self
  }
}

extension LNPhotoBrowser: UICollectionViewDelegate {
  func collectionView(collectionView: UICollectionView, didSelectItemAtIndexPath indexPath: NSIndexPath) {
    let cell: LNMediaCollectionViewCell? = collectionView.cellForItemAtIndexPath(indexPath) as? LNMediaCollectionViewCell
    if let isPhoto = cell?.isPhoto where !isPhoto {
      cell?.didTouchPlayButton()
    }
    delegate?.didSelectAtIndex(indexPath.row)
  }
  
  func collectionView(collectionView: UICollectionView, willDisplayCell cell: UICollectionViewCell, forItemAtIndexPath indexPath: NSIndexPath) {
    // Reassign current cell
    currentIndex = indexPath.row
    // Calling delegate func
    if let delegate = delegate, let item = (cell as? LNMediaCollectionViewCell)?.cellItem {
      delegate.willDisplayItem(item)
    }
  }
  
  func collectionView(collectionView: UICollectionView, didEndDisplayingCell cell: UICollectionViewCell, forItemAtIndexPath indexPath: NSIndexPath) {
    // Reset zoom if needed when the cell did end displaying
    currentCell?.resetZoomIfNeeded()
    // Update current cell to new cell
    currentCell = cell as? LNMediaCollectionViewCell
  }
}

extension LNPhotoBrowser: UICollectionViewDelegateFlowLayout {
  func collectionView(collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAtIndexPath indexPath: NSIndexPath) -> CGSize {
    return self.collectionView?.frame.size ?? CGSizeZero
  }
}

extension LNPhotoBrowser: LNMediaCellDelegate {
  
  func playVideoOfCell(cell: LNMediaCollectionViewCell) {
    // Playing video iff the video url is correct
    if let url = cell.cellItem?.videoURL {
       let playStVideo = playStandardVideo()
      if cell.cellItem!.isLocalFile(url) {
        playStVideo |> url
      } else {
        switch cell.cellItem!.videoType {
        case .Youtube:
          // Playing youtube video
          if let vidId = url.suffix("=") {
            presentingPlayer(youtubePlayerVC) { [weak self] in
              self?.youtubePlayerVC.playVideoWithVideoId(vidId)
            }
          }
        case .Vimeo:
          // TODO: playing a video from Vimeo site
          break
        case .Other, .Stream:
          playStVideo |> url
        }
      }
    }
  }
  
  private func playStandardVideo() -> String -> () {
    return { [weak self] url in
      guard let wSelf = self else { return }
      // Playing video local file
      wSelf.videoPlayerVC.player = wSelf.player(url)
      wSelf.presentingPlayer(wSelf.videoPlayerVC) {
        wSelf.videoPlayerVC.player?.play()
      }
    }
  }
}
