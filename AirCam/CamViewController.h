//
//  CamViewController.h
//  AirCam
//
//  Created by Si Wen on 13-4-22.
//  Copyright (c) 2013年 Si Wen. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import "x264Manager.h"

@interface CamViewController : UIViewController <AVCaptureVideoDataOutputSampleBufferDelegate> {
    AVCaptureSession*   avCaptureSession;
    AVCaptureDevice*    avCaptureDevice;
    AVCaptureVideoDataOutput *avCaptureVideoDataOutput;
    
    UIView*             localView;
    
    x264Manager* manager264;
    
}

@property (nonatomic, retain) AVCaptureSession *avCaptureSession;

@end
