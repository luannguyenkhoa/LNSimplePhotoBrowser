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
fileprivate func < <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l < r
  case (nil, _?):
    return true
  default:
    return false
  }
}


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
  func itemAtIndex(_ index: Int) -> LNMediaFile
  
}

protocol LNPhotoBrowserDelegate: class {
  
  func willDisplayItem(_ item: LNMediaFile)
  func didSelectAtIndex(_ index: Int)
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
  
  fileprivate var items: [LNMediaFile]?
  fileprivate var collectionView: UICollectionView?
  fileprivate var flowLayout: UICollectionViewFlowLayout?
  fileprivate var currentCell: LNMediaCollectionViewCell?
  fileprivate lazy var videoPlayerVC: AVPlayerViewController = self.initialMoviePlayer()
  fileprivate lazy var topViewController: UIViewController = self.getTopController()
  fileprivate lazy var youtubePlayerVC: LNYoutubePlayerViewController = self.initialYoutubePlayerViewController()

  fileprivate var currentIndexForRotation: Int?
  
  override func awakeFromNib() {
    super.awakeFromNib()
  }

  deinit {
    NotificationCenter.default.removeObserver(self)
  }
  
  /**
   Setup collectionview
   */
  func setupCollectionView() {
    
    // Initialize collection view flow layout
    flowLayout = UICollectionViewFlowLayout()
    flowLayout?.scrollDirection = .horizontal
    flowLayout?.minimumLineSpacing = 0.0
    
    // Initialize collection view
    collectionView = UICollectionView(frame: CGRect.zero, collectionViewLayout: flowLayout!)
    collectionView?.backgroundColor = .clear
    collectionView?.translatesAutoresizingMaskIntoConstraints = false
    addSubview(collectionView!)
    
    // Add constraints
    createConstraints(collectionView!, attributeName: "collectionView", superView: self)
    
    collectionView?.register(UINib(nibName: "LNMediaCollectionViewCell", bundle: nil), forCellWithReuseIdentifier: cellIdentifier)
    collectionView?.delegate = self
    collectionView?.dataSource = self
    collectionView?.bounces = true
    collectionView?.showsVerticalScrollIndicator = false
    collectionView?.showsHorizontalScrollIndicator = false
    collectionView?.isPagingEnabled = true
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
    if let startIndex = startIndex , startIndex < items?.count {
      let indexPath = IndexPath(row: startIndex, section: 0)
      collectionView?.scrollToItem(at: indexPath, at: .centeredHorizontally, animated: false)
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
      collectionView?.setContentOffset(CGPoint(x: offset, y: 0), animated: false)
      animateCollectionAlpha(0.125) |> (collectionView, true)
    }
  }
  /**
   Animating show/hide collection view by alpha value
   */
  fileprivate func animateCollectionAlpha(_ duration: TimeInterval) -> (UIView?, Bool) -> () {
    return { cview, isShow in
      let alpha: CGFloat = isShow ? 1 : 0
      UIView.animate(withDuration: duration, animations: {
        cview?.alpha = alpha
      })
    }
  }
  
  fileprivate func createConstraints(_ view: UIView, attributeName: String, superView: UIView) {
    let views = [attributeName: view]
    let horizontalConstraints = NSLayoutConstraint.constraints(withVisualFormat: "H:|[\(attributeName)]|", options: [], metrics: nil, views: views)
    superView.addConstraints(horizontalConstraints)
    
    let verticalConstraints = NSLayoutConstraint.constraints(withVisualFormat: "V:|[\(attributeName)]|", options: [], metrics: nil, views: views)
    superView.addConstraints(verticalConstraints)
  }
  /**
   Initializing movie player view controller
   */
  fileprivate func initialMoviePlayer() -> AVPlayerViewController {
    let videoPlayerVC = AVPlayerViewController()
    if let window = UIApplication.shared.keyWindow {
      videoPlayerVC.view.frame = window.bounds
    }
    return videoPlayerVC
  }
  /**
   Presenting video player vc and playing video when presenting is done
   */
  fileprivate func presentingPlayer(_ vc: UIViewController, handler: (() -> ())?) {
    self.topViewController.present(vc, animated: true) { _ in
      handler?()
    }
  }
  /**
   Creating avplayer with initialization url string
   
   - parameter urlStr: url string
   
   - returns: avplayer
   */
  fileprivate func player(_ urlStr: String) -> AVPlayer? {
    let fm = FileManager.default
    var url: URL?
    // for url string is a path of file in local, create url from file url with path
    if fm.fileExists(atPath: urlStr) {
      url = URL(fileURLWithPath: urlStr)
    }
    // for url is a link
    if url == nil {
      url = URL(string: urlStr)
    }
    guard let fURL = url else { return nil }
    return AVPlayer(url: fURL)
  }
  /**
   Initial player viewcontroller that contains the youtube video player
   - returns: UIViewController
   */
  fileprivate func initialYoutubePlayerViewController() -> LNYoutubePlayerViewController {
    return LNYoutubePlayerViewController()
  }
  
  /**
   Getting top viewcontroller that is the latest presented vc
   
   - returns: viewcontroller
   */
  fileprivate func getTopController() -> UIViewController {
    if let rootVC = UIApplication.shared.keyWindow?.rootViewController {
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
  
  func numberOfSections(in collectionView: UICollectionView) -> Int {
    return 1
  }
  
  func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
    guard let items = self.items else { return 0 }
    return items.count
  }
  
  func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
    let cell: LNMediaCollectionViewCell = collectionView.dequeueReusableCell(withReuseIdentifier: cellIdentifier, for: indexPath) as! LNMediaCollectionViewCell
    configureCell(cell, forItemAtIndexPath: indexPath)
    return cell
  }
  
  func configureCell(_ cell: LNMediaCollectionViewCell, forItemAtIndexPath: IndexPath) {
    cell.renderContentToViews(self.items![(forItemAtIndexPath as NSIndexPath).row])
    cell.delegate = self
  }
}

extension LNPhotoBrowser: UICollectionViewDelegate {
  func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
    let cell: LNMediaCollectionViewCell? = collectionView.cellForItem(at: indexPath) as? LNMediaCollectionViewCell
    if let isPhoto = cell?.isPhoto , !isPhoto {
      cell?.didTouchPlayButton()
    }
    delegate?.didSelectAtIndex((indexPath as NSIndexPath).row)
  }
  
  func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
    // Reassign current cell
    currentIndex = (indexPath as NSIndexPath).row
    // Calling delegate func
    if let delegate = delegate, let item = (cell as? LNMediaCollectionViewCell)?.cellItem {
      delegate.willDisplayItem(item)
    }
  }
  
  func collectionView(_ collectionView: UICollectionView, didEndDisplaying cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
    // Reset zoom if needed when the cell did end displaying
    currentCell?.resetZoomIfNeeded()
    // Update current cell to new cell
    currentCell = cell as? LNMediaCollectionViewCell
  }
}

extension LNPhotoBrowser: UICollectionViewDelegateFlowLayout {
  func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
    return self.collectionView?.frame.size ?? CGSize.zero
  }
}

extension LNPhotoBrowser: LNMediaCellDelegate {
  
  func playVideoOfCell(_ cell: LNMediaCollectionViewCell) {
    // Playing video iff the video url is correct
    if let url = cell.cellItem?.videoURL {
       let playStVideo = playStandardVideo()
      if cell.cellItem!.isLocalFile(url) {
        playStVideo |> url
      } else {
        switch cell.cellItem!.videoType {
        case .youtube:
          // Playing youtube video
          if let vidId = url.suffix("=") {
            presentingPlayer(youtubePlayerVC) { [weak self] in
              self?.youtubePlayerVC.playVideoWithVideoId(vidId)
            }
          }
        case .vimeo:
          // TODO: playing a video from Vimeo site
          break
        case .other, .stream:
          playStVideo |> url
        }
      }
    }
  }
  
  fileprivate func playStandardVideo() -> (String) -> () {
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
