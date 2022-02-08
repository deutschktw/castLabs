//
//  ViewController.swift
//  castLabs
//
//  Created by Taewoo Kim on 08.02.22.
//

import UIKit
import AVFoundation

class ViewController: UIViewController {
    @IBOutlet weak var timeLabel: UILabel!
    @IBOutlet weak var slider: UISlider!
    @IBOutlet weak var playButton: UIButton!
    @IBOutlet weak var audioButton: UIButton!
    @IBOutlet weak var subtitleButton: UIButton!
    @IBOutlet weak var playerView: AVPlayerView!
    var avPlayer: AVPlayer? = nil
    var playerItemContext: UnsafeMutableRawPointer? = nil
    var dragging = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        disableControls()
        prepareToPlay()        
        slider.addTarget(self, action: #selector(sliderValueChanged(slider:event:)), for: .valueChanged)
    }
    
    @IBAction func playButton(sender: UIButton) {
        if sender.isSelected {
            sender.isSelected = false
            avPlayer?.pause()
        }
        else {
            sender.isSelected = true
            avPlayer?.play()
        }
    }
    
    @IBAction func audioButton(sender: UIButton) {
        
    }
    
    @IBAction func subtitleButton(sender: UIButton) {
        
    }
    

}

extension ViewController {
    func prepareToPlay() {
        let asset = AVAsset(url: Contents.video)
        let assetKeys = [
            "playable",
            "hasProtectedContent"
        ]
        let playerItem = AVPlayerItem(asset: asset, automaticallyLoadedAssetKeys: assetKeys)
        playerItem.addObserver(self,
                               forKeyPath: #keyPath(AVPlayerItem.status),
                               options: [.old, .new],
                               context: &playerItemContext)
        
        let player = AVPlayer(playerItem: playerItem)
        if let playLayer = playerView.layer as? AVPlayerLayer {
            playLayer.player = player
        }
        
        player.addPeriodicTimeObserver(forInterval: CMTimeMakeWithSeconds(1, preferredTimescale: 1), queue: DispatchQueue.main, using: { [weak self] time in
            self?.updateProgressTime(time)
        })
        
        self.avPlayer = player
    }
    
    override func observeValue(forKeyPath keyPath: String?,
                               of object: Any?,
                               change: [NSKeyValueChangeKey : Any]?,
                               context: UnsafeMutableRawPointer?) {
        // Only handle observations for the playerItemContext
        guard context == &playerItemContext else {
            super.observeValue(forKeyPath: keyPath,
                               of: object,
                               change: change,
                               context: context)
            return
        }
        
        if keyPath == #keyPath(AVPlayerItem.status) {
            let status: AVPlayerItem.Status
            if let statusNumber = change?[.newKey] as? NSNumber {
                status = AVPlayerItem.Status(rawValue: statusNumber.intValue)!
            } else {
                status = .unknown
            }
            
            switch status {
            case .readyToPlay:
                enableControls()
                slider.maximumValue = Float(CMTimeGetSeconds(avPlayer?.currentItem?.duration ?? CMTime(seconds: 0, preferredTimescale: 1)))
            case .failed, .unknown:
                fallthrough
            @unknown default:
                disableControls()
            }
        }
    }
    
    func enableControls() {
        slider.isEnabled = true
        playButton.isEnabled = true
        audioButton.isEnabled = true
        subtitleButton.isEnabled = true
    }
    
    func disableControls() {
        slider.isEnabled = false
        playButton.isEnabled = false
        audioButton.isEnabled = false
        subtitleButton.isEnabled = false
    }
    
    func updateProgressTime(_ time: CMTime) {
        let sec = CMTimeGetSeconds(time)
        timeLabel.text = NSString(format: "%02d:%02d", Int(sec) / 60, Int(sec) % 60) as String
        if !dragging {
            slider.value = Float(sec)
        }
    }
    
    @objc func sliderValueChanged(slider: UISlider, event: UIEvent) {
        if let touchEvent = event.allTouches?.first {
            switch touchEvent.phase {
            case .began:
                dragging = true
            case .moved:
                return
            case .ended:
                seekVideo() { [weak self] in
                    self?.dragging = false
                }
            default:
                break
            }
        }
    }
    
    func seekVideo(_ completion: @escaping ()->Void) {
        guard let avPlayer = avPlayer else { return }
        let seconds = Int64(self.slider.value)
        let targetTime: CMTime = CMTimeMake(value: seconds, timescale: 1)
        avPlayer.pause()
        avPlayer.seek(to: targetTime, completionHandler: { [weak self] result in
            guard let avPlayer = self?.avPlayer else { return }
            avPlayer.play()
            completion()
        })
    }
}
