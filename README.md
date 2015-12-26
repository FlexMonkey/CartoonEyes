# CartoonEyes
Composite Cartoon Eyes over Face from Front Camera with CoreImage

Companion project to: http://flexmonkey.blogspot.co.uk/2015/12/cartooneyes-compositing-cartoon-eyes.html

![screenshot](/FaceDetect/screenshot.jpg)

Here's some festive silliness: CartoonEyes composites cartoon eyeballs over a face captured by an iOS devices's front camera and then passes that composite through a Core Image Comic Effect filter. It makes use of Core Image's face detection class, `CIDetector`, to find the positions of the eyes.

##Capturing Video from Front Camera

I played with applying Core Image filters to a live camera feed earlier this year (see: Applying CIFilters to a Live Camera Feed with Swift). The main difference with this project is that I wanted to use the front camera rather than the default camera. To do this, I use a guard statement to filter the the devices by their position and pick the first item of that filter as my device:

```swift
    guard let frontCamera = (AVCaptureDevice.devicesWithMediaType(AVMediaTypeVideo) as! [AVCaptureDevice])
    .filter({ $0.position == .Front })
    .first else
    {
        fatalError("Unable to access front camera")
    }
```    

##Compositing Cartoon Eyes

Once I have the source image from the camera, it's time to composite the cartoon eyes over it. My function, `eyeImage()`, takes the original camera image (to calculate  the eye positions), an image to composite the eye over and a Boolean indicating whether it's looking at the left or right eye:

```swift
    func eyeImage(cameraImage: CIImage, backgroundImage: CIImage, leftEye: Bool) -> CIImage
```

It's called twice:

```swift
    let leftEyeImage = eyeImage(cameraImage, backgroundImage: cameraImage, leftEye: true)
    let rightEyeImage = eyeImage(cameraImage, backgroundImage: leftEyeImage, leftEye: false)
```

The first call creates an image compositing the left eye over the original camera image and the second call composites the right eye over the previous left eye composite.

Before I can invoke eyeImage(), I need a `CIDetector` instance which will give me the positions of the facial features:

```swift
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
```

Inside `eyeImage()`, I first create a composite Core Image filter and a transform filter:

```swift
    let compositingFilter = CIFilter(name: "CISourceAtopCompositing")!
    let transformFilter = CIFilter(name: "CIAffineTransform")!
```

I also need to calculate the midpoint of the cartoon eye image as an offset for the transform:

```swift
    let halfEyeWidth = eyeballImage.extent.width / 2
    let halfEyeHeight = eyeballImage.extent.height / 2
```

Now, using the detector, I need the features of the first face in the image and, depending on the `leftEye` argument, whether it has the eye position I need:

```swift
    if let features = detector.featuresInImage(cameraImage).first as? CIFaceFeature
        where leftEye ? features.hasLeftEyePosition : features.hasRightEyePosition
    {
        ...
```

If it does, I'll need to create a transform for the transform filter to position the cartoon eye image based on the "real" eye position:

```swift
    let eyePosition = CGAffineTransformMakeTranslation(
        leftEye ? features.leftEyePosition.x - halfEyeWidth : features.rightEyePosition.x - halfEyeWidth,
        leftEye ? features.leftEyePosition.y - halfEyeHeight : features.rightEyePosition.y - halfEyeHeight)
```

...and now I can execute the transform filter and get an image of the cartoon eye positioned over the real eye:

```swift
    transformFilter.setValue(eyeballImage, forKey: "inputImage")
    transformFilter.setValue(NSValue(CGAffineTransform: eyePosition), forKey: "inputTransform")

    let transformResult = transformFilter.valueForKey("outputImage") as! CIImage
```

Finally I composite the transformed cartoon eye over the supplied background image and return that result:

```swift
    compositingFilter.setValue(backgroundImage, forKey: kCIInputBackgroundImageKey)
    compositingFilter.setValue(transformResult, forKey: kCIInputImageKey)
    
    return  compositingFilter.valueForKey("outputImage") as! CIImage
```

If there were no facial features detected, I simply return the background image as it was supplied.

##Displaying Output with OpenGL ES

Rather than converting the output to a `UIImage` and displaying it in a `UIImageView`, this project takes the more direct route and renders the output using a `GLKView`. Once the captureOutput method of my `AVCaptureVideoDataOutputSampleBufferDelegate` has its image, it invalidates the `GLKView`'s display in a foreground thread:

```swift
    dispatch_async(dispatch_get_main_queue())
    {
        self.imageView.setNeedsDisplay()
    }
```

Since my view controller is the `GLKView`'s `GLKViewDelegate`, this invokes `glkView()` where I call `eyeImage()` and pass the right eye's image into a comic effect Core Image filter and draw that output the the `GLKView`'s context:

```swift
    let leftEyeImage = eyeImage(cameraImage, backgroundImage: cameraImage, leftEye: true)
    let rightEyeImage = eyeImage(cameraImage, backgroundImage: leftEyeImage, leftEye: false)

    comicEffect.setValue(rightEyeImage, forKey: kCIInputImageKey)
    
    let outputImage = comicEffect.valueForKey(kCIOutputImageKey) as! CIImage

    ciContext.drawImage(outputImage,
        inRect: CGRect(x: 0, y: 0,
            width: imageView.drawableWidth,
            height: imageView.drawableHeight),
        fromRect: outputImage.extent)
```

##Conclusion

With very little work, the combination of Core Image filters and detectors combined with AV Capture Session has allowed me to composite different images based on the positions of different facial features. 

As always, the source code for this project is available at my GitHub repository here. Enjoy!
