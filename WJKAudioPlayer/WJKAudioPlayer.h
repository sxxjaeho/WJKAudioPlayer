//
//  WJKAudioPlayer.h
//  iOSwujike
//
//  Created by Zeaho on 2017/8/24.
//  Copyright © 2017年 xhb_iOS. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

@class WJKAudioPlayer;

#define kPlayer [WJKAudioPlayer shareInstance]

typedef NS_ENUM(NSInteger, WJKAudioPlayerState) {
    WJKAudioPlayerState_UnKnown = 0, // 未知
    WJKAudioPlayerState_Loading = 1, // 正在加载
    WJKAudioPlayerState_Loaded  = 2, // 加载完成
    WJKAudioPlayerState_Playing = 3, // 播放中
    WJKAudioPlayerState_Stoped  = 4, // 停止
    WJKAudioPlayerState_Pause   = 5, // 暂停
    WJKAudioPlayerState_Failed  = 6, // 失败
};

@protocol WJKAudioPlayerDelegate <NSObject>

@optional
// 获取当前播放状态的代理方法
- (void)player:(WJKAudioPlayer *)player stateChanged:(WJKAudioPlayerState)state;
// 获取当前时间进度的代理方法
- (void)player:(WJKAudioPlayer *)player currentTime:(CGFloat)currentTime;
// 音频将要播放的代理方法
- (void)audioPlayerWillPlayMusic;
// 音频将要停止的代理方法
- (void)audioPlayerWillStopMusic;

@end

@interface WJKAudioPlayer : NSObject

/**
 播放地址
 */
@property (nonatomic, copy) NSString *playUrl;

/**
 是否静音
 */
@property (nonatomic, assign) BOOL muted;

/**
 倍速控制
 */
@property (nonatomic, assign) float rate;

/**
 音量控制
 */
@property (nonatomic, assign) float volume;

/**
 音频总时长
 */
@property (nonatomic, assign, readonly) NSTimeInterval totalTime;
@property (nonatomic, strong, readonly) NSString *totalTimeFormat;

/**
 当前播放时长
 */
@property (nonatomic, assign, readonly) NSTimeInterval currentTime;
@property (nonatomic, strong, readonly) NSString *currentTimeFormat;

/**
 当前播放进度
 */
@property (nonatomic, assign, readonly) float progress;

/**
 当前加载进度
 */
@property (nonatomic, assign, readonly) float loadProgress;

/**
 当前播放URL
 */
@property (nonatomic, strong, readonly) NSURL *currentURL;

/**
 当前播放播放状态
 */
@property (nonatomic, assign, readonly) WJKAudioPlayerState state;

/**
 播放器代理
 */
@property (nonatomic, weak) id<WJKAudioPlayerDelegate> delegate;

/**
 单例

 @return instance
 */
+ (instancetype)shareInstance;

/**
 根据音频地址播放

 @param url 音频地址
 */
- (void)playWithURL:(NSURL *)url;

/**
 暂停
 */
- (void)pause;

/**
 继续播放
 */
- (void)resume;

/**
 停止
 */
- (void)stop;

/**
 快进快退

 @param timing 快进快退时间
 */
- (void)seekWithTimeDiffer:(NSTimeInterval)timing;

/**
 指定播放进度播放
 */
- (void)seekWithProgress:(CGFloat)progress;

/**
 指定播放时间

 @param time 指定时间点
 @param isResume 是否继续
 */
- (void)seekWithTime:(CGFloat)time isResume:(BOOL)isResume;

@end
