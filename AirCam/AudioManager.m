//
//  AudioManager.m
//  AirCam
//
//  Created by user on 14/11/11.
//  Copyright (c) 2014年 Si Wen. All rights reserved.
//

#import "AudioManager.h"
#import "rtmpManager.h"

#define SAMPLERATE      8000
#define NUMBERCHANNEL   1
#define BUFFERBYTESIZE  16000

@implementation AudioManager

static AudioManager* shareInstace = nil;
+ (instancetype)getInstance
{
    static dispatch_once_t instance;
    dispatch_once(&instance, ^{
        shareInstace = [[self alloc] init];
    });
    return shareInstace;
}

static void OnInputBufferCallback(void *inUserData,
                             AudioQueueRef inAQ,
                             AudioQueueBufferRef inBuffer,
                             const AudioTimeStamp *inStartTime,
                             UInt32 inNumPackets,
                             const AudioStreamPacketDescription *inPacketDesc)
{
    AudioManager * manager = (__bridge AudioManager*)inUserData;
    if (manager == NULL || manager->recording == NO)
    {
        return;
    }
    
    //此处编码
    unsigned int bufferSize = 0;
    int nRet = faacEncEncode(manager->audioEncoder, inBuffer->mAudioData, manager->inputSamples, manager->outputBuffer, bufferSize);
        
    if (nRet > 0)
    {
        [[rtmpManager getInstance] send_rtmp_audio:manager->outputBuffer andLength:nRet];
        //fwrite(manager->outputBuffer, 1, nRet, manager->fp);
    }
    AudioQueueEnqueueBuffer(manager->queueRef, inBuffer, 0, NULL);
}

static void OnIsRunningCallback(void *inUserData, AudioQueueRef inAQ, AudioQueuePropertyID inID)
{
    AudioManager * manager = (__bridge AudioManager*)inUserData;
    if (manager == NULL)
    {
        return;
    }
    
    UInt32 size = sizeof(manager->running);
    AudioQueueGetProperty(manager->queueRef, kAudioQueueProperty_IsRunning, &manager->running, &size);
    
    if (!manager->running)
    {
        [manager stopRecording];
    }
}

- (void)startRecording
{
    [self openEncoder];
    [self initForFilePath];
    
    AVAudioSession * audioSession = [AVAudioSession sharedInstance];
    [audioSession setCategory:AVAudioSessionCategoryPlayAndRecord error: nil];
    UInt32 audioRouteOverride = kAudioSessionOverrideAudioRoute_Speaker;
    AudioSessionSetProperty (kAudioSessionProperty_OverrideAudioRoute,
                             sizeof (audioRouteOverride),
                             &audioRouteOverride);
    [audioSession setActive:YES error: nil];
    
    
    
    self->basicDescription.mFormatID = kAudioFormatLinearPCM;
    self->basicDescription.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked;
    self->basicDescription.mSampleRate = SAMPLERATE;
    self->basicDescription.mChannelsPerFrame = NUMBERCHANNEL;
    self->basicDescription.mBitsPerChannel = 16;
    self->basicDescription.mBytesPerPacket = self->basicDescription.mBytesPerFrame = (self->basicDescription.mBitsPerChannel / 8) * self->basicDescription.mChannelsPerFrame;
    self->basicDescription.mFramesPerPacket = 1;
    
    OSStatus status = AudioQueueNewInput(&self->basicDescription, OnInputBufferCallback, (__bridge void*)self, CFRunLoopGetCurrent(), kCFRunLoopCommonModes, 0, &self->queueRef);
    if (status)
    {
        NSLog(@"Could not establish new queue");
        return;
    }
    
    AudioQueueSetParameter(self->queueRef, kAudioQueueParam_Volume, 1.0f);
    
    for (unsigned int i = 0; i != kNumberOfRecordBuffers; ++i)
    {
        AudioQueueAllocateBuffer(self->queueRef, BUFFERBYTESIZE, &(self->buffer[i]));
        AudioQueueEnqueueBuffer(self->queueRef, self->buffer[i], 0, NULL);
    }
    
     //AudioQueueAddPropertyListener(self->queueRef, kAudioQueueProperty_IsRunning, OnIsRunningCallback, (__bridge void*)self);
    
    UInt32 trueValue = true;
    AudioQueueSetProperty(self->queueRef, kAudioQueueProperty_EnableLevelMetering, &trueValue, sizeof(trueValue));
    OSStatus rst = AudioQueueStart(self->queueRef, NULL);
    
    if (rst != 0)
    {
        AudioQueueStart(self->queueRef, NULL);
    }
    self->recording = YES;
}


- (void)stopRecording
{
    AudioQueueStop(self->queueRef, true);
    AudioQueueDispose(self->queueRef, false);
    self->queueRef = NULL;
    
    [self stopEncoder];
}


- (void)openEncoder
{
    self->audioEncoder = faacEncOpen(SAMPLERATE, NUMBERCHANNEL, &self->inputSamples, &self->maxOutputBytes);
    faacEncConfigurationPtr ptr = faacEncGetCurrentConfiguration(self->audioEncoder);
    ptr->inputFormat = FAAC_INPUT_16BIT;
    faacEncSetConfiguration(self->audioEncoder, ptr);
    
    unsigned char *tmp;
    unsigned long spec_len;
    faacEncGetDecoderSpecificInfo(self->audioEncoder, &tmp, &spec_len);
    [[rtmpManager getInstance] send_rtmp_audio_spec:tmp andLength:(UInt32)spec_len];
    free(tmp);
    
    self->outputBuffer = malloc(self->maxOutputBytes);
}


- (void)stopEncoder
{
    faacEncClose(self->audioEncoder);
}


- (void)initForFilePath
{
    char *path = [self GetFilePathByfileName:"IOSCamDemo.aac"];
    NSLog(@"%s",path);
    self->fp = fopen(path,"wb");
}


- (char*)GetFilePathByfileName:(char*)filename

{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask,YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSString *strName = [NSString stringWithFormat:@"%s",filename];
    
    NSString *writablePath = [documentsDirectory stringByAppendingPathComponent:strName];
    
    NSUInteger len = [writablePath length];
    
    char *filepath = (char*)malloc(sizeof(char) * (len + 1));
    
    [writablePath getCString:filepath maxLength:len + 1 encoding:[NSString defaultCStringEncoding]];
    
    return filepath;
}

@end
