//
//  CameraController.swift
//  SomeService
//
//  Created by 劉紘任 on 2020/6/8.
//  Copyright © 2020 劉紘任. All rights reserved.
//

import AVFoundation
import UIKit

public protocol CameraCaptureDelegate: class {
  func photoCapture(image: UIImage)
  func captureError(error: Error)
}

public class CameraController: NSObject {
  
  var captureSession: AVCaptureSession?
  var currentCameraPosition: CameraPosition?
  
  // 裝置
  var frontCamera: AVCaptureDevice?
  var rearCamera: AVCaptureDevice?
  
  // 輸入 用來相片擷取
  var frontCameraInput: AVCaptureDeviceInput?
  var rearCameraInput: AVCaptureDeviceInput?
  
  // 輸出
  var photoOutput: AVCapturePhotoOutput?
  var metadataOutput: AVCaptureMetadataOutput?
  
  // 預覽畫面
  var previewLayer: AVCaptureVideoPreviewLayer?
  
  var flashMode = AVCaptureDevice.FlashMode.off // 閃光燈
  
  weak var delegate: CameraCaptureDelegate?
  
  //  var photoCaptureCompletionBlock: ((UIImage?, Error?) -> Void)?
}

public extension CameraController {
  
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
          camera.focusMode = .continuousAutoFocus
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
    }
    
    // 設定輸出 拍照
    func configurePhotoOutput() throws {
      guard let captureSession = self.captureSession else { throw ControllerError.captureSessionIsMissing }
      
      self.photoOutput = AVCapturePhotoOutput()
      self.photoOutput!.setPreparedPhotoSettingsArray([AVCapturePhotoSettings(format: [AVVideoCodecKey : AVVideoCodecType.jpeg])], completionHandler: nil)
      
      if captureSession.canAddOutput(self.photoOutput!) { captureSession.addOutput(self.photoOutput!) }
      captureSession.startRunning()
    }
    
    DispatchQueue(label: "prepare").async {
      do {
        createCaptureSession()
        try configureCaptureDevices()
        try configureDeviceInputs()
        try configurePhotoOutput()
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

public extension CameraController {
  
  func displayPreview() throws -> AVCaptureVideoPreviewLayer? {
    
    guard let captureSession = self.captureSession, captureSession.isRunning else { throw ControllerError.captureSessionIsMissing }
    
    self.previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
    self.previewLayer?.videoGravity = AVLayerVideoGravity.resizeAspectFill
    self.previewLayer?.connection?.videoOrientation = .portrait
    
    return self.previewLayer
  }
}

/**
 拍照
 */
extension CameraController: AVCapturePhotoCaptureDelegate {
  
  // 拍照
  func captureImage() {
    
    guard let captureSession = captureSession, captureSession.isRunning else {
      self.delegate?.captureError(error: ControllerError.captureSessionIsMissing)
      return
    }
    
    self.photoOutput?.capturePhoto(with: AVCapturePhotoSettings(), delegate: self)
  }
  
  public func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
    
    if let error = error {
      self.delegate?.captureError(error: error)
    } else if let imageData = photo.fileDataRepresentation(), let image = UIImage(data: imageData) {
      self.delegate?.photoCapture(image: image)
    } else {
      self.delegate?.captureError(error: ControllerError.unknown)
    }
  }
  
  // 切換閃光燈
  func switchFlash() throws {
      
    guard let currentCameraPosition = currentCameraPosition, let captureSession = self.captureSession, captureSession.isRunning, let rearCamera = rearCamera
    else { throw ControllerError.captureSessionIsMissing }
    
    if (currentCameraPosition == .rear && rearCamera.hasTorch) {
      do {
        try rearCamera.lockForConfiguration()
      } catch {
        
      }
      
      if rearCamera.isTorchActive {
        rearCamera.torchMode = AVCaptureDevice.TorchMode.off
      } else {
        rearCamera.torchMode = AVCaptureDevice.TorchMode.on
      }
      
      rearCamera.unlockForConfiguration()
    }
  }
  
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
    
    guard let frontCameraInput = self.frontCameraInput, captureSession.inputs.contains(frontCameraInput),
      let rearCamera = self.rearCamera else { throw ControllerError.invalidOperation }
    
    self.rearCameraInput = try AVCaptureDeviceInput(device: rearCamera)
    
    captureSession.removeInput(frontCameraInput)
    
    if captureSession.canAddInput(self.rearCameraInput!) {
      captureSession.addInput(self.rearCameraInput!)
      
      self.currentCameraPosition = .rear
    }
    else { throw ControllerError.invalidOperation }
  }
}

public extension CameraController {
  
  enum ControllerError: Swift.Error {
    case captureSessionAlreadyRunning
    case captureSessionIsMissing
    case inputsAreInvalid
    case invalidOperation
    case noCamerasAvailable
    case unknown
  }
  
  public enum CameraPosition {
    case front
    case rear
  }
}

