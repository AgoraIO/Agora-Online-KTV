//
//  KTVKit.h
//  Agora-Online-KTV
//
//  Created by zhanxiaochao on 2018/9/20.
//  Copyright © 2018年 Agora. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AgoraRtcKit/AgoraRtcEngineKit.h>
NS_ASSUME_NONNULL_BEGIN
typedef NS_ENUM(NSInteger, KTVStatusType)
{
    KTVStatusTypePrepared = 1,
    KTVStatusTypeCompleted = 2,
};

@protocol KTVKitDelegate <NSObject>
- (void)ktvStatusCallBack:(KTVStatusType)ktvStatusType;
@end

@interface KTVKit : NSObject
+ (instancetype)shareInstance;
@property (nonatomic, assign) id<KTVKitDelegate>delegate;

//创建KTVKit
- (void)createKTVKitWithView:(UIView * _Nonnull)view rtcEngine:(AgoraRtcEngineKit * _Nonnull)rtcEngine sampleRate:(int)sampleRate;
//切歌
- (void)loadMV:(NSString * _Nonnull)videoPath;
//获取视频时长
- (double)getDuation;
//获取当前的视频位置
- (float)getCurrentPosition;
//调整采集人声的音量
- (void)adjustVoiceVolume:(double)volume;
//调整视频音量
- (void)adjustAccompanyVolume:(double)volume;
//设置音轨(计数从1开始; 如果有多音轨，默认值2; 不支持大于2的值)
- (void)setAudioTrack:(int)audioTrack;
//视频的播放/暂停
- (void)play;
- (void)pause;
//释放 KTVKit 占用的资源
- (void)releaseSource;
//注销 KTVKit
- (void)destroyKTVKit;
@end

NS_ASSUME_NONNULL_END
