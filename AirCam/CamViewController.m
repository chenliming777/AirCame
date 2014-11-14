//
//  CamViewController.m
//  AirCam
//
//  Created by Si Wen on 13-4-22.
//  Copyright (c) 2013年 Si Wen. All rights reserved.
//

#import "CamViewController.h"
#import <AVFoundation/AVCaptureDevice.h>
#import "rtmpManager.h"
#import "AudioManager.h"

#define SCREEN_WIDTH ([[UIScreen mainScreen]bounds].size.width)
#define SCREEN_HEIGHT ([[UIScreen mainScreen]bounds].size.height)
#define PHONE_STATUSBAR_HEIGHT 20
#define PHONE_NAVIGATIONBAR_HEIGHT 44
#define PHONE_SCREEN_SIZE (CGSizeMake(SCREEN_WIDTH, SCREEN_HEIGHT - PHONE_STATUSBAR_HEIGHT))
#define IS_IPHONE_5 (fabs((double)[[UIScreen mainScreen] bounds].size.height-(double)568 ) < DBL_EPSILON )

@interface CamViewController ()
{
    dispatch_queue_t _queue;
}
@end

@implementation CamViewController
@synthesize avCaptureSession;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    [[rtmpManager getInstance] startRtmpConnect];
    [[AudioManager getInstance] startRecording];
    
    localView = [[UIView alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    [self.view addSubview:localView];
    
    [[x264Manager getInstance] initForX264WithWidth:352 height:288];
    [[x264Manager getInstance] initForFilePath];
    
    [self startVideoCapture];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (AVCaptureDevice *)getFrontCamera {
    //获取前置摄像头设备
    NSArray *cameras = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for (AVCaptureDevice *device in cameras){
        if (device.position == AVCaptureDevicePositionBack)
            return device;
    }
    return [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
}

- (bool)startVideoCapture {
    //打开摄像设备，并开始捕抓图像
    NSLog(@"Starting Video stream");
    if(self->avCaptureDevice|| self->avCaptureSession) {
        NSLog(@"Already capturing");
        return false;
    }
    
    if((self->avCaptureDevice = [self getFrontCamera]) == nil) {
       NSLog(@"Failed to get valide capture device");
        return false;
    }
    
    NSError *error = nil;
    AVCaptureDeviceInput *videoInput = [AVCaptureDeviceInput deviceInputWithDevice:self->avCaptureDevice error:&error];
    if (!videoInput){
        NSLog(@"Failed to get video input");
        self->avCaptureDevice = nil;
        return false;
    }
    
    self->avCaptureSession = [[AVCaptureSession alloc] init];
    self->avCaptureSession.sessionPreset = AVCaptureSessionPreset352x288;
    [self->avCaptureSession addInput:videoInput];
    
    // Currently, the only supported key is kCVPixelBufferPixelFormatTypeKey. Recommended pixel format choices are
    // kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange or kCVPixelFormatType_32BGRA.
    // On iPhone 3G, the recommended pixel format choices are kCVPixelFormatType_422YpCbCr8 or kCVPixelFormatType_32BGRA.
    self->avCaptureVideoDataOutput = [[AVCaptureVideoDataOutput alloc] init];
    
    NSDictionary *settings = [[NSDictionary alloc] initWithObjectsAndKeys:
                              [NSNumber numberWithUnsignedInt:kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange], kCVPixelBufferPixelFormatTypeKey,
                              nil];

    self->avCaptureVideoDataOutput.videoSettings = settings;

    _queue = dispatch_queue_create("com.sinashow.com", NULL);
    [self->avCaptureVideoDataOutput setSampleBufferDelegate:self queue:_queue];
    [self->avCaptureSession addOutput:self->avCaptureVideoDataOutput];
    
    
    AVCaptureVideoPreviewLayer* previewLayer = [AVCaptureVideoPreviewLayer layerWithSession: self->avCaptureSession];
    previewLayer.frame = localView.bounds;
    previewLayer.videoGravity= AVLayerVideoGravityResizeAspectFill;
    [self->localView.layer addSublayer: previewLayer];

    [self->avCaptureSession startRunning];  
    NSLog(@"Video capture started");
    
    return true;
}

- (void)stopVideoCapture:(id)arg {
    //停止摄像头捕抓
    if(self->avCaptureSession){
        [self->avCaptureSession stopRunning];
        self->avCaptureSession= nil;
        NSLog(@"Video capture stopped");
    }
    self->avCaptureDevice= nil;
    //移除localView里面的内容
    for(UIView*view in self->localView.subviews) {
        [view removeFromSuperview];
    }
}


- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection

{
    //@autoreleasepool {
        if (captureOutput == self->avCaptureVideoDataOutput && CMSampleBufferDataIsReady(sampleBuffer))
        {
            [[x264Manager getInstance] encoderToH264:sampleBuffer];
        }
    //};
}

@end
