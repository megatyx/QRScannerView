//
//  QRScannerView.swift
//  Created by Tyler Wells
//

import Foundation
import UIKit
import AVFoundation

enum QRCodeScannerError: Error {
    case invalidQRCode, videoInputFailed, metadataOutputFailed, nilCaptureSession
    case closureNotSet
}

class QRScannerView: UIView {
    
    // MARK:- Closure delegates
    var onScanFailure: ((QRCodeScannerError)->Void)? = nil
    var scanningDidSucceedWithCode: ((String) -> Void)? = nil
    var scanningDidStop: (()->Void)? = nil
    
    // MARK:- Capture Session
    var captureSession: AVCaptureSession?
    
    var isRunning: Bool {
        return captureSession?.isRunning ?? false
    }
    
    // MARK:- INITS
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setup()
    }
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    // MARK:- Overrides
    override class var layerClass: AnyClass  {
        return AVCaptureVideoPreviewLayer.self
    }
    override var layer: AVCaptureVideoPreviewLayer {
        return super.layer as! AVCaptureVideoPreviewLayer
    }
    
    // MARK:- Setup
    private func setup() {
        clipsToBounds = true
        
        //Get our capture session Ready
        captureSession = AVCaptureSession()
        
        //Get preferred video capture hardware
        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else { return }
        //Init the video input class
        let videoInput: AVCaptureDeviceInput
        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
        } catch {
            print(error.localizedDescription)
            scanningDidFail(.videoInputFailed)
            return
        }
        
        //Make sure the capture session's init succeeded
        guard let captureSession = captureSession else {
            scanningDidFail(.nilCaptureSession)
            return
        }
        
        if (captureSession.canAddInput(videoInput)) {
            captureSession.addInput(videoInput)
        } else {
            scanningDidFail(QRCodeScannerError.videoInputFailed)
            return
        }
        
        //Set up metadata capture
        let metadataOutput = AVCaptureMetadataOutput()
        
        guard captureSession.canAddOutput(metadataOutput) else {
            scanningDidFail(QRCodeScannerError.metadataOutputFailed)
            return
        }
        
        captureSession.addOutput(metadataOutput)
        
        metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
        metadataOutput.metadataObjectTypes = [.qr, .ean8, .ean13, .pdf417, .code128]
        
        self.layer.session = captureSession
        self.layer.videoGravity = .resizeAspectFill
        
        captureSession.startRunning()
    }
    
    //MARK:- Start and Stop Scanning
    func startScanning() {
        captureSession?.startRunning()
    }
    
    func stopScanning() {
        captureSession?.stopRunning()
        self.scanningDidStop?()
    }
    
    //MARK:- Failure Function
    func scanningDidFail(_ error: QRCodeScannerError) {
        self.onScanFailure?(error)
        captureSession = nil
    }
    
    //MARK:- Success Function
    func didFindCode(code: String) {
        if scanningDidSucceedWithCode == nil {
            print("Please set the 'scanningDidSucceed' closure, because if you don't, it will never work here, my dude")
            scanningDidFail(.closureNotSet)
        }
        self.scanningDidSucceedWithCode?(code)
    }
    
    //Make sure we account for rotation
    func updateOrientation(orientation: UIDeviceOrientation) {
        switch orientation {
        case .portrait:
            self.layer.connection?.videoOrientation = AVCaptureVideoOrientation.portrait
        case .landscapeLeft:
            self.layer.connection?.videoOrientation = AVCaptureVideoOrientation.landscapeRight
        case .landscapeRight:
            self.layer.connection?.videoOrientation = AVCaptureVideoOrientation.landscapeLeft
        default:
            break
        }
    }
}

extension QRScannerView: AVCaptureMetadataOutputObjectsDelegate {
    func metadataOutput(_ output: AVCaptureMetadataOutput,
                        didOutput metadataObjects: [AVMetadataObject],
                        from connection: AVCaptureConnection) {
        stopScanning()
        if let metadataObject = metadataObjects.first {
            guard let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject,
            let stringValue = readableObject.stringValue else {
                scanningDidFail(QRCodeScannerError.invalidQRCode)
                return
            }
            AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
            didFindCode(code: stringValue)
        }
    }
}
