//
//  ViewController.swift
//  castLabs
//
//  Created by Taewoo Kim on 08.02.22.
//

import UIKit
import AVFoundation
import MediaPlayer

enum PickerViewType: Int {
    case audio
    case subtitle
}

class ViewController: UIViewController {
    @IBOutlet weak var timeLabel: UILabel!
    @IBOutlet weak var slider: UISlider!
    @IBOutlet weak var playButton: UIButton!
    @IBOutlet weak var audioButton: UIButton!
    @IBOutlet weak var subtitleButton: UIButton!
    @IBOutlet weak var pickerView: UIPickerView!
    @IBOutlet weak var playerView: AVPlayerView!    
    var avPlayer: AVPlayer? = nil
    var playerItemContext: UnsafeMutableRawPointer? = nil
    var isDragging = false
    var pickerItems: [AVMediaSelectionOption] = [];
    
    override func viewDidLoad() {
        super.viewDidLoad()
        disableControls()
        slider.addTarget(self, action: #selector(sliderValueChanged(slider:event:)), for: .valueChanged)
        prepareToPlay()
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
        if false == pickerView.isHidden,
           .audio == PickerViewType(rawValue: pickerView.tag) {
            pickerView.isHidden = true
            return
        }
        displayPickerView(ofType: .audio)
    }
    
    @IBAction func subtitleButton(sender: UIButton) {
        if false == pickerView.isHidden,
           .subtitle == PickerViewType(rawValue: pickerView.tag) {
            pickerView.isHidden = true
            return
        }
        displayPickerView(ofType: .subtitle)
    }
}

// MARK:- Play
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
                initSlider()
            case .failed, .unknown:
                fallthrough
            @unknown default:
                disableControls()
            }
        }
    }
}
    
// MARK:- UI controls
extension ViewController {
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
        if !isDragging {
            slider.value = Float(sec)
        }
    }
    
    func initSlider() {
        slider.value = 0.0
        slider.maximumValue = Float(CMTimeGetSeconds(avPlayer?.currentItem?.duration ?? CMTime(seconds: 0, preferredTimescale: 1)))
    }
    
    @objc func sliderValueChanged(slider: UISlider, event: UIEvent) {
        if let touchEvent = event.allTouches?.first {
            switch touchEvent.phase {
            case .began:
                isDragging = true
            case .moved:
                return
            case .ended:
                seekVideo() { [weak self] in
                    self?.isDragging = false
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
        avPlayer.seek(to: targetTime, completionHandler: { _ in
            completion()
        })
    }
    
    func displayPickerView(ofType type: PickerViewType) {
        switch type {
        case .audio:
            if let asset = avPlayer?.currentItem?.asset,
               let group = asset.mediaSelectionGroup(forMediaCharacteristic: AVMediaCharacteristic.audible) {
                pickerItems = group.options
                pickerView.reloadAllComponents()
                pickerView.tag = type.rawValue
                pickerView.isHidden = false
            }
        case .subtitle:
            if let asset = avPlayer?.currentItem?.asset,
               let group = asset.mediaSelectionGroup(forMediaCharacteristic: AVMediaCharacteristic.legible) {
                pickerItems = group.options
                pickerView.reloadAllComponents()
                pickerView.tag = type.rawValue
                pickerView.isHidden = false
            }
        }
    }
}

// MARK:- UIPickerViewDataSource
extension ViewController: UIPickerViewDataSource {
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return pickerItems.count
    }
}

// MARK:- UIPickerViewDelegate
extension ViewController: UIPickerViewDelegate {
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return pickerItems[row].displayName
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        pickerView.isHidden = true
        guard let currentItem = avPlayer?.currentItem else {
            return
        }
        
        switch PickerViewType(rawValue: pickerView.tag) {
        case .audio:
            guard let group = currentItem.asset.mediaSelectionGroup(forMediaCharacteristic: AVMediaCharacteristic.audible) else {
                return
            }
            let option = pickerItems[row]
            currentItem.select(option, in: group)
        case .subtitle:
            guard let group = currentItem.asset.mediaSelectionGroup(forMediaCharacteristic: AVMediaCharacteristic.legible) else {
                return
            }
            let option = pickerItems[row]
            currentItem.select(option, in: group)
        case .none:
            break
        }
    }
}
