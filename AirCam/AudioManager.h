//
//  AudioManager.h
//  AirCam
//
//  Created by user on 14/11/11.
//  Copyright (c) 2014年 Si Wen. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import "faac.h"

#define kNumberOfRecordBuffers 3
#define Bitrate 200//码率

@interface AudioManager : NSObject
{
    AudioStreamBasicDescription basicDescription;
    AudioQueueRef               queueRef;
    AudioQueueBufferRef         buffer[3];
    
    BOOL                        recording;
    BOOL                        running;
    
    faacEncHandle               audioEncoder;
    unsigned long               inputSamples;
    unsigned long               maxOutputBytes;
    unsigned char*              outputBuffer;
    
    FILE *fp;
}

+ (instancetype)getInstance;

/**
 *  开始录制
 */
- (void)startRecording;

/**
 *  结束录制
 */
- (void)stopRecording;

@end
