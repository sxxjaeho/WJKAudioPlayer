//
//  WJKAudioPlayer.m
//  iOSwujike
//
//  Created by Zeaho on 2017/8/24.
//  Copyright © 2017年 xhb_iOS. All rights reserved.
//

#import "WJKAudioPlayer.h"

static WJKAudioPlayer *_instance;

@interface WJKAudioPlayer()
/**
 播放器
 */
@property (nonatomic, strong) AVPlayer *player;

/**
 时间监听
 */
@property (nonatomic, strong) id timerObserver;

@end

@implementation WJKAudioPlayer

#pragma mark - life cycle
- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

// 移除观察者
- (void)removeObservers
{
    [[[self player] currentItem] removeObserver:self forKeyPath:@"status"];
    [[[self player] currentItem] removeObserver:self forKeyPath:@"playbackLikelyToKeepUp"];
    [self removeObserver:self forKeyPath:@"state"];
}

// 添加时间监听
- (void)addPlayerTimerObserver
{
    if (!(_timerObserver != nil)) {
        __weak typeof(self)weakSelf = self;
        _timerObserver = [[self player] addPeriodicTimeObserverForInterval:CMTimeMake(1, 30) queue:dispatch_get_main_queue() usingBlock:^(CMTime time) {
            if ([[weakSelf delegate] respondsToSelector:@selector(player:currentTime:)] && self.delegate) {
                [[weakSelf delegate] player:weakSelf currentTime:CMTimeGetSeconds(time)];
            }
        }];
    }
}

// 移除时间监听
- (void)removePlayerTimerObserver
{
    if (_timerObserver != nil) {
        [[self player] removeTimeObserver:_timerObserver];
        _timerObserver = nil;
    }
}

#pragma mark - public
- (void)playWithURL:(NSURL *)url {
    if([NSURL URLWithString:[self playUrl]] == url) {
        //如果这次播放和上一次一样，说明播放任务存在，存在就继续播放
        [self resume];
        return;
    }

    self.playUrl = [url absoluteString];
    
    // 请求资源
    AVURLAsset *asset = [AVURLAsset assetWithURL:url];
    
    // 播放下一个之移除上一个资源组织组者的监听
    if([[self player] currentItem]) {
        [self removeObservers];
        [self removePlayerTimerObserver];
    }
    
    // 资源的组织
    AVPlayerItem *item = [AVPlayerItem playerItemWithAsset:asset];
    
    // 组织播放状态(WJKAudioPlayerState_UnKnown,WJKAudioPlayerState_Playing,WJKAudioPlayerState_Failed)
    [item addObserver:self forKeyPath:@"status" options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld context:nil];
    
    // 组织加载内容(WJKAudioPlayerState_Loading)
    [item addObserver:self forKeyPath:@"playbackLikelyToKeepUp" options:NSKeyValueObservingOptionNew |NSKeyValueObservingOptionOld context:nil];
    
    // 监听当前资源状态
    [self addObserver:self forKeyPath:@"state" options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld context:nil];
    
    // 通知监听(WJKAudioPlayerState_Stoped)
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(audioPlayerPlayMusicToEnd:) name:AVPlayerItemDidPlayToEndTimeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(audioPlayerInterruptPlayMusic:) name:AVPlayerItemPlaybackStalledNotification object:nil];
    
    // 资源的播放
    self.player = [AVPlayer playerWithPlayerItem:item];
    
    // 添加时间监听
    [self addPlayerTimerObserver];
}

- (void)pause {
    
    [[self player] pause];
    // 设置暂停状态
    if(self.player) {
        self.state = WJKAudioPlayerState_Pause;
    }
}

- (void)resume {
    
    // 播放器存在并且资源已经加载到可以播放,设置播放状态
    if(self.player && self.player.currentItem.playbackLikelyToKeepUp) {
        self.state = WJKAudioPlayerState_Playing;
    }
    [[self player] play];
}

- (void)stop {
    //必须移除上一个资源组织组者的监听
    if(self.player.currentItem) {
        [self removeObservers];
        [self removePlayerTimerObserver];
    }
    
    [self pause];
    
    // 设置停止状态
    if(self.player) {
        self.state = WJKAudioPlayerState_Stoped;
    }
    
    self.player = nil;
}

- (void)seekWithProgress:(CGFloat)progress {
    
    if(progress < 0 || progress > 1) return;
    
    // 获取总时长
    NSTimeInterval totalTimeSec = [self totalTime];
    
    // 需要播放的进度
    NSTimeInterval playTimeSec = totalTimeSec * progress;
    CMTime currentTime = CMTimeMake(playTimeSec, 1.0);
    
    // 播放
    __weak typeof(self) weakSelf = self;
    if (self.player.currentItem.playbackLikelyToKeepUp) {
        [[self player] seekToTime:currentTime completionHandler:^(BOOL finished) {
            if(finished){
                NSLog(@"拖动到%f秒", CMTimeGetSeconds(currentTime));
                //播放结束的时候，不会自动调用播放，需要手动调用
                [weakSelf resume];
            } else {
                NSLog(@"取消加载");
            }
        }];
    }
}

- (void)seekWithTimeDiffer:(NSTimeInterval)timing {
    // 获取总时长
    NSTimeInterval totalTimeSec = [self totalTime];
    
    //  获取当前时长
    NSTimeInterval currentTimeSec = [self currentTime];
    
    // 计算快进和快退时长
    NSTimeInterval result = currentTimeSec + timing;
    if(result < 0) result = 0;
    if(result > totalTimeSec) result =  totalTimeSec;
    
    // 播放
    [self seekWithProgress:result/totalTimeSec];
}

- (void)seekWithTime:(CGFloat)time isResume:(BOOL)isResume {
    // 获取总时长
    NSTimeInterval totalTimeSec = [self totalTime];
    if (time < 0) {
        time = 0;
    }
    if(time > totalTimeSec){
       time =  totalTimeSec;
    }
    CMTime currentTime = CMTimeMake(time, 1.0);
    // 播放
    __weak typeof(self) weakSelf = self;
    if (self.player.currentItem.playbackLikelyToKeepUp) {
        [[self player] seekToTime:currentTime completionHandler:^(BOOL finished) {
            if(finished){
                if (isResume) {
                    [weakSelf resume];
                } else {
                    [weakSelf pause];
                }
            } else {
                NSLog(@"取消加载");
            }
        }];
    }
}

// 播放结束
- (void)audioPlayerPlayMusicToEnd:(NSNotification *)notification{
    // 设置停止状态
    if(self.player) {
        self.state = WJKAudioPlayerState_Stoped;
    }
    if ([[self delegate] respondsToSelector:@selector(audioPlayerWillStopMusic)]) {
        [[self delegate] audioPlayerWillStopMusic];
    }
    NSLog(@"播放结束");
}

// 播放被打断
- (void)audioPlayerInterruptPlayMusic:(NSNotification *)notification {
    NSLog(@"播放被打断");
}

#pragma mark - KVO
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context
{
    if([keyPath isEqualToString:@"status"]) {
        AVPlayerItemStatus status = [change[NSKeyValueChangeNewKey] integerValue];
        switch (status) {
            case AVPlayerItemStatusReadyToPlay:
            {
                NSLog(@"数据加载完毕,开始播放");
                if (self.state != WJKAudioPlayerState_Pause) {
                    [self resume];
                }
                break;
            }
            case AVPlayerItemStatusFailed:
            {
                NSLog(@"数据加载失败,无法播放");
                self.state = WJKAudioPlayerState_Failed;
                break;
            }
            default:
                break;
        }
    } else if ([keyPath isEqualToString:@"playbackLikelyToKeepUp"]) {
        BOOL keepUp = [change[NSKeyValueChangeNewKey] integerValue];
        if(keepUp) {
            if ([[self delegate] respondsToSelector:@selector(audioPlayerWillPlayMusic)]) {
                [[self delegate] audioPlayerWillPlayMusic];
            }
            // 设置加载完成状态
            if (self.player && self.state != WJKAudioPlayerState_Pause) {
                self.state = WJKAudioPlayerState_Loaded;
            }
            NSLog(@"资源已经加载的差不多,可以播放了");
        } else {
            // 设置正在加载状态
            if (self.player) {
                self.state = WJKAudioPlayerState_Loading;
            }
            NSLog(@"资源不够,还要继续加载");
        }
    } else if ([keyPath isEqualToString:@"state"]) {
        if ([[self delegate] respondsToSelector:@selector(player:stateChanged:)]) {
            [[self delegate] player:self stateChanged:[self state]];
        }
        NSLog(@"状态改变,状态码:%ld", self.state);
    }
}

#pragma mark - accessor
- (void)setState:(WJKAudioPlayerState)state
{
    if(_state == state) {
        return;
    }
    _state = state;
}

- (void)setPlayUrl:(NSString *)playUrl {
    if (_playUrl != playUrl) {
        _playUrl = playUrl;
    }
    if (self.state == WJKAudioPlayerState_Playing) {
        [self stop];
    }
}

- (NSTimeInterval)totalTime
{
    CMTime totalTime = self.player.currentItem.duration;
    NSTimeInterval totalTimeSec = CMTimeGetSeconds(totalTime);
    if(isnan(totalTimeSec))
        return 0;
    return totalTimeSec;
}

- (NSString *)totalTimeFormat
{
    return [NSString stringWithFormat:@"%02zd:%02zd",(int)self.totalTime/60,(int)self.totalTime%60];
}

- (NSTimeInterval)currentTime
{
    CMTime currentTime = self.player.currentItem.currentTime;
    NSTimeInterval currentTimeSec = CMTimeGetSeconds(currentTime);
    if(isnan(currentTimeSec)) {
        return 0;
    }
    return currentTimeSec;
}

- (NSString*)currentTimeFormat
{
    return [NSString stringWithFormat:@"%02zd:%02zd",(int)self.currentTime/60,(int)self.currentTime%60];
}

- (float)progress
{
    if(self.totalTime == 0) {
        return 0;
    }
    return self.currentTime / self.totalTime;
}

- (float)loadProgress
{
    CMTimeRange timeRange = [[self.player.currentItem loadedTimeRanges].lastObject CMTimeRangeValue];
    CMTime loadTime =  CMTimeAdd(timeRange.start, timeRange.duration);
    NSTimeInterval loadTimeSec = CMTimeGetSeconds(loadTime);
    if(isnan(loadTimeSec)) {
        return 0;
    }
    return loadTimeSec / self.totalTime;
}

- (void)setRate:(float)rate
{
    self.player.rate = rate;
}

- (float)rate
{
    return self.player.rate;
}

- (void)setMuted:(BOOL)muted
{
    self.player.muted = muted;
}

- (BOOL)muted
{
    return self.player.muted;
}

- (void)setVolume:(float)volume
{
    if(volume < 0 || volume > 1) {
        return;
    }
    
    if(volume > 0)
        [self setMuted:NO];
    
    self.player.volume = volume;
}

- (float)volume{
    return self.player.volume;
}

#pragma mark - singleton
+ (instancetype)shareInstance
{
    if(_instance == nil) {
        _instance = [[self alloc]init];
    }
    return _instance;
}

+ (instancetype)allocWithZone:(struct _NSZone *)zone
{
    if(_instance == nil) {
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            _instance = [super allocWithZone:zone];
        });
    }
    return _instance;
}

@end
