//
//  LNMediaCollectionViewCell.swift
//  LNSimplePhotoBrowser
//
//  Created by Luan Nguyen on 7/24/16.
//  Copyright © 2016 Luan Nguyen. All rights reserved.
//

import UIKit

// Delegate handlers
protocol LNMediaCellDelegate: class {
  
  func playVideoOfCell(_ cell: LNMediaCollectionViewCell)
  
}

// Grouping all actions selector
enum Actions {
  
  static let doubleTapHandler: Selector = #selector(LNMediaCollectionViewCell.doubleTapHandler(_:))
  static let pinchHandler: Selector = #selector(LNMediaCollectionViewCell.pichHandler(_:))
  static let buttonTapped: Selector = #selector(LNMediaCollectionViewCell.didTouchPlayButton)
}


internal final class LNMediaCollectionViewCell: UICollectionViewCell {
  
  // MARK: Outlets
  @IBOutlet fileprivate weak var mainScrollView: UIScrollView!
  @IBOutlet weak var contentImageView: UIImageView!
  @IBOutlet fileprivate weak var playVideoButton: UIButton!
  
  // MARK: Properties
  weak var delegate: LNMediaCellDelegate?
  var cellItem: LNMediaFile?
  var isPhoto: Bool = false
  fileprivate var doubleTap: UITapGestureRecognizer?
  fileprivate var pinchGesture: UIPinchGestureRecognizer?
  
  // MARK: Constants
  fileprivate let MAXIMUM_SCALE: CGFloat = 4.0
  fileprivate let MINIMUM_SCALE: CGFloat = 1
  
  override func awakeFromNib() {
    super.awakeFromNib()
    // Initialization code
    mainScrollView.maximumZoomScale = MAXIMUM_SCALE
    mainScrollView.minimumZoomScale = MINIMUM_SCALE
    
    // Initialize gestures
    doubleTap = UITapGestureRecognizer(target: self, action: Actions.doubleTapHandler)
    doubleTap?.numberOfTapsRequired = 2
    
    pinchGesture = UIPinchGestureRecognizer(target: self, action: Actions.pinchHandler)
    
    // Add button action target
    playVideoButton.addTarget(self, action: Actions.buttonTapped, for: .touchUpInside)
  }
  
  override func prepareForReuse() {
    self.contentImageView.center = self.mainScrollView.center
    // Remove all gesture recognizers if exists
    if let gestures = self.gestureRecognizers , gestures.count > 0 {
      gestures.forEach({ removeGestureRecognizer($0) })
    }
    mainScrollView.delegate = nil
    // Cancel set image if needed
    contentImageView.hnk_cancelSetImage()
    // Reset imageview content
    contentImageView.image = nil
    super.prepareForReuse()
  }
  
  // MARK: Setup
  /**
   Passing a media file object that will be rendered to views
   
   - parameter item: media file object that includes image or video
   */
  func renderContentToViews(_ item: LNMediaFile) {
    // Save cell's item
    cellItem = item
    // Hide play button if there is a photo item
    isPhoto = item.videoURL == nil
    playVideoButton.isHidden = isPhoto
    
    if isPhoto {
      // Render photo data
      mainScrollView.addGestureRecognizer(doubleTap!)
      mainScrollView.delegate = self
    }
    LNMediaProcessing.singleton.loadImage(item) { [weak self] img in
      self?.contentImageView.image = img
    }
  }
  
  // MARK: Handlers
  /**
   Check if the current image was zoomed, reset to identify for transform and zoom to default if needed
   */
  func resetZoomIfNeeded() {
    // Reset transform and zoom scale to default if needed
    contentImageView.transform = CGAffineTransform.identity
    mainScrollView.setZoomScale(1, animated: true)
  }
  /**
   Handling did touch play button action
   */
  func didTouchPlayButton() {
    // Do nothing if the delegate is nil
    guard let delegate = delegate else { return }
    // Calling delegate function
    delegate.playVideoOfCell(self)
  }
  /**
   Handling double tap on image to zooming it
   
   - parameter gesture: sender tap gesture
   */
  func doubleTapHandler(_ gesture: UITapGestureRecognizer) {
    var newScale: CGFloat = 1
    // Assigning new scale value if it's an identify value right now
    if self.mainScrollView.zoomScale == 1 {
      newScale = mainScrollView.zoomScale * MAXIMUM_SCALE
    }
    // Getting center point of gesture owner view
    var center = gesture.location(in: gesture.view)
    // Getting zoom rect value for determined scale value and center point
    let zoomRect = zoomToRectForScale(newScale, center: &center)
    // Zooming container scrollview to zoom rect value above
    mainScrollView.zoom(to: zoomRect, animated: true)
  }
  
  func pichHandler(_ gesture: UIPinchGestureRecognizer) {
    if [.ended, .changed].contains(gesture.state) {
      // Getting current scale value of self
      let currentScale: CGFloat = self.frame.size.width / self.bounds.size.width
      // Calculating a new scale value from current scale and gesture scale
      var newScale: CGFloat = currentScale * gesture.scale
      
      // Re-assigning new scale value to min/max if it's out of range
      newScale = newScale < MINIMUM_SCALE ? MINIMUM_SCALE : newScale
      newScale = newScale > MAXIMUM_SCALE ? MAXIMUM_SCALE : newScale
      
      // Initializing a transform object and transform self with this
      let transform = CGAffineTransform(scaleX: newScale, y: newScale)
      self.transform = transform
      // Reset gesture scale value
      gesture.scale = 1
    }
  }
  /**
   Passing 2 params are scale and center point to determining zoom rect value
   
   - parameter scale:  a new scale value that is used to determining content scaling
   - parameter center: center of gesture view
   
   - returns: rect that will be destination rect of content image view
   */
  fileprivate func zoomToRectForScale(_ scale: CGFloat,center: inout CGPoint) -> CGRect {
    // Initialize zoom rect object with zero
    var zoomRect: CGRect = CGRect.zero
    // Getting zoomRect size from division between imgView's size and scale param
    zoomRect.size.height = contentImageView.frame.height / scale
    zoomRect.size.width = contentImageView.frame.width / scale
    
    // Converting center point of gesture view
    center = contentImageView.convert(center, from: self)
    
    // Getting zoomRect origin
    zoomRect.origin.x = center.x - (zoomRect.size.width / 2.0)
    zoomRect.origin.y = center.y - (zoomRect.size.height / 2.0)
    
    return zoomRect
  }
}

extension LNMediaCollectionViewCell: UIScrollViewDelegate {
  // Determining view for zooming
  func viewForZooming(in scrollView: UIScrollView) -> UIView? {
    return isPhoto ? contentImageView : nil
  }
  
}
