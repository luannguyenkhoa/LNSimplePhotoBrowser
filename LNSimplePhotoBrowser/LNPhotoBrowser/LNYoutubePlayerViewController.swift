//
//  LNYoutubePlayerViewController.swift
//  LNSimplePhotoBrowser
//
//  Created by Luan Nguyen on 8/12/16.
//  Copyright © 2016 Luan Nguyen. All rights reserved.
//

import UIKit
import youtube_ios_player_helper

class LNYoutubePlayerViewController: UIViewController {
  
  // MARK: Outlets
  @IBOutlet weak var titleLabel: UILabel!
  @IBOutlet weak var ytbPlayerView: YTPlayerView!
  
  override func loadView() {
    NSBundle.mainBundle().loadNibNamed("LNYoutubePlayerViewController", owner: self, options: nil)
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    // Do any additional setup after loading the view.
  }
  
  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    // Dispose of any resources that can be recreated.
  }
  
  @IBAction func didTouchCloseButton() {
    ytbPlayerView.stopVideo()
    dismissViewControllerAnimated(true, completion: nil)
  }
  
  func playVideoWithVideoId(vidId: String) {
    ytbPlayerView.loadWithVideoId(vidId)
  }
}
