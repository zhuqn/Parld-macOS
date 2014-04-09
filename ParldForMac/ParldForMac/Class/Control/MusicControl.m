//
//  MusicControl.m
//  ParldForMac
//
//  Created by sohunjug on 3/30/14.
//  Copyright (c) 2014 sohunjug. All rights reserved.
//

#import "MusicControl.h"
#import "ParldInterface.h"

static MusicControl *musicControl;
static MusicControlValue * _Music_Control_Value_;

@implementation MusicControlValue

@synthesize streamer;
@synthesize musicList;
@synthesize playIndex;
@synthesize nowState;
@synthesize lastState;
@synthesize playAtLaunch;

- (id)init
{
    if (self = [super init]) {
        [self refresh];
        [[NSUserDefaults standardUserDefaults] registerDefaults:
         [NSDictionary dictionaryWithContentsOfFile:
          [[NSBundle mainBundle] pathForResource:@"ParldConfig" ofType:@"plist"]]];
        
        playAtLaunch = [[NSUserDefaults standardUserDefaults] boolForKey:@"playAtLaunch"];
    }
    return self;
}

+ (MusicControlValue*)shareInstance
{
    if (_Music_Control_Value_ == nil) {
        _Music_Control_Value_ = [[MusicControlValue alloc] init];
    }
    return _Music_Control_Value_;
}

- (void)refresh
{
    playIndex = 0;
    nowState = MusicInit;
    lastState = MusicInit;
    musicList = [[ParldInterface shareInstance] getMusicList];
}

@end

@implementation MusicControl

- (id)init
{
    if (self = [super init]) {
        [[MusicControlValue shareInstance] addObserver:self forKeyPath:@"nowState" options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld context:NULL];
        if ([[MusicControlValue shareInstance] playAtLaunch]) {
            [self play];
        }
    }
    return self;
}

+ (MusicControl *)shareMusicControl
{
    if (musicControl == nil) {
        musicControl = [[MusicControl alloc] init];
    }
    return musicControl;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if([keyPath isEqualToString:@"nowState"])
    {
        switch ([[MusicControlValue shareInstance] nowState]) {
            case MusicPlaying:
                if (MusicPause == [[MusicControlValue shareInstance] lastState]) {
                    [self pauseMusic];
                }
                else {
                    [self playMusic];
                }
                break;
                
            case MusicPause:
                [self pauseMusic];
                break;
                
            case MusicStop:
                [self stopMusic];
                break;
                
            default:
                break;
        }
        [[MusicControlValue shareInstance] setLastState:[[MusicControlValue shareInstance] nowState]];
        if ([[[MusicControlValue shareInstance] musicList] count] != 0 || [[MusicControlValue shareInstance] nowState] == MusicStop) [self sendNotification];
    }
    else
    {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

- (void)playOrPause
{
    if ([[MusicControlValue shareInstance] nowState] == MusicPlaying) {
        [self pause];
    }
    else {
        [self play];
    }
}

- (void)play
{
    [[MusicControlValue shareInstance] setNowState:MusicPlaying];
}

- (void)pause
{
    [[MusicControlValue shareInstance] setNowState:MusicPause];
}

- (void)stop
{
    [[MusicControlValue shareInstance] setNowState:MusicStop];
}

- (void)last
{
    [self stop];
    if ([self isFirst]) {
        [self refresh];
        return;
    }
    [[MusicControlValue shareInstance] setPlayIndex:[[MusicControlValue shareInstance] playIndex] - 1];
    [self play];
}

- (void)next
{
    [self stop];
    if ([self isLast]) {
        [self refresh];
        return;
    }
    [[MusicControlValue shareInstance] setPlayIndex:[[MusicControlValue shareInstance] playIndex] + 1];
    [self play];
}

- (void)refresh
{
    [self stop];
    [[MusicControlValue shareInstance] refresh];
    [self play];
}

- (BOOL)isLast
{
    if ([[MusicControlValue shareInstance] playIndex] == [[[MusicControlValue shareInstance] musicList] count]) {
        return YES;
    }
    return NO;
}

- (BOOL)isFirst
{
    if ([[MusicControlValue shareInstance] playIndex] == 0) {
        return YES;
    }
    return NO;
}

- (void)playMusic
{
    [self createStreamer];
    if ([[[MusicControlValue shareInstance] musicList] count] == 0) {
        [self performSelector:@selector(playMusic) withObject:nil afterDelay:0.1];
        //[self removeNotification:[THUserNotification notification]];
    }
    [[[MusicControlValue shareInstance] streamer] start];
}

- (void)pauseMusic
{
    [[[MusicControlValue shareInstance] streamer] pause];
}

- (void)stopMusic
{
    [[[MusicControlValue shareInstance] streamer] stop];
}

#pragma mark -
#pragma mark 初始化播放器

- (void)createStreamer
{
    
	[self destroyStreamer];
    
	NSURL *url = [NSURL URLWithString:[[NSString alloc] initWithFormat:@"%@/%@", ParldWebSite, (NSString*)[[[[MusicControlValue shareInstance] musicList] objectAtIndex:[[MusicControlValue shareInstance] playIndex]] valueForKey:@"url"]]];
	[[MusicControlValue shareInstance] setStreamer:[[AudioStreamer alloc] initWithURL:url]];
	
	[[NSNotificationCenter defaultCenter]
     addObserver:self
     selector:@selector(playbackStateChanged:)
     name:ASStatusChangedNotification
     object:[[MusicControlValue shareInstance] streamer]];
}

- (void)playbackStateChanged:(NSNotification *)aNotification
{
	if ([[[MusicControlValue shareInstance] streamer] isIdle])
	{
        if ([[MusicControlValue shareInstance] nowState] == MusicStop) {
            [self stop];
        }
        else {
            [self next];
        }
	}
    else if ([[[MusicControlValue shareInstance] streamer] isAborted])
    {
        [self stop];
    }
}

- (void)destroyStreamer
{
	if ([[MusicControlValue shareInstance] streamer])
	{
		[[NSNotificationCenter defaultCenter]
         removeObserver:self
         name:ASStatusChangedNotification
         object:[[MusicControlValue shareInstance] streamer]];
		
		[[[MusicControlValue shareInstance] streamer] stop];
		[[MusicControlValue shareInstance] setStreamer:nil];
	}
}

- (void)sendNotification
{
    THUserNotification *notification = [THUserNotification notification];
    notification.title = @"Parld";
    notification.informativeText = [NSString stringWithFormat:@"[%@] %@ - %@", [[MusicControlValue shareInstance] nowState] == MusicPlaying ? NSLocalizedString(@"play", nil) : NSLocalizedString(@"stop", nil), (NSString*)[[[[MusicControlValue shareInstance] musicList] objectAtIndex:[[MusicControlValue shareInstance] playIndex]] valueForKey:@"name"], (NSString*)[[[[MusicControlValue shareInstance] musicList] objectAtIndex:[[MusicControlValue shareInstance] playIndex]] valueForKey:@"artist"]];
    if ([[[ParldInterface shareInstance] musicPic] valueForKey:[[[[MusicControlValue shareInstance] musicList] objectAtIndex:[[MusicControlValue shareInstance] playIndex]] valueForKey:@"hash"]] != nil) {
        //[suspensionView setImage:[[NSImage alloc] initWithData:self.musicpic]];
        notification.contentImage = [[NSImage alloc] initWithData:[[[ParldInterface shareInstance] musicPic] valueForKey:[[[[MusicControlValue shareInstance] musicList] objectAtIndex:[[MusicControlValue shareInstance] playIndex]] valueForKey:@"hash"]]];
    }
    //设置通知提交的时间
    notification.deliveryDate = [NSDate dateWithTimeIntervalSinceNow:1];
    THUserNotificationCenter *center = [THUserNotificationCenter notificationCenter];
    if ([center isKindOfClass:[THUserNotificationCenter class]]) {
        center.centerType = THUserNotificationCenterTypeBanner;
    }
    //删除已经显示过的通知(已经存在用户的通知列表中的)
    [center removeAllDeliveredNotifications];
    //递交通知
    [center deliverNotification:notification];
    //设置通知的代理
    [center setDelegate:self];
    
    [self performSelector:@selector(removeNotification:) withObject:notification afterDelay:5.0];
}

- (void)removeNotification:(NSUserNotification *)notification {
    [[THUserNotificationCenter notificationCenter] removeDeliveredNotification:notification];
}

- (void)userNotificationCenter:(THUserNotificationCenter *)center didActivateNotification:(THUserNotification *)notification {
    //    [self showMainWindow:nil];
}


- (void)userNotificationCenter:(THUserNotificationCenter *)center didDeliverNotification:(THUserNotification *)notification {
    // do nothing
}


- (BOOL)userNotificationCenter:(THUserNotificationCenter *)center shouldPresentNotification:(THUserNotification *)notification {
    return YES;
}


@end
