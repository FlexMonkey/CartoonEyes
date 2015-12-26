//
//  ViewController.swift
//  FaceDetect
//
//  Created by Simon Gladman on 24/12/2015.
//  Copyright © 2015 Simon Gladman. All rights reserved.
//

import UIKit
import GLKit
import AVFoundation
import CoreMedia

class ViewController: UIViewController
{
    let eaglContext = EAGLContext(API: .OpenGLES2)
    
    let comicEffect = CIFilter(name: "CIComicEffect")!
    let eyeballImage = CIImage(image: UIImage(named: "eyeball.png")!)!
    
    lazy var ciContext: CIContext =
    {
        [unowned self] in
        
        return  CIContext(EAGLContext: self.eaglContext)
    }()
    
    lazy var detector: CIDetector =
    {
        [unowned self] in
        
        CIDetector(ofType: CIDetectorTypeFace, context: self.ciContext, options: nil)
    }()
    
    let imageView = GLKView()
    var cameraImage: CIImage?
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        initialiseCaptureSession()
        
        view.addSubview(imageView)
        imageView.context = eaglContext
        imageView.delegate = self
    }

    func initialiseCaptureSession()
    {
        let captureSession = AVCaptureSession()
        captureSession.sessionPreset = AVCaptureSessionPresetPhoto
        
        guard let frontCamera = AVCaptureDevice.devicesWithMediaType(AVMediaTypeVideo)
            .filter({ ($0 as? AVCaptureDevice)?.position == AVCaptureDevicePosition.Front })
            .first as? AVCaptureDevice else
        {
            fatalError("Unable to access front camera")
        }
        
        do
        {
            let input = try AVCaptureDeviceInput(device: frontCamera)
            
            captureSession.addInput(input)
        }
        catch
        {
            fatalError("Unable to access front camera")
        }
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        view.layer.addSublayer(previewLayer)
        
        let videoOutput = AVCaptureVideoDataOutput()
        
        videoOutput.setSampleBufferDelegate(self, queue: dispatch_queue_create("sample buffer delegate", DISPATCH_QUEUE_SERIAL))
        if captureSession.canAddOutput(videoOutput)
        {
            captureSession.addOutput(videoOutput)
        }
        
        captureSession.startRunning()
    }
    
    /// Detects either the left or right eye from `cameraImage` and, if detected, composites
    /// `eyeballImage` over `backgroundImage`. If no eye is detected, simply returns the
    /// `backgroundImage`.
    func eyeImage(cameraImage: CIImage, backgroundImage: CIImage, leftEye: Bool) -> CIImage
    {
        let compositingFilter = CIFilter(name: "CISourceAtopCompositing")!
        let transformFilter = CIFilter(name: "CIAffineTransform")!
        
        let halfEyeWidth = eyeballImage.extent.width / 2
        let halfEyeHeight = eyeballImage.extent.height / 2
        
        if let features = detector.featuresInImage(cameraImage).first as? CIFaceFeature where leftEye ? features.hasLeftEyePosition : features.hasRightEyePosition
        {
            let leftEyePosition = CGAffineTransformMakeTranslation(
                leftEye ? features.leftEyePosition.x - halfEyeWidth : features.rightEyePosition.x - halfEyeWidth,
                leftEye ? features.leftEyePosition.y - halfEyeHeight : features.rightEyePosition.y - halfEyeHeight)
            
            transformFilter.setValue(eyeballImage, forKey: "inputImage")
            transformFilter.setValue(NSValue(CGAffineTransform: leftEyePosition), forKey: "inputTransform")
            let leftTransformResult = transformFilter.valueForKey("outputImage") as! CIImage
            
            compositingFilter.setValue(backgroundImage, forKey: kCIInputBackgroundImageKey)
            compositingFilter.setValue(leftTransformResult, forKey: kCIInputImageKey)
            
            return  compositingFilter.valueForKey("outputImage") as! CIImage
        }
        else
        {
            return backgroundImage
        }
    }
    
    override func viewDidLayoutSubviews()
    {
        imageView.frame = view.bounds
    }
}

extension ViewController: AVCaptureVideoDataOutputSampleBufferDelegate
{
    func captureOutput(captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, fromConnection connection: AVCaptureConnection!)
    {
        connection.videoOrientation = AVCaptureVideoOrientation(rawValue: UIApplication.sharedApplication().statusBarOrientation.rawValue)!

        let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
        cameraImage = CIImage(CVPixelBuffer: pixelBuffer!)

        dispatch_async(dispatch_get_main_queue())
        {
            self.imageView.setNeedsDisplay()
        }
    }
}

extension ViewController: GLKViewDelegate
{
    func glkView(view: GLKView, drawInRect rect: CGRect)
    {
        guard let cameraImage = cameraImage else
        {
            return
        }

        let leftEyeImage = eyeImage(cameraImage, backgroundImage: cameraImage, leftEye: true)
        let rightEyeImage = eyeImage(cameraImage, backgroundImage: leftEyeImage, leftEye: false)
 
        comicEffect.setValue(rightEyeImage, forKey: kCIInputImageKey)
        
        let outputImage = comicEffect.valueForKey(kCIOutputImageKey) as! CIImage

        ciContext.drawImage(outputImage,
            inRect: CGRect(x: 0, y: 0, width: imageView.drawableWidth, height: imageView.drawableHeight),
            fromRect: outputImage.extent)
    }
}





