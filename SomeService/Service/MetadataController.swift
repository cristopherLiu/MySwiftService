//
//  MetadataController.swift
//  SomeService
//
//  Created by 劉紘任 on 2020/6/8.
//  Copyright © 2020 劉紘任. All rights reserved.
//

import AVFoundation
import UIKit

public protocol MetadataCaptureDelegate: class {
  func qrcodeCapture(value: String)
  func code128Capture(value: String)
  func code39Capture(value: String)
  func captureError(error: Error)
}

public class MetadataController: NSObject {
  
  public var captureSession: AVCaptureSession?
  
  // 裝置
  var frontCamera: AVCaptureDevice?
  var rearCamera: AVCaptureDevice?
  
  // 輸入 用來擷取
  var frontCameraInput: AVCaptureDeviceInput?
  var rearCameraInput: AVCaptureDeviceInput?
  
  // 輸出
  var metadataOutput: AVCaptureMetadataOutput?
  
  // 預覽畫面
  public var previewLayer: AVCaptureVideoPreviewLayer?
  
  public weak var delegate: MetadataCaptureDelegate?
  
  var currentCameraPosition: CameraPosition?
  
  //  var metadataCaptureCompletionBlock: ((String?, Error?) -> Void)?
  
  func checkCameraAccess() {
    switch AVCaptureDevice.authorizationStatus(for: .video) {
      case .denied:
        print("拒絕授權相機, request permission from settings")
      case .restricted:
        print("相機受限制, device owner must approve")
      case .authorized:
        print("授權相機")
      case .notDetermined:
        AVCaptureDevice.requestAccess(for: .video) { success in
          if success {
            print("Permission granted, proceed")
          } else {
            print("Permission denied")
          }
        }
      default: break
    }
  }
}

public extension MetadataController {
  
  func prepare(completionHandler: @escaping (Error?) -> Void) {
    
    func createCaptureSession() {
      self.captureSession = AVCaptureSession()
    }
    
    // 設定裝置
    func configureCaptureDevices() throws {
      
      // 找出裝置上所有可用的內置相機
      let session = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: AVMediaType.video, position: .unspecified)
      let cameras = session.devices.compactMap { $0 }
      guard !cameras.isEmpty else { throw ControllerError.noCamerasAvailable }
      
      for camera in cameras {
        
        // 前鏡頭
        if camera.position == .front {
          self.frontCamera = camera
        }
        
        // 後鏡頭
        if camera.position == .back {
          self.rearCamera = camera
          
          try camera.lockForConfiguration()
          camera.isSubjectAreaChangeMonitoringEnabled = true
          camera.focusMode = AVCaptureDevice.FocusMode.continuousAutoFocus
          camera.exposureMode = AVCaptureDevice.ExposureMode.continuousAutoExposure
          camera.unlockForConfiguration()
        }
      }
    }
    
    // 設定輸入
    func configureDeviceInputs() throws {
      guard let captureSession = self.captureSession else { throw ControllerError.captureSessionIsMissing }
      
      if let rearCamera = self.rearCamera {
        self.rearCameraInput = try AVCaptureDeviceInput(device: rearCamera)
        
        if captureSession.canAddInput(self.rearCameraInput!) { captureSession.addInput(self.rearCameraInput!) }
        
        self.currentCameraPosition = .rear
      }
      else if let frontCamera = self.frontCamera {
        self.frontCameraInput = try AVCaptureDeviceInput(device: frontCamera)
        
        if captureSession.canAddInput(self.frontCameraInput!) { captureSession.addInput(self.frontCameraInput!) }
          
        else { throw ControllerError.inputsAreInvalid }
        
        self.currentCameraPosition = .front
      }
      else { throw ControllerError.noCamerasAvailable }
      
      // 預設後鏡頭
//      guard let rearCamera = self.rearCamera else { throw ControllerError.noCamerasAvailable }
//
//      self.rearCameraInput = try AVCaptureDeviceInput(device: rearCamera)
//
//      if captureSession.canAddInput(self.rearCameraInput!) { captureSession.addInput(self.rearCameraInput!) }
//      self.currentCameraPosition = .rear
    }
    
    // 設定輸出 掃描Qrcode
    func configureMetadataOutput() throws {
      guard let captureSession = self.captureSession else { throw ControllerError.captureSessionIsMissing }
      
      self.metadataOutput = AVCaptureMetadataOutput()
      
      // 必須先將metadataOutput 加入到session,才能設置metadataObjectTypes,注意順序,不然會crash
      if captureSession.canAddOutput(self.metadataOutput!) { captureSession.addOutput(self.metadataOutput!) }
      
      self.metadataOutput?.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
      self.metadataOutput?.metadataObjectTypes = [ .qr, .code128, .code39 ]
//            self.metadataOutput?.metadataObjectTypes = self.metadataOutput?.availableMetadataObjectTypes
      
      captureSession.startRunning()
    }
    
    func configurePreview() throws {
      guard let captureSession = self.captureSession, captureSession.isRunning else { throw ControllerError.captureSessionIsMissing }
      
      self.previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
      self.previewLayer?.videoGravity = AVLayerVideoGravity.resizeAspectFill
      self.previewLayer?.connection?.videoOrientation = .portrait
    }
    
    DispatchQueue(label: "taipei.gov.myCode.prepare", qos: DispatchQoS.userInteractive).async {
      do {
        createCaptureSession()
        try configureCaptureDevices()
        try configureDeviceInputs()
        try configureMetadataOutput()
        try configurePreview()
      }
        
      catch {
        DispatchQueue.main.async {
          completionHandler(error)
        }
        return
      }
      DispatchQueue.main.async {
        completionHandler(nil)
      }
    }
  }
}

public extension MetadataController {
  
  // 切換相機
  func switchCameras() throws {
    
    guard let currentCameraPosition = currentCameraPosition, let captureSession = self.captureSession, captureSession.isRunning
      else { throw ControllerError.captureSessionIsMissing }
    
    captureSession.beginConfiguration()
    
    switch currentCameraPosition {
    case .front:
      try switchToRearCamera()
      
    case .rear:
      try switchToFrontCamera()
    }
    
    captureSession.commitConfiguration()
  }
  
  private func switchToFrontCamera() throws {
    
    guard let captureSession = self.captureSession, captureSession.isRunning
      else { throw ControllerError.captureSessionIsMissing }
    
    guard let rearCameraInput = self.rearCameraInput, captureSession.inputs.contains(rearCameraInput), let frontCamera = self.frontCamera
      else { throw ControllerError.invalidOperation }
    
    self.frontCameraInput = try AVCaptureDeviceInput(device: frontCamera)
    
    captureSession.removeInput(rearCameraInput)
    
    if captureSession.canAddInput(self.frontCameraInput!) {
      captureSession.addInput(self.frontCameraInput!)
      
      self.currentCameraPosition = .front
    }
    else {
      throw ControllerError.invalidOperation
    }
  }
  
  private func switchToRearCamera() throws {
    
    guard let captureSession = self.captureSession, captureSession.isRunning
      else { throw ControllerError.captureSessionIsMissing }
    
    guard let frontCameraInput = self.frontCameraInput, captureSession.inputs.contains(frontCameraInput), let rearCamera = self.rearCamera
      else { throw ControllerError.invalidOperation }
    
    self.rearCameraInput = try AVCaptureDeviceInput(device: rearCamera)
    
    captureSession.removeInput(frontCameraInput)
    
    if captureSession.canAddInput(self.rearCameraInput!) {
      captureSession.addInput(self.rearCameraInput!)
      
      self.currentCameraPosition = .rear
    }
    else { throw ControllerError.invalidOperation }
  }
}

/**
 掃描
 */
extension MetadataController: AVCaptureMetadataOutputObjectsDelegate {
  
  func startScan() {
    if let session = self.captureSession, session.isRunning == false {
      session.startRunning()
    }
  }
  
  func stopScan() {
    if let session = self.captureSession, session.isRunning == true {
      session.stopRunning()
    }
  }
  
  public func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
    
    // 如果 metadataObjects 是空陣列
    if metadataObjects.isEmpty {
      print("Qrcode空資訊")
      return
    }
    
    // 如果能夠取得 metadataObjects 並且能夠轉換成 AVMetadataMachineReadableCodeObject（條碼訊息）
    if let metadataObj = metadataObjects[0] as? AVMetadataMachineReadableCodeObject {
      
      if let value = metadataObj.stringValue {
        
        self.stopScan() // 停止掃描
//        print("種類:\(metadataObj.type.rawValue), value:\(value)")
        
        //        // 如果 metadata 與 QR code metadata 相同，則更新搜尋框的 frame
        //        let barCodeObject = videoPreviewLayer?.transformedMetadataObject(for: metadataObj)
        //        qrCodeFrameView?.frame = barCodeObject!.bounds
        
        //掃到後的震動提示
        AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
        
        // 判斷 metadataObj 的類型是否為 QR Code
        if metadataObj.type == AVMetadataObject.ObjectType.qr {
          self.delegate?.qrcodeCapture(value: value)
        }
        
        // 身分證
        if metadataObj.type == AVMetadataObject.ObjectType.code128 {
          self.delegate?.code128Capture(value: value)
        }
        
        // 居留證
        if metadataObj.type == AVMetadataObject.ObjectType.code39 {
          self.delegate?.code39Capture(value: value)
        }
      }
    }
  }
}

public extension MetadataController {
  
  enum ControllerError: Swift.Error {
    case captureSessionAlreadyRunning
    case captureSessionIsMissing
    case inputsAreInvalid
    case invalidOperation
    case noCamerasAvailable
    case unknown
  }
  
  enum CameraPosition {
    case front
    case rear
  }
}
