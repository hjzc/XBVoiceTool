//
//  XBAudioUnitMixer.m
//  XBVoiceTool
//
//  Created by xxb on 2018/7/2.
//  Copyright © 2018年 xxb. All rights reserved.
//

#import "XBAudioUnitMixer.h"
#import "XBAudioUnitRecorder.h"
#import "XBAudioUnitPlayer.h"
#import "XBAudioDataReader.h"
#import "XBAudioDataWriter.h"

#define subPathPCM @"/Documents/xbMixData"
#define stroePath [NSHomeDirectory() stringByAppendingString:subPathPCM]

#define CONST_BUFFER_SIZE 2048*2*10

@interface XBAudioUnitMixer ()
{
    Byte *recorderTempBuffer;
}
@property (nonatomic,strong) XBAudioUnitRecorder *recorder;
@property (nonatomic,strong) XBAudioUnitPlayer *player;
@property (nonatomic,strong) XBAudioDataReader *dataReader;
@property (nonatomic,strong) XBAudioDataWriter *dataWriter;
@property (nonatomic,strong) NSData *data;
@end

@implementation XBAudioUnitMixer

- (instancetype)initWithPCMFilePath:(NSString *)filePath rate:(XBVoiceRate)rate channels:(XBVoiceChannel)channels bit:(XBVoiceBit)bit
{
    if (self = [super init])
    {
        self.data = [NSData dataWithContentsOfFile:filePath];
        self.player = [[XBAudioUnitPlayer alloc] initWithRate:rate bit:bit channel:channels];
        self.recorder = [[XBAudioUnitRecorder alloc] initWithRate:rate bit:bit channel:channels];
        self.dataReader = [XBAudioDataReader new];
        self.dataWriter = [XBAudioDataWriter new];
        [self initParams];
    }
    return self;
}

- (void)initParams
{
    recorderTempBuffer = malloc(CONST_BUFFER_SIZE);
    typeof(self) __weak weakSelf = self;
    typeof(weakSelf) __strong strongSelf = weakSelf;
    if (self.recorder.bl_output == nil)
    {
        self.recorder.bl_output = ^(AudioBufferList *bufferList) {
            AudioBuffer buffer = bufferList->mBuffers[0];
            int len = buffer.mDataByteSize;
            memcpy(strongSelf->recorderTempBuffer, buffer.mData, len);
        };
    }
    if (self.player.bl_input == nil)
    {
        self.player.bl_input = ^(AudioBufferList *bufferList) {
            AudioBuffer buffer = bufferList->mBuffers[0];
            int len = buffer.mDataByteSize;
            int readLen = [weakSelf.dataReader readDataFrom:weakSelf.data len:len forData:buffer.mData];
            buffer.mDataByteSize = readLen;
            
            for (int i = 0; i < readLen; i++)
            {
                ((Byte *)buffer.mData)[i] = ((Byte *)buffer.mData)[i] + strongSelf->recorderTempBuffer[i];
            }
            //写文件
//            [strongSelf.dataWriter writeBytes:buffer.mData len:readLen toPath:stroePath];
            if (readLen == 0)
            {
                [weakSelf stop];
            }
        };
    }
}

- (void)start
{
    [self.recorder start];
    [self.player start];
}

- (void)stop
{
    self.recorder.bl_output = nil;
    self.player.bl_input = nil;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self.recorder stop];
        [self.player stop];
    });
}
@end
