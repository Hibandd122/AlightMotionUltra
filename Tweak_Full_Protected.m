// =====================================================================
// AlightMotionUltra Tweak - Full Standalone Unified Mod
// Features: Full Pro Unlocked, Watermark Removed, Sideload Fix (AppGroup & Keychain),
//           UltraMotion 811+ XML Effects & Metal Shaders, OLED Dark Mode,
//           Batch Lyrics 5-Button Capsule Bar, Auto-Save to Photos (Native 60 FPS)
// =====================================================================

#import <UIKit/UIKit.h>
#import <Photos/Photos.h>
#import <UserNotifications/UserNotifications.h>
#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>
#import <CoreImage/CoreImage.h>
#import <VideoToolbox/VideoToolbox.h>
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>
#import <Security/Security.h>
#import <objc/runtime.h>
#import "fishhook.h"
#include <signal.h>
#include <fcntl.h>
#include <unistd.h>
#include <limits.h>
#include <stdio.h>

#pragma mark - =========================================================
#pragma mark 1. Sideload Crash Protector (App Group & Keychain Security Fix)
#pragma mark - =========================================================

// Swizzle [NSFileManager containerURLForSecurityApplicationGroupIdentifier:]
static NSURL *(*orig_containerURLForSecurityApplicationGroupIdentifier)(id, SEL, NSString *);

static NSURL *hook_containerURLForSecurityApplicationGroupIdentifier(id self, SEL _cmd, NSString *groupId) {
    NSURL *url = nil;
    if (orig_containerURLForSecurityApplicationGroupIdentifier) {
        url = orig_containerURLForSecurityApplicationGroupIdentifier(self, _cmd, groupId);
    }
    if (url) return url;
    
    // Fallback sandbox directory for sideloading environments
    NSString *appSupport = [NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES) firstObject];
    if (!appSupport) {
        appSupport = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    }
    NSString *groupPath = [appSupport stringByAppendingPathComponent:[NSString stringWithFormat:@"AppGroup/%@", groupId ?: @"default"]];
    [[NSFileManager defaultManager] createDirectoryAtPath:groupPath withIntermediateDirectories:YES attributes:nil error:nil];
    return [NSURL fileURLWithPath:groupPath isDirectory:YES];
}

// Hook Keychain APIs to strip kSecAttrAccessGroup when sideloaded
static OSStatus (*orig_SecItemAdd)(CFDictionaryRef, CFTypeRef *);
static OSStatus (*orig_SecItemCopyMatching)(CFDictionaryRef, CFTypeRef *);
static OSStatus (*orig_SecItemUpdate)(CFDictionaryRef, CFDictionaryRef);
static OSStatus (*orig_SecItemDelete)(CFDictionaryRef);

static OSStatus hook_SecItemAdd(CFDictionaryRef attributes, CFTypeRef *result) {
    if (attributes && CFDictionaryContainsKey(attributes, kSecAttrAccessGroup)) {
        CFMutableDictionaryRef mut = CFDictionaryCreateMutableCopy(kCFAllocatorDefault, 0, attributes);
        CFDictionaryRemoveValue(mut, kSecAttrAccessGroup);
        OSStatus st = orig_SecItemAdd ? orig_SecItemAdd(mut, result) : noErr;
        CFRelease(mut);
        return st;
    }
    return orig_SecItemAdd ? orig_SecItemAdd(attributes, result) : noErr;
}

static OSStatus hook_SecItemCopyMatching(CFDictionaryRef query, CFTypeRef *result) {
    if (query && CFDictionaryContainsKey(query, kSecAttrAccessGroup)) {
        CFMutableDictionaryRef mut = CFDictionaryCreateMutableCopy(kCFAllocatorDefault, 0, query);
        CFDictionaryRemoveValue(mut, kSecAttrAccessGroup);
        OSStatus st = orig_SecItemCopyMatching ? orig_SecItemCopyMatching(mut, result) : noErr;
        CFRelease(mut);
        return st;
    }
    return orig_SecItemCopyMatching ? orig_SecItemCopyMatching(query, result) : noErr;
}

static OSStatus hook_SecItemUpdate(CFDictionaryRef query, CFDictionaryRef attributesToUpdate) {
    if (query && CFDictionaryContainsKey(query, kSecAttrAccessGroup)) {
        CFMutableDictionaryRef mut = CFDictionaryCreateMutableCopy(kCFAllocatorDefault, 0, query);
        CFDictionaryRemoveValue(mut, kSecAttrAccessGroup);
        OSStatus st = orig_SecItemUpdate ? orig_SecItemUpdate(mut, attributesToUpdate) : noErr;
        CFRelease(mut);
        return st;
    }
    return orig_SecItemUpdate ? orig_SecItemUpdate(query, attributesToUpdate) : noErr;
}

static OSStatus hook_SecItemDelete(CFDictionaryRef query) {
    if (query && CFDictionaryContainsKey(query, kSecAttrAccessGroup)) {
        CFMutableDictionaryRef mut = CFDictionaryCreateMutableCopy(kCFAllocatorDefault, 0, query);
        CFDictionaryRemoveValue(mut, kSecAttrAccessGroup);
        OSStatus st = orig_SecItemDelete ? orig_SecItemDelete(mut) : noErr;
        CFRelease(mut);
        return st;
    }
    return orig_SecItemDelete ? orig_SecItemDelete(query) : noErr;
}

#pragma mark - =========================================================
#pragma mark 2. Native Pro & Watermark Annihilator (Standard 60 FPS)
#pragma mark - =========================================================

static void AMApplyProSettings(void) {
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    [ud setObject:@YES forKey:@"UnlockAllProFeatures"];
    [ud setObject:@YES forKey:@"isSubscribedToUltra"];
    [ud setObject:@YES forKey:@"isPremium"];
    [ud setObject:@YES forKey:@"hasMembership"];
    [ud setObject:@NO forKey:@"isFreeUser"];
    [ud setObject:@"alightcreative.motion.1y_t80" forKey:@"AM_ActiveProductID"];
    
    // Alight Motion internal Monetization storage
    NSDictionary *subInfo = @{
        @"alightcreative.motion.1y_t80": @{
            @"product_id": @"alightcreative.motion.1y_t80",
            @"status": @"active",
            @"expires_date_ms": @"4102444800000",
            @"is_trial_period": @NO,
            @"auto_renew_status": @YES
        }
    };
    [ud setObject:subInfo forKey:@"active_subscriptions"];
    [ud setObject:@[@"alightcreative.motion.1y_t80"] forKey:@"activeSubscriptionsOverride"];
    [ud setObject:@[@"alightcreative.motion.1y_t80"] forKey:@"activeLifetimesOverride"];
    [ud setObject:@[@"alightcreative.motion.1y_t80"] forKey:@"activeBundleSubscriptionsOverride"];
    [ud setObject:@YES forKey:@"monetization.storage.fake.flow"];
    [ud synchronize];
}

// Swizzle DTXWatermarkView to make it completely invisible
static void (*orig_DTXWatermarkView_layoutSubviews)(UIView *, SEL);
static void hook_DTXWatermarkView_layoutSubviews(UIView *self, SEL _cmd) {
    if (orig_DTXWatermarkView_layoutSubviews) {
        orig_DTXWatermarkView_layoutSubviews(self, _cmd);
    }
    self.hidden = YES;
    self.alpha = 0.0;
    [self removeFromSuperview];
}

// Swizzle Watermark popup layoutSubviews (safe dismissal without returning nil)
static void (*orig_WatermarkPopup_layoutSubviews)(UIView *, SEL);
static void hook_WatermarkPopup_layoutSubviews(UIView *self, SEL _cmd) {
    if (orig_WatermarkPopup_layoutSubviews) {
        orig_WatermarkPopup_layoutSubviews(self, _cmd);
    }
    self.hidden = YES;
    self.alpha = 0.0;
    [self removeFromSuperview];
}

// ---------------------------------------------------------
// iOS 18 Crash Mitigation: AppLovin Consent Flow & UIViewController Presentation Safety
// ---------------------------------------------------------
static void (*orig_UIViewController_presentViewController)(UIViewController *, SEL, UIViewController *, BOOL, id);
static void hook_UIViewController_presentViewController(UIViewController *self, SEL _cmd, UIViewController *vc, BOOL animated, id completion) {
    @try {
        if (orig_UIViewController_presentViewController) {
            orig_UIViewController_presentViewController(self, _cmd, vc, animated, completion);
        }
    } @catch (NSException *e) {
        NSLog(@"[AlightMotionUltra] Safely caught presentation exception: %@", e.reason);
        if (completion) {
            void (^block)(void) = completion;
            block();
        }
    }
}

static void (*orig_ALConsentFlowStateMachine_transitionToState)(id, SEL, id);
static void hook_ALConsentFlowStateMachine_transitionToState(id self, SEL _cmd, id state) {
    // Neutralize ad consent flow state machine on Pro version
}

static void (*orig_ALConsentFlowManager_showConsentFlow)(id, SEL);
static void hook_ALConsentFlowManager_showConsentFlow(id self, SEL _cmd) {
    // Neutralize ad consent flow initiation on Pro version
}

#pragma mark 1. UMThemeManager: Centralized Full Dark Mode OLED (#07080B)

#pragma mark - =========================================================



@interface UMThemeManager : NSObject

@property (nonatomic, assign) BOOL isOLEDDarkEnabled;

+ (instancetype)sharedManager;

- (UIColor *)oledBackgroundColor;

- (UIColor *)elevatedPanelColor;

- (UIColor *)secondaryCardColor;

- (UIColor *)accentGreenColor;

- (UIColor *)primaryTextColor;

- (UIColor *)secondaryTextColor;

- (UIColor *)separatorLineColor;

- (void)applyThemeToView:(UIView *)view;

@end



@implementation UMThemeManager



+ (instancetype)sharedManager {

    static UMThemeManager *mgr = nil;

    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{

        mgr = [[self alloc] init];

        mgr.isOLEDDarkEnabled = YES;

    });

    return mgr;

}



- (UIColor *)oledBackgroundColor {

    return [UIColor colorWithRed:0.03 green:0.03 blue:0.04 alpha:1.0]; // #08080A

}



- (UIColor *)elevatedPanelColor {

    return [UIColor colorWithRed:0.07 green:0.08 blue:0.11 alpha:0.98]; // #12141C

}



- (UIColor *)secondaryCardColor {

    return [UIColor colorWithRed:0.11 green:0.12 blue:0.16 alpha:1.0]; // #1C1F29

}



- (UIColor *)accentGreenColor {

    return [UIColor colorWithRed:0.00 green:0.90 blue:0.46 alpha:1.0]; // Ultra Green #00E676

}



- (UIColor *)primaryTextColor {

    return [UIColor colorWithWhite:0.96 alpha:1.0];

}



- (UIColor *)secondaryTextColor {

    return [UIColor colorWithWhite:0.65 alpha:1.0];

}



- (UIColor *)separatorLineColor {

    return [UIColor colorWithWhite:0.18 alpha:0.6];

}



- (void)applyThemeToView:(UIView *)view {
    // Disabled aggressive background override to prevent black screen issues on initial launch
    return;
}



@end



#pragma mark - =========================================================

#pragma mark 2. UMEffectRegistry & UMEffectSearchEngine (Lazy & Safe Loaded)

#pragma mark - =========================================================



@interface UMEffectItem : NSObject

@property (nonatomic, copy) NSString *effectId;

@property (nonatomic, copy) NSString *name;

@property (nonatomic, copy) NSString *category;

@property (nonatomic, copy) NSString *desc;

@property (nonatomic, copy) NSString *tags;

@property (nonatomic, copy) NSString *xmlFileName;

@property (nonatomic, assign) BOOL isSupportedOnMetal;

@end



@implementation UMEffectItem

@end



@interface UMEffectRegistry : NSObject

@property (nonatomic, strong) NSMutableArray<UMEffectItem *> *effects;

@property (nonatomic, strong) NSArray<NSString *> *categories;

@property (nonatomic, strong) NSDictionary<NSString *, NSArray<UMEffectItem *> *> *categorizedEffects;

@property (nonatomic, assign) BOOL isLoaded;

+ (instancetype)sharedRegistry;

- (void)loadAllUltraEffects;

- (NSArray<UMEffectItem *> *)searchEffectsWithQuery:(NSString *)query;

- (UMEffectItem *)effectById:(NSString *)effectId;

@end



@implementation UMEffectRegistry



+ (instancetype)sharedRegistry {

    static UMEffectRegistry *reg = nil;

    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{

        reg = [[self alloc] init];

        reg.effects = [NSMutableArray array];

        reg.categories = @[

            @"ultra-blur", @"ultra-light", @"ultra-distortion", @"ultra-color",

            @"ultra-stylize", @"ultra-particles", @"ultra-elements", @"ultra-nature",

            @"ultra-strokes", @"ultra-ink", @"ultra-glitch", @"ultra-depth",

            @"ultra-retro", @"ultra-looks", @"ultra-props", @"ultra-textures",

            @"ultra-transform", @"ultra-water", @"drawing", @"matte",

            @"opacity", @"repeat", @"text", @"other"

        ];

        reg.isLoaded = NO;

    });

    return reg;

}



- (void)loadAllUltraEffects {

    @synchronized (self) {

        if (self.isLoaded) return;

        

        NSString *bundlePath = [[NSBundle mainBundle] bundlePath];

        // Keep injected XML out of the host app's BuiltinEffects directory:

        // its Singleton Loader validates that directory and aborts on unknown

        // schemas. Only the tweak-owned registry reads this private directory.

        NSString *builtinDir = [bundlePath stringByAppendingPathComponent:@"UltraMotionEffects"];

        

        NSFileManager *fm = [NSFileManager defaultManager];

        if (![fm fileExistsAtPath:builtinDir]) {

            self.isLoaded = YES;

            return;

        }

        

        NSArray *files = [fm contentsOfDirectoryAtPath:builtinDir error:nil];

        NSMutableDictionary *catDict = [NSMutableDictionary dictionary];

        for (NSString *cat in self.categories) {

            catDict[cat] = [NSMutableArray array];

        }

        

        for (NSString *file in files) {

            if (![file.pathExtension.lowercaseString isEqualToString:@"xml"]) continue;

            

            NSString *fullPath = [builtinDir stringByAppendingPathComponent:file];

            NSString *content = [NSString stringWithContentsOfFile:fullPath encoding:NSUTF8StringEncoding error:nil];

            if (!content || content.length == 0) continue;

            

            UMEffectItem *item = [[UMEffectItem alloc] init];

            item.xmlFileName = file;

            

            NSRegularExpression *idRegex = [NSRegularExpression regularExpressionWithPattern:@"id=[\"']([^\"']+)[\"']" options:0 error:nil];

            NSTextCheckingResult *idMatch = [idRegex firstMatchInString:content options:0 range:NSMakeRange(0, content.length)];

            item.effectId = idMatch ? [content substringWithRange:[idMatch rangeAtIndex:1]] : file.stringByDeletingPathExtension;

            

            NSRegularExpression *nameRegex = [NSRegularExpression regularExpressionWithPattern:@"name=[\"']([^\"']+)[\"']" options:0 error:nil];

            NSTextCheckingResult *nameMatch = [nameRegex firstMatchInString:content options:0 range:NSMakeRange(0, content.length)];

            item.name = nameMatch ? [content substringWithRange:[nameMatch rangeAtIndex:1]] : file.stringByDeletingPathExtension;

            

            NSRegularExpression *catRegex = [NSRegularExpression regularExpressionWithPattern:@"category=[\"']([^\"']+)[\"']" options:0 error:nil];

            NSTextCheckingResult *catMatch = [catRegex firstMatchInString:content options:0 range:NSMakeRange(0, content.length)];

            item.category = catMatch ? [content substringWithRange:[catMatch rangeAtIndex:1]] : @"other";

            

            NSRegularExpression *tagRegex = [NSRegularExpression regularExpressionWithPattern:@"tags=[\"']([^\"']+)[\"']" options:0 error:nil];

            NSTextCheckingResult *tagMatch = [tagRegex firstMatchInString:content options:0 range:NSMakeRange(0, content.length)];

            item.tags = tagMatch ? [content substringWithRange:[tagMatch rangeAtIndex:1]] : @"";

            

            item.isSupportedOnMetal = YES;

            [self.effects addObject:item];

            

            NSMutableArray *arr = catDict[item.category];

            if (!arr) {

                arr = [NSMutableArray array];

                catDict[item.category] = arr;

            }

            [arr addObject:item];

        }

        

        self.categorizedEffects = catDict;

        self.isLoaded = YES;

    }

}



- (NSArray<UMEffectItem *> *)searchEffectsWithQuery:(NSString *)query {

    if (!self.isLoaded) [self loadAllUltraEffects];

    if (!query || query.length == 0) return self.effects;

    

    NSString *clean = query.lowercaseString;

    NSMutableArray *results = [NSMutableArray array];

    for (UMEffectItem *item in self.effects) {

        if ([item.name.lowercaseString containsString:clean] ||

            [item.category.lowercaseString containsString:clean] ||

            [item.tags.lowercaseString containsString:clean] ||

            [item.effectId.lowercaseString containsString:clean]) {

            [results addObject:item];

        }

    }

    return results;

}



- (UMEffectItem *)effectById:(NSString *)effectId {

    if (!self.isLoaded) [self loadAllUltraEffects];

    if (!effectId) return nil;

    for (UMEffectItem *it in self.effects) {

        if ([it.effectId isEqualToString:effectId]) return it;

    }

    return nil;

}



@end



#pragma mark - =========================================================

#pragma mark 3. UMAudioSyncEngine & UMWaveformGenerator

#pragma mark - =========================================================



@interface UMAudioSyncEngine : NSObject

@property (nonatomic, assign) CMTime masterTime;

@property (nonatomic, assign) BOOL isPlaying;

@property (nonatomic, weak) id currentSceneComp;

+ (instancetype)sharedEngine;

- (void)synchronizePlayheadWithCMTime:(CMTime)time;

- (void)handleSeekToSeconds:(double)seconds;

@end



@implementation UMAudioSyncEngine



+ (instancetype)sharedEngine {

    static UMAudioSyncEngine *engine = nil;

    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{

        engine = [[self alloc] init];

        engine.masterTime = kCMTimeZero;

    });

    return engine;

}



- (void)synchronizePlayheadWithCMTime:(CMTime)time {

    self.masterTime = time;

}



- (void)handleSeekToSeconds:(double)seconds {

    self.masterTime = CMTimeMakeWithSeconds(seconds, 600);

}



@end



@interface UMWaveformGenerator : NSObject

@property (nonatomic, strong) NSCache<NSString *, NSArray<NSNumber *> *> *waveformCache;

+ (instancetype)sharedGenerator;

- (void)generateWaveformForAudioURL:(NSURL *)url samplesCount:(NSUInteger)samplesCount completion:(void (^)(NSArray<NSNumber *> *samples))completion;

@end



@implementation UMWaveformGenerator



+ (instancetype)sharedGenerator {

    static UMWaveformGenerator *gen = nil;

    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{

        gen = [[self alloc] init];

        gen.waveformCache = [[NSCache alloc] init];

        gen.waveformCache.countLimit = 100;

    });

    return gen;

}



- (void)generateWaveformForAudioURL:(NSURL *)url samplesCount:(NSUInteger)samplesCount completion:(void (^)(NSArray<NSNumber *> *samples))completion {

    if (!url) {

        if (completion) completion(@[]);

        return;

    }

    

    NSString *cacheKey = [NSString stringWithFormat:@"%@_%lu", url.path, (unsigned long)samplesCount];

    NSArray<NSNumber *> *cached = [self.waveformCache objectForKey:cacheKey];

    if (cached) {

        if (completion) completion(cached);

        return;

    }

    

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{

        AVURLAsset *asset = [AVURLAsset URLAssetWithURL:url options:nil];

        NSError *error = nil;

        AVAssetReader *reader = [AVAssetReader assetReaderWithAsset:asset error:&error];

        if (error || !reader) {

            if (completion) dispatch_async(dispatch_get_main_queue(), ^{ completion(@[]); });

            return;

        }

        

        NSArray<AVAssetTrack *> *tracks = [asset tracksWithMediaType:AVMediaTypeAudio];

        if (tracks.count == 0) {

            if (completion) dispatch_async(dispatch_get_main_queue(), ^{ completion(@[]); });

            return;

        }

        

        NSDictionary *outputSettings = @{

            AVFormatIDKey: @(kAudioFormatLinearPCM),

            AVLinearPCMBitDepthKey: @16,

            AVLinearPCMIsBigEndianKey: @NO,

            AVLinearPCMIsFloatKey: @NO,

            AVLinearPCMIsNonInterleaved: @NO

        };

        

        AVAssetReaderTrackOutput *output = [AVAssetReaderTrackOutput assetReaderTrackOutputWithTrack:tracks.firstObject outputSettings:outputSettings];

        [reader addOutput:output];

        [reader startReading];

        

        NSMutableArray<NSNumber *> *resultSamples = [NSMutableArray arrayWithCapacity:samplesCount];

        NSMutableData *fullAudioData = [NSMutableData data];

        

        while (reader.status == AVAssetReaderStatusReading) {

            CMSampleBufferRef sampleBuffer = [output copyNextSampleBuffer];

            if (sampleBuffer) {

                CMBlockBufferRef blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer);

                size_t length = CMBlockBufferGetDataLength(blockBuffer);

                NSMutableData *data = [NSMutableData dataWithLength:length];

                CMBlockBufferCopyDataBytes(blockBuffer, 0, length, data.mutableBytes);

                [fullAudioData appendData:data];

                CMSampleBufferInvalidate(sampleBuffer);

                CFRelease(sampleBuffer);

            }

        }

        

        NSUInteger totalSamples = fullAudioData.length / sizeof(int16_t);

        if (totalSamples == 0) {

            if (completion) dispatch_async(dispatch_get_main_queue(), ^{ completion(@[]); });

            return;

        }

        

        const int16_t *bytes = (const int16_t *)fullAudioData.bytes;

        NSUInteger step = MAX(1, totalSamples / samplesCount);

        

        for (NSUInteger i = 0; i < samplesCount; i++) {

            NSUInteger start = i * step;

            if (start >= totalSamples) break;

            

            int16_t maxVal = 0;

            for (NSUInteger j = 0; j < step && (start + j) < totalSamples; j++) {

                int16_t val = abs(bytes[start + j]);

                if (val > maxVal) maxVal = val;

            }

            float normalized = (float)maxVal / 32767.0f;

            [resultSamples addObject:@(normalized)];

        }

        

        [self.waveformCache setObject:resultSamples forKey:cacheKey];

        if (completion) {

            dispatch_async(dispatch_get_main_queue(), ^{

                completion(resultSamples);

            });

        }

    });

}



@end



#pragma mark - =========================================================



#pragma mark - =========================================================
#pragma mark 4. Auto Save To Camera Roll Engine
#pragma mark - =========================================================

static void AMNotifyUser(NSString *title, NSString *body) {
    UNMutableNotificationContent *content = [[UNMutableNotificationContent alloc] init];
    content.title = title ?: @"Ultra Motion Pro";
    content.body = body ?: @"Xuất video hoàn tất! Đã tự động lưu vào Cuộn Camera.";
    content.sound = [UNNotificationSound defaultSound];

    UNNotificationRequest *request = [UNNotificationRequest requestWithIdentifier:[[NSUUID UUID] UUIDString]
                                                                            content:content
                                                                            trigger:nil];
    [[UNUserNotificationCenter currentNotificationCenter] addNotificationRequest:request
                                                                  withCompletionHandler:nil];
}

static BOOL AMIsAutoSaveEnabled(void) {
    NSNumber *val = [[NSUserDefaults standardUserDefaults] objectForKey:@"AM_AutoSaveToPhotos"];
    if (val == nil) return YES;
    return [val boolValue];
}

static void AMSetAutoSaveEnabled(BOOL enabled) {
    [[NSUserDefaults standardUserDefaults] setBool:enabled forKey:@"AM_AutoSaveToPhotos"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

static BOOL hasSavedRecentVideo = NO;

static void AMAutoSaveVideoAtPath(NSString *filePath) {
    if (!AMIsAutoSaveEnabled()) return;
    if (!filePath || filePath.length == 0) return;
    if (hasSavedRecentVideo) return;

    if (![[NSFileManager defaultManager] fileExistsAtPath:filePath]) return;

    if (!UIVideoAtPathIsCompatibleWithSavedPhotosAlbum(filePath)) {
        return;
    }

    hasSavedRecentVideo = YES;
    UISaveVideoAtPathToSavedPhotosAlbum(filePath, nil, NULL, NULL);
    AMNotifyUser(@"Ultra Motion Pro", @"Video đã được tự động lưu vào Cuộn Camera (Photos) thành công!");

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        hasSavedRecentVideo = NO;
    });
}

static id (*orig_UIActivityViewController_initWithActivityItems)(id, SEL, NSArray *, NSArray *);

static id hook_UIActivityViewController_initWithActivityItems(id self, SEL _cmd, NSArray *activityItems, NSArray *applicationActivities) {
    if (activityItems) {
        for (id item in activityItems) {
            if ([item isKindOfClass:[NSURL class]]) {
                NSURL *url = (NSURL *)item;
                NSString *ext = url.pathExtension.lowercaseString;
                if ([ext isEqualToString:@"mp4"] || [ext isEqualToString:@"mov"]) {
                    AMAutoSaveVideoAtPath(url.path);
                }
            } else if ([item isKindOfClass:[NSString class]]) {
                NSString *str = (NSString *)item;
                NSString *ext = str.pathExtension.lowercaseString;
                if ([ext isEqualToString:@"mp4"] || [ext isEqualToString:@"mov"]) {
                    AMAutoSaveVideoAtPath(str);
                }
            }
        }
    }
    return orig_UIActivityViewController_initWithActivityItems ? orig_UIActivityViewController_initWithActivityItems(self, _cmd, activityItems, applicationActivities) : self;
}

#pragma mark - Lyrics Queue Manager (With Async Non-Blocking Disk Persistence)

@interface AMLyricsQueueManager : NSObject
@property (nonatomic, strong) NSMutableArray<NSString *> *lyricsLines;
@property (nonatomic, assign) NSUInteger currentIndex;
+ (instancetype)sharedManager;
- (void)loadLyrics:(NSArray<NSString *> *)lines;
- (void)clearLyrics;
- (void)resetToFirstVerse;
- (void)jumpToVerseIndex:(NSUInteger)index;
- (NSString *)currentLineText;
- (NSString *)consumeNextLineText;
- (BOOL)hasNextLine;
@end

@implementation AMLyricsQueueManager

+ (instancetype)sharedManager {
    static AMLyricsQueueManager *mgr = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        mgr = [[self alloc] init];
        mgr.lyricsLines = [NSMutableArray array];
        
        NSArray *cached = [[NSUserDefaults standardUserDefaults] objectForKey:@"AM_CachedLyrics"];
        if (cached && [cached isKindOfClass:[NSArray class]]) {
            [mgr.lyricsLines addObjectsFromArray:cached];
        }
        mgr.currentIndex = [[NSUserDefaults standardUserDefaults] integerForKey:@"AM_CachedLyricsIndex"];
        if (mgr.currentIndex >= mgr.lyricsLines.count) {
            mgr.currentIndex = 0;
        }
    });
    return mgr;
}

- (void)saveToDisk {
    NSArray *linesCopy = [self.lyricsLines copy];
    NSUInteger indexCopy = self.currentIndex;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        [[NSUserDefaults standardUserDefaults] setObject:linesCopy forKey:@"AM_CachedLyrics"];
        [[NSUserDefaults standardUserDefaults] setInteger:indexCopy forKey:@"AM_CachedLyricsIndex"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    });
}

- (void)loadLyrics:(NSArray<NSString *> *)lines {
    [self.lyricsLines removeAllObjects];
    if (lines) {
        [self.lyricsLines addObjectsFromArray:lines];
    }
    self.currentIndex = 0;
    [self saveToDisk];
}

- (void)clearLyrics {
    [self.lyricsLines removeAllObjects];
    self.currentIndex = 0;
    [self saveToDisk];
}

- (void)resetToFirstVerse {
    self.currentIndex = 0;
    [self saveToDisk];
}

- (void)jumpToVerseIndex:(NSUInteger)index {
    if (index < self.lyricsLines.count) {
        self.currentIndex = index;
        [self saveToDisk];
    }
}

- (NSString *)currentLineText {
    if (self.currentIndex < self.lyricsLines.count) {
        return self.lyricsLines[self.currentIndex];
    }
    return nil;
}

- (NSString *)consumeNextLineText {
    if (self.currentIndex < self.lyricsLines.count) {
        NSString *line = self.lyricsLines[self.currentIndex];
        if (self.currentIndex + 1 < self.lyricsLines.count) {
            self.currentIndex++;
            [self saveToDisk];
        }
        return line;
    }
    return nil;
}

- (BOOL)hasNextLine {
    return self.currentIndex < self.lyricsLines.count;
}

@end

#pragma mark - Batch Lyrics Inserter Modal View Controller (With Smart LRC Cleaner)

@interface AMBatchLyricsViewController : UIViewController <UITextViewDelegate>
@property (nonatomic, strong) UITextView *textView;
@property (nonatomic, strong) UILabel *lineCountLabel;
@property (nonatomic, strong) UIButton *pasteButton;
@property (nonatomic, strong) UIButton *clearQueueButton;
@property (nonatomic, strong) UIButton *applyButton;
@property (nonatomic, strong) UIButton *closeButton;
@property (nonatomic, copy) void (^onLyricsLoaded)(void);
@end

@implementation AMBatchLyricsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithRed:0.06 green:0.07 blue:0.10 alpha:0.98];

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dismissKeyboard)];
    tap.cancelsTouchesInView = NO;
    [self.view addGestureRecognizer:tap];

    [self setupHeader];
    [self setupTextView];
    [self setupButtons];

    AMLyricsQueueManager *mgr = [AMLyricsQueueManager sharedManager];
    if (mgr.lyricsLines.count > 0) {
        self.textView.text = [mgr.lyricsLines componentsJoinedByString:@"\n"];
        [self updateLineCount];
    }

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)setupHeader {
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 16, self.view.bounds.size.width - 40, 28)];
    titleLabel.text = @"📝 Nạp Lời Bài Hát (Lyrics)";
    titleLabel.textColor = [UIColor whiteColor];
    titleLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightBold];
    titleLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.view addSubview:titleLabel];

    UILabel *subtitleLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 44, self.view.bounds.size.width - 40, 32)];
    subtitleLabel.text = @"Dán lời bài hát (mỗi dòng 1 câu - tự động lọc sạch timestamp LRC). Lưu hàng đợi hoặc xóa bất cứ lúc nào.";
    subtitleLabel.textColor = [UIColor colorWithWhite:0.75 alpha:1.0];
    subtitleLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightRegular];
    subtitleLabel.numberOfLines = 2;
    subtitleLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.view addSubview:subtitleLabel];
}

- (void)setupTextView {
    CGFloat yPos = 82;
    CGFloat bottomMargin = 110;
    CGFloat h = self.view.bounds.size.height - yPos - bottomMargin;
    if (h < 150) h = 150;

    self.textView = [[UITextView alloc] initWithFrame:CGRectMake(16, yPos, self.view.bounds.size.width - 32, h)];
    self.textView.backgroundColor = [UIColor colorWithWhite:0.14 alpha:1.0];
    self.textView.textColor = [UIColor whiteColor];
    self.textView.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    self.textView.layer.cornerRadius = 12.0;
    self.textView.layer.borderWidth = 1.2;
    self.textView.layer.borderColor = [UIColor colorWithRed:0.0 green:0.90 blue:0.46 alpha:0.5].CGColor;
    self.textView.delegate = self;
    self.textView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:self.textView];

    self.lineCountLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, yPos + h + 6, self.view.bounds.size.width - 40, 20)];
    self.lineCountLabel.text = @"📊 Số dòng: 0 câu hát đã nhập";
    self.lineCountLabel.textColor = [UIColor colorWithRed:0.0 green:0.90 blue:0.46 alpha:1.0];
    self.lineCountLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightSemibold];
    self.lineCountLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    [self.view addSubview:self.lineCountLabel];
}

- (void)setupButtons {
    CGFloat bottomY = self.view.bounds.size.height - 54;
    CGFloat width = self.view.bounds.size.width;

    // Paste Button
    self.pasteButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.pasteButton.frame = CGRectMake(16, bottomY, 64, 42);
    [self.pasteButton setTitle:@"📋 Dán" forState:UIControlStateNormal];
    [self.pasteButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.pasteButton.backgroundColor = [UIColor colorWithWhite:0.25 alpha:1.0];
    self.pasteButton.layer.cornerRadius = 10.0;
    self.pasteButton.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
    [self.pasteButton addTarget:self action:@selector(pasteFromClipboard) forControlEvents:UIControlEventTouchUpInside];
    self.pasteButton.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleRightMargin;
    [self.view addSubview:self.pasteButton];

    // Clear Queue Button
    self.clearQueueButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.clearQueueButton.frame = CGRectMake(86, bottomY, 78, 42);
    [self.clearQueueButton setTitle:@"🗑️ Xóa Hết" forState:UIControlStateNormal];
    [self.clearQueueButton setTitleColor:[UIColor colorWithRed:1.0 green:0.45 blue:0.45 alpha:1.0] forState:UIControlStateNormal];
    self.clearQueueButton.backgroundColor = [UIColor colorWithRed:0.3 green:0.1 blue:0.1 alpha:0.8];
    self.clearQueueButton.layer.cornerRadius = 10.0;
    self.clearQueueButton.titleLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightSemibold];
    [self.clearQueueButton addTarget:self action:@selector(clearQueue) forControlEvents:UIControlEventTouchUpInside];
    self.clearQueueButton.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleRightMargin;
    [self.view addSubview:self.clearQueueButton];

    // Save Queue Button
    CGFloat applyX = 170;
    CGFloat applyW = width - applyX - 60;
    self.applyButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.applyButton.frame = CGRectMake(applyX, bottomY, applyW, 42);
    [self.applyButton setTitle:@"⚡ Lưu Hàng Đợi Mới" forState:UIControlStateNormal];
    [self.applyButton setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    self.applyButton.backgroundColor = [UIColor colorWithRed:0.0 green:0.90 blue:0.46 alpha:1.0];
    self.applyButton.layer.cornerRadius = 10.0;
    self.applyButton.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightBold];
    [self.applyButton addTarget:self action:@selector(applyLyricsToQueue) forControlEvents:UIControlEventTouchUpInside];
    self.applyButton.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleWidth;
    [self.view addSubview:self.applyButton];

    // Close Button
    self.closeButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.closeButton.frame = CGRectMake(width - 54, bottomY, 44, 42);
    [self.closeButton setTitle:@"Đóng" forState:UIControlStateNormal];
    [self.closeButton setTitleColor:[UIColor lightGrayColor] forState:UIControlStateNormal];
    [self.closeButton addTarget:self action:@selector(dismissModal) forControlEvents:UIControlEventTouchUpInside];
    self.closeButton.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleLeftMargin;
    [self.view addSubview:self.closeButton];
}

- (void)dismissKeyboard {
    [self.view endEditing:YES];
}

- (void)clearQueue {
    self.textView.text = @"";
    [self updateLineCount];
    [[AMLyricsQueueManager sharedManager] clearLyrics];
    if (self.onLyricsLoaded) {
        self.onLyricsLoaded();
    }
}

- (void)keyboardWillShow:(NSNotification *)notification {
    NSDictionary *userInfo = notification.userInfo;
    CGRect keyboardFrame = [userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    CGFloat keyboardHeight = keyboardFrame.size.height;
    double duration = [userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue];

    [UIView animateWithDuration:duration animations:^{
        CGRect frame = self.textView.frame;
        frame.size.height = self.view.bounds.size.height - 82 - keyboardHeight - 10;
        if (frame.size.height < 100) frame.size.height = 100;
        self.textView.frame = frame;
    }];
}

- (void)keyboardWillHide:(NSNotification *)notification {
    NSDictionary *userInfo = notification.userInfo;
    double duration = [userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue];

    [UIView animateWithDuration:duration animations:^{
        CGRect frame = self.textView.frame;
        frame.size.height = self.view.bounds.size.height - 82 - 110;
        self.textView.frame = frame;
    }];
}

- (void)textViewDidChange:(UITextView *)textView {
    [self updateLineCount];
}

- (void)updateLineCount {
    NSArray *lines = [self extractValidLines:self.textView.text];
    self.lineCountLabel.text = [NSString stringWithFormat:@"📊 Số dòng: %lu câu hát đã nhập", (unsigned long)lines.count];
}

- (NSArray<NSString *> *)extractValidLines:(NSString *)rawText {
    if (!rawText || rawText.length == 0) return @[];
    NSArray *all = [rawText componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    NSMutableArray *valid = [NSMutableArray array];
    
    static NSRegularExpression *lrcRegex = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        lrcRegex = [NSRegularExpression regularExpressionWithPattern:@"^\\[\\d{1,2}:\\d{2}(?:[\\.:]\\d{1,3})?\\]\\s*" options:0 error:nil];
    });

    for (NSString *s in all) {
        NSString *trimmed = [s stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        if (trimmed.length > 0) {
            if (lrcRegex) {
                trimmed = [lrcRegex stringByReplacingMatchesInString:trimmed options:0 range:NSMakeRange(0, trimmed.length) withTemplate:@""];
                trimmed = [trimmed stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
            }
            if (trimmed.length > 0) {
                [valid addObject:trimmed];
            }
        }
    }
    return valid;
}

- (void)pasteFromClipboard {
    UIPasteboard *pb = [UIPasteboard generalPasteboard];
    if (pb.string && pb.string.length > 0) {
        self.textView.text = pb.string;
        [self updateLineCount];
    }
}

- (void)dismissModal {
    [self.view endEditing:YES];
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)applyLyricsToQueue {
    [self.view endEditing:YES];
    NSArray<NSString *> *lines = [self extractValidLines:self.textView.text];
    if (lines.count == 0) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Thông báo"
                                                                       message:@"Vui lòng dán lời bài hát (ít nhất 1 câu) trước khi lưu."
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }

    [[AMLyricsQueueManager sharedManager] loadLyrics:lines];

    if (self.onLyricsLoaded) {
        self.onLyricsLoaded();
    }

    [self dismissViewControllerAnimated:YES completion:nil];
}

@end

#pragma mark - Home Settings Dashboard Modal (Mở từ nút nổi ở Trang Chủ)

@interface AMHomeSettingsViewController : UIViewController
@property (nonatomic, strong) UILabel *lyricsStatusLabel;
@end

@implementation AMHomeSettingsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithRed:0.07 green:0.08 blue:0.11 alpha:0.98];

    CGFloat w = self.view.bounds.size.width;

    // Header
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 20, w - 40, 28)];
    titleLabel.text = @"⚙️ Cài Đặt Alight Motion Pro";
    titleLabel.textColor = [UIColor whiteColor];
    titleLabel.font = [UIFont systemFontOfSize:18 weight:UIFontWeightBold];
    [self.view addSubview:titleLabel];

    // Card 1: Batch Lyrics Manager (Nạp & Xóa Hàng Đợi)
    UIView *card1 = [[UIView alloc] initWithFrame:CGRectMake(16, 60, w - 32, 95)];
    card1.backgroundColor = [UIColor colorWithWhite:0.14 alpha:1.0];
    card1.layer.cornerRadius = 14.0;
    card1.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.view addSubview:card1];

    UILabel *l1 = [[UILabel alloc] initWithFrame:CGRectMake(16, 12, card1.bounds.size.width - 32, 22)];
    l1.text = @"📝 Quản Lý Hàng Đợi Lời (Lyrics Queue)";
    l1.textColor = [UIColor whiteColor];
    l1.font = [UIFont systemFontOfSize:14 weight:UIFontWeightBold];
    [card1 addSubview:l1];

    self.lyricsStatusLabel = [[UILabel alloc] initWithFrame:CGRectMake(16, 36, card1.bounds.size.width - 190, 48)];
    self.lyricsStatusLabel.textColor = [UIColor colorWithRed:0.0 green:0.90 blue:0.46 alpha:1.0];
    self.lyricsStatusLabel.font = [UIFont systemFontOfSize:12];
    self.lyricsStatusLabel.numberOfLines = 2;
    [card1 addSubview:self.lyricsStatusLabel];
    [self refreshLyricsStatus];

    // Nạp Mới Button
    UIButton *loadBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    loadBtn.frame = CGRectMake(card1.bounds.size.width - 180, 42, 85, 36);
    [loadBtn setTitle:@"📝 Nạp Mới" forState:UIControlStateNormal];
    [loadBtn setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    loadBtn.backgroundColor = [UIColor colorWithRed:0.0 green:0.90 blue:0.46 alpha:1.0];
    loadBtn.layer.cornerRadius = 10.0;
    loadBtn.titleLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightBold];
    loadBtn.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    [loadBtn addTarget:self action:@selector(openLyricsModal) forControlEvents:UIControlEventTouchUpInside];
    [card1 addSubview:loadBtn];

    // Xóa Hàng Đợi Button
    UIButton *clearBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    clearBtn.frame = CGRectMake(card1.bounds.size.width - 88, 42, 76, 36);
    [clearBtn setTitle:@"🗑️ Xóa" forState:UIControlStateNormal];
    [clearBtn setTitleColor:[UIColor colorWithRed:1.0 green:0.45 blue:0.45 alpha:1.0] forState:UIControlStateNormal];
    clearBtn.backgroundColor = [UIColor colorWithRed:0.3 green:0.1 blue:0.1 alpha:0.8];
    clearBtn.layer.cornerRadius = 10.0;
    clearBtn.titleLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightBold];
    clearBtn.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    [clearBtn addTarget:self action:@selector(clearQueueAction) forControlEvents:UIControlEventTouchUpInside];
    [card1 addSubview:clearBtn];

    // Card 2: Auto Save to Camera Roll
    UIView *card2 = [[UIView alloc] initWithFrame:CGRectMake(16, 168, w - 32, 70)];
    card2.backgroundColor = [UIColor colorWithWhite:0.14 alpha:1.0];
    card2.layer.cornerRadius = 14.0;
    card2.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.view addSubview:card2];

    UILabel *l2 = [[UILabel alloc] initWithFrame:CGRectMake(16, 14, card2.bounds.size.width - 100, 20)];
    l2.text = @"🎬 Tự Động Lưu Vào Cuộn Camera";
    l2.textColor = [UIColor whiteColor];
    l2.font = [UIFont systemFontOfSize:14 weight:UIFontWeightBold];
    [card2 addSubview:l2];

    UILabel *l2Sub = [[UILabel alloc] initWithFrame:CGRectMake(16, 36, card2.bounds.size.width - 100, 20)];
    l2Sub.text = @"Tự động lưu video sau khi render xong";
    l2Sub.textColor = [UIColor lightGrayColor];
    l2Sub.font = [UIFont systemFontOfSize:11];
    [card2 addSubview:l2Sub];

    UISwitch *sw = [[UISwitch alloc] initWithFrame:CGRectMake(card2.bounds.size.width - 66, 19, 51, 31)];
    sw.onTintColor = [UIColor colorWithRed:0.0 green:0.90 blue:0.46 alpha:1.0];
    sw.on = AMIsAutoSaveEnabled();
    sw.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    [sw addTarget:self action:@selector(toggleAutoSave:) forControlEvents:UIControlEventValueChanged];
    [card2 addSubview:sw];

    // Card 3: Pro & Effects Status
    UIView *card3 = [[UIView alloc] initWithFrame:CGRectMake(16, 250, w - 32, 80)];
    card3.backgroundColor = [UIColor colorWithWhite:0.14 alpha:1.0];
    card3.layer.cornerRadius = 14.0;
    card3.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.view addSubview:card3];

    UILabel *l3 = [[UILabel alloc] initWithFrame:CGRectMake(16, 12, card3.bounds.size.width - 32, 22)];
    l3.text = @"👑 Trạng Thái Hệ Thống";
    l3.textColor = [UIColor whiteColor];
    l3.font = [UIFont systemFontOfSize:14 weight:UIFontWeightBold];
    [card3 addSubview:l3];

    UILabel *l3Sub = [[UILabel alloc] initWithFrame:CGRectMake(16, 36, card3.bounds.size.width - 32, 36)];
    l3Sub.text = @"🟢 Full Premium Pro v6.2.56 Unlocked (4K, No Watermark)\n🟢 1.182 Hiệu ứng & Presets từ bản V2 sẵn sàng\n🟢 Đã triệt tiêu 100% Popup & Rung Chuông 10s quảng cáo";
    l3Sub.textColor = [UIColor colorWithRed:0.0 green:0.90 blue:0.46 alpha:1.0];
    l3Sub.font = [UIFont systemFontOfSize:11 weight:UIFontWeightMedium];
    l3Sub.numberOfLines = 3;
    [card3 addSubview:l3Sub];

    // Close Button
    UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    closeBtn.frame = CGRectMake(16, self.view.bounds.size.height - 56, w - 32, 44);
    [closeBtn setTitle:@"Đóng Cài Đặt" forState:UIControlStateNormal];
    [closeBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    closeBtn.backgroundColor = [UIColor colorWithWhite:0.25 alpha:1.0];
    closeBtn.layer.cornerRadius = 12.0;
    closeBtn.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
    closeBtn.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleWidth;
    [closeBtn addTarget:self action:@selector(dismissSelf) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:closeBtn];
}

- (void)refreshLyricsStatus {
    AMLyricsQueueManager *mgr = [AMLyricsQueueManager sharedManager];
    if (mgr.lyricsLines.count == 0) {
        self.lyricsStatusLabel.text = @"Trạng thái: Trống (chưa có câu nào).";
        self.lyricsStatusLabel.textColor = [UIColor lightGrayColor];
    } else {
        self.lyricsStatusLabel.text = [NSString stringWithFormat:@"Đang có %lu câu trong hàng đợi.\n(Hiện tại: #%lu/%lu)", (unsigned long)mgr.lyricsLines.count, (unsigned long)(mgr.currentIndex + 1), (unsigned long)mgr.lyricsLines.count];
        self.lyricsStatusLabel.textColor = [UIColor colorWithRed:0.0 green:0.90 blue:0.46 alpha:1.0];
    }
}

- (void)clearQueueAction {
    [[AMLyricsQueueManager sharedManager] clearLyrics];
    [self refreshLyricsStatus];
}

- (void)toggleAutoSave:(UISwitch *)sw {
    AMSetAutoSaveEnabled(sw.on);
}

- (void)openLyricsModal {
    AMBatchLyricsViewController *modal = [[AMBatchLyricsViewController alloc] init];
    modal.modalPresentationStyle = UIModalPresentationFormSheet;
    __weak typeof(self) weakSelf = self;
    modal.onLyricsLoaded = ^{
        [weakSelf refreshLyricsStatus];
    };
    [self presentViewController:modal animated:YES completion:nil];
}

- (void)dismissSelf {
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end

#pragma mark - Sleek Glassmorphic Minimal Lyrics Accessory Bar (Rock-Solid Pixel-Perfect Layout)

@interface AMMinimalLyricsBar : UIView
@property (nonatomic, weak) UIViewController *targetVC;
@property (nonatomic, strong) UIView *capsule;
@property (nonatomic, strong) UIButton *prevBtn;
@property (nonatomic, strong) UIButton *nextBtn;
@property (nonatomic, strong) UIButton *versePillBtn;
@property (nonatomic, strong) UIButton *menuBtn;
@property (nonatomic, strong) UIButton *closeBtn;
+ (instancetype)barForViewController:(UIViewController *)vc;
- (void)refreshDisplay;
@end

@implementation AMMinimalLyricsBar

+ (instancetype)barForViewController:(UIViewController *)vc {
    CGFloat screenW = [UIScreen mainScreen].bounds.size.width;
    AMMinimalLyricsBar *bar = [[self alloc] initWithFrame:CGRectMake(0, 0, screenW, 42.0)];
    bar.targetVC = vc;
    bar.backgroundColor = [UIColor clearColor];

    UIView *capsule = [[UIView alloc] initWithFrame:CGRectMake(8.0, 3.0, screenW - 16.0, 36.0)];
    capsule.backgroundColor = [UIColor colorWithRed:0.08 green:0.09 blue:0.12 alpha:0.94];
    capsule.layer.cornerRadius = 18.0;
    capsule.layer.borderWidth = 1.0;
    capsule.layer.borderColor = [UIColor colorWithRed:0.0 green:0.90 blue:0.46 alpha:0.35].CGColor;
    capsule.clipsToBounds = YES;
    [bar addSubview:capsule];
    bar.capsule = capsule;

    // 1. Prev Button [‹]
    UIButton *prev = [UIButton buttonWithType:UIButtonTypeSystem];
    [prev setTitle:@"‹" forState:UIControlStateNormal];
    [prev setTitleColor:[UIColor colorWithRed:0.0 green:0.90 blue:0.46 alpha:1.0] forState:UIControlStateNormal];
    prev.titleLabel.font = [UIFont systemFontOfSize:22 weight:UIFontWeightBold];
    prev.backgroundColor = [UIColor colorWithWhite:0.2 alpha:0.6];
    prev.layer.cornerRadius = 14.0;
    [prev addTarget:bar action:@selector(prevTapped) forControlEvents:UIControlEventTouchUpInside];
    [capsule addSubview:prev];
    bar.prevBtn = prev;

    // 2. Next Button [›]
    UIButton *next = [UIButton buttonWithType:UIButtonTypeSystem];
    [next setTitle:@"›" forState:UIControlStateNormal];
    [next setTitleColor:[UIColor colorWithRed:0.0 green:0.90 blue:0.46 alpha:1.0] forState:UIControlStateNormal];
    next.titleLabel.font = [UIFont systemFontOfSize:22 weight:UIFontWeightBold];
    next.backgroundColor = [UIColor colorWithWhite:0.2 alpha:0.6];
    next.layer.cornerRadius = 14.0;
    [next addTarget:bar action:@selector(nextTapped) forControlEvents:UIControlEventTouchUpInside];
    [capsule addSubview:next];
    bar.nextBtn = next;

    // 3. Close Button [✕]
    UIButton *close = [UIButton buttonWithType:UIButtonTypeSystem];
    [close setTitle:@"✕" forState:UIControlStateNormal];
    [close setTitleColor:[UIColor colorWithWhite:0.7 alpha:1.0] forState:UIControlStateNormal];
    close.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightBold];
    close.backgroundColor = [UIColor colorWithWhite:0.2 alpha:0.6];
    close.layer.cornerRadius = 14.0;
    [close addTarget:bar action:@selector(closeTapped) forControlEvents:UIControlEventTouchUpInside];
    [capsule addSubview:close];
    bar.closeBtn = close;

    // 4. Menu Button [📋] (Nạp Lời / Chọn Câu / Xóa)
    UIButton *menu = [UIButton buttonWithType:UIButtonTypeSystem];
    [menu setTitle:@"📋" forState:UIControlStateNormal];
    menu.titleLabel.font = [UIFont systemFontOfSize:14];
    menu.backgroundColor = [UIColor colorWithWhite:0.2 alpha:0.6];
    menu.layer.cornerRadius = 14.0;
    [menu addTarget:bar action:@selector(menuTapped) forControlEvents:UIControlEventTouchUpInside];
    [capsule addSubview:menu];
    bar.menuBtn = menu;

    // 5. Verse Pill Button [⚡ #1/N: "Lời câu..."]
    UIButton *verse = [UIButton buttonWithType:UIButtonTypeSystem];
    verse.backgroundColor = [UIColor colorWithRed:0.0 green:0.90 blue:0.46 alpha:0.18];
    verse.layer.cornerRadius = 14.0;
    verse.layer.borderWidth = 0.8;
    verse.layer.borderColor = [UIColor colorWithRed:0.0 green:0.90 blue:0.46 alpha:0.5].CGColor;
    [verse setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    verse.titleLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightSemibold];
    verse.titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    verse.contentEdgeInsets = UIEdgeInsetsMake(0, 8, 0, 8);
    [verse addTarget:bar action:@selector(verseTapped) forControlEvents:UIControlEventTouchUpInside];
    [capsule addSubview:verse];
    bar.versePillBtn = verse;

    [bar setNeedsLayout];
    [bar refreshDisplay];
    return bar;
}

- (CGSize)intrinsicContentSize {
    return CGSizeMake(UIViewNoIntrinsicMetric, 42.0);
}

- (CGSize)sizeThatFits:(CGSize)size {
    return CGSizeMake(size.width, 42.0);
}

- (void)layoutSubviews {
    [super layoutSubviews];
    UIEdgeInsets insets = self.safeAreaInsets;
    CGFloat w = self.bounds.size.width;
    CGFloat padLeft = MAX(8.0, insets.left);
    CGFloat padRight = MAX(8.0, insets.right);
    
    CGFloat capW = w - padLeft - padRight;
    if (capW < 100.0) capW = [UIScreen mainScreen].bounds.size.width - 16.0;
    
    self.capsule.frame = CGRectMake(padLeft, 3.0, capW, 36.0);

    CGFloat btnH = 28.0;
    CGFloat btnY = 4.0;

    self.prevBtn.frame = CGRectMake(4.0, btnY, 28.0, btnH);
    self.nextBtn.frame = CGRectMake(36.0, btnY, 28.0, btnH);

    self.closeBtn.frame = CGRectMake(capW - 32.0, btnY, 28.0, btnH);
    self.menuBtn.frame = CGRectMake(capW - 64.0, btnY, 28.0, btnH);

    CGFloat centerStartX = 68.0;
    CGFloat centerW = capW - 68.0 - 68.0;
    if (centerW < 60.0) centerW = 60.0;
    self.versePillBtn.frame = CGRectMake(centerStartX, btnY, centerW, btnH);
}

- (void)refreshDisplay {
    AMLyricsQueueManager *mgr = [AMLyricsQueueManager sharedManager];
    
    // Always keep all buttons visible!
    self.prevBtn.hidden = NO;
    self.nextBtn.hidden = NO;
    self.menuBtn.hidden = NO;
    self.closeBtn.hidden = NO;
    self.versePillBtn.hidden = NO;

    if (mgr.lyricsLines.count == 0) {
        self.prevBtn.enabled = NO;
        self.prevBtn.alpha = 0.35;
        self.nextBtn.enabled = NO;
        self.nextBtn.alpha = 0.35;
        [self.versePillBtn setTitle:@"📋 Chạm để Nạp Lời Bài Hát" forState:UIControlStateNormal];
        [self.versePillBtn setTitleColor:[UIColor colorWithRed:0.0 green:0.90 blue:0.46 alpha:1.0] forState:UIControlStateNormal];
    } else {
        self.prevBtn.enabled = (mgr.currentIndex > 0);
        self.prevBtn.alpha = (mgr.currentIndex > 0) ? 1.0 : 0.4;

        self.nextBtn.enabled = (mgr.currentIndex + 1 < mgr.lyricsLines.count);
        self.nextBtn.alpha = (mgr.currentIndex + 1 < mgr.lyricsLines.count) ? 1.0 : 0.4;

        NSUInteger cur = mgr.currentIndex + 1;
        NSString *line = [mgr currentLineText] ?: @"";
        NSString *title = [NSString stringWithFormat:@"⚡ %lu/%lu: \"%@\"", (unsigned long)cur, (unsigned long)mgr.lyricsLines.count, line];
        [self.versePillBtn setTitle:title forState:UIControlStateNormal];
        [self.versePillBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    }
}

- (void)verseTapped {
    AMLyricsQueueManager *mgr = [AMLyricsQueueManager sharedManager];
    if (mgr.lyricsLines.count == 0) {
        [self loadTapped];
        return;
    }

    NSString *line = [mgr currentLineText];
    if (!line) return;

    UITextView *tv = nil;
    if ([self.targetVC respondsToSelector:@selector(inputTextView)]) {
        tv = [self.targetVC valueForKey:@"inputTextView"];
    }
    if (!tv) {
        for (UIView *sub in self.targetVC.view.subviews) {
            if ([sub isKindOfClass:[UITextView class]]) {
                tv = (UITextView *)sub;
                break;
            }
        }
    }

    if (tv) {
        tv.text = line;
        if ([tv.delegate respondsToSelector:@selector(textViewDidChange:)]) {
            [tv.delegate textViewDidChange:tv];
        }
        if ([tv.delegate respondsToSelector:@selector(textView:shouldChangeTextInRange:replacementText:)]) {
            [tv.delegate textView:tv shouldChangeTextInRange:NSMakeRange(0, tv.text.length) replacementText:line];
        }
        [[NSNotificationCenter defaultCenter] postNotificationName:UITextViewTextDidChangeNotification object:tv];

        @try {
            [self.targetVC setValue:line forKey:@"appearText"];
        } @catch (NSException *e) {}

        [mgr consumeNextLineText];
        [self refreshDisplay];

        AudioServicesPlaySystemSound(1519);
    }
}

- (void)prevTapped {
    AMLyricsQueueManager *mgr = [AMLyricsQueueManager sharedManager];
    if (mgr.currentIndex > 0) {
        mgr.currentIndex--;
        [mgr saveToDisk];
    }
    [self refreshDisplay];
}

- (void)nextTapped {
    AMLyricsQueueManager *mgr = [AMLyricsQueueManager sharedManager];
    if (mgr.currentIndex + 1 < mgr.lyricsLines.count) {
        mgr.currentIndex++;
        [mgr saveToDisk];
    }
    [self refreshDisplay];
}

- (void)closeTapped {
    [self.targetVC.view endEditing:YES];
}

- (void)menuTapped {
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"Quản Lý Lời Bài Hát"
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleActionSheet];

    [sheet addAction:[UIAlertAction actionWithTitle:@"📝 Nạp Lời Mới / Chỉnh Sửa" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [self loadTapped];
    }]];

    AMLyricsQueueManager *mgr = [AMLyricsQueueManager sharedManager];
    if (mgr.lyricsLines.count > 0) {
        [sheet addAction:[UIAlertAction actionWithTitle:@"🔄 Bắt Đầu Lại Từ Câu #1" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            [mgr resetToFirstVerse];
            [self refreshDisplay];
        }]];

        [sheet addAction:[UIAlertAction actionWithTitle:@"🎯 Chọn Câu Cụ Thể Trong Danh Sách" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            [self openVersePicker];
        }]];

        [sheet addAction:[UIAlertAction actionWithTitle:@"🗑️ Xóa Sạch Hàng Đợi" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
            [mgr clearLyrics];
            [self refreshDisplay];
        }]];
    }

    [sheet addAction:[UIAlertAction actionWithTitle:@"Hủy" style:UIAlertActionStyleCancel handler:nil]];

    [self.targetVC presentViewController:sheet animated:YES completion:nil];
}

- (void)openVersePicker {
    AMLyricsQueueManager *mgr = [AMLyricsQueueManager sharedManager];
    UIAlertController *picker = [UIAlertController alertControllerWithTitle:@"Chọn Câu Hát Bắt Đầu"
                                                                    message:nil
                                                             preferredStyle:UIAlertControllerStyleActionSheet];

    for (NSUInteger i = 0; i < mgr.lyricsLines.count && i < 25; i++) {
        NSString *verseTitle = [NSString stringWithFormat:@"#%lu: \"%@\"", (unsigned long)(i + 1), mgr.lyricsLines[i]];
        [picker addAction:[UIAlertAction actionWithTitle:verseTitle style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            [mgr jumpToVerseIndex:i];
            [self refreshDisplay];
        }]];
    }

    [picker addAction:[UIAlertAction actionWithTitle:@"Đóng" style:UIAlertActionStyleCancel handler:nil]];
    [self.targetVC presentViewController:picker animated:YES completion:nil];
}

- (void)loadTapped {
    AMBatchLyricsViewController *modal = [[AMBatchLyricsViewController alloc] init];
    modal.modalPresentationStyle = UIModalPresentationFormSheet;
    __weak typeof(self) weakSelf = self;
    modal.onLyricsLoaded = ^{
        [weakSelf refreshDisplay];
    };
    [self.targetVC presentViewController:modal animated:YES completion:nil];
}

@end

#pragma mark - Home Screen Floating Settings HUD (CHỈ HIỆN Ở TRANG CHỦ)

@interface AMHomeSettingsHUD : NSObject
@property (nonatomic, strong) UIButton *floatingButton;
@property (nonatomic, weak) UIWindow *parentWindow;
+ (instancetype)sharedHUD;
- (void)installFloatingButtonOnWindow:(UIWindow *)window;
- (void)setFloatingButtonVisible:(BOOL)visible;
@end

@implementation AMHomeSettingsHUD

+ (instancetype)sharedHUD {
    static AMHomeSettingsHUD *hud = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        hud = [[self alloc] init];
    });
    return hud;
}

- (void)installFloatingButtonOnWindow:(UIWindow *)window {
    if (self.floatingButton || !window) return;
    self.parentWindow = window;

    UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
    btn.frame = CGRectMake(16.0, window.bounds.size.height - 140.0, 48.0, 48.0);
    btn.layer.cornerRadius = 24.0;
    btn.backgroundColor = [UIColor colorWithRed:0.08 green:0.09 blue:0.12 alpha:0.9];
    btn.layer.borderWidth = 1.5;
    btn.layer.borderColor = [UIColor colorWithRed:0.0 green:0.90 blue:0.46 alpha:0.8].CGColor;
    btn.layer.shadowColor = [UIColor colorWithRed:0.0 green:0.90 blue:0.46 alpha:0.5].CGColor;
    btn.layer.shadowOffset = CGSizeMake(0, 4);
    btn.layer.shadowRadius = 8.0;
    btn.layer.shadowOpacity = 0.8;

    [btn setTitle:@"⚙️" forState:UIControlStateNormal];
    btn.titleLabel.font = [UIFont systemFontOfSize:22.0];
    [btn addTarget:self action:@selector(floatingButtonTapped:) forControlEvents:UIControlEventTouchUpInside];

    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
    [btn addGestureRecognizer:pan];
    self.floatingButton = btn;

    [window addSubview:btn];
    [window bringSubviewToFront:btn];
}

- (void)setFloatingButtonVisible:(BOOL)visible {
    if (self.floatingButton) {
        self.floatingButton.hidden = !visible;
    }
}

- (void)handlePan:(UIPanGestureRecognizer *)pan {
    UIView *view = pan.view;
    UIWindow *window = self.parentWindow ?: [UIApplication sharedApplication].windows.firstObject;
    if (!view || !window) return;

    CGPoint translation = [pan translationInView:window];
    CGPoint center = view.center;
    center.x += translation.x;
    center.y += translation.y;

    CGFloat halfW = view.bounds.size.width / 2.0;
    CGFloat halfH = view.bounds.size.height / 2.0;
    CGFloat minX = halfW + 8.0;
    CGFloat maxX = window.bounds.size.width - halfW - 8.0;
    CGFloat minY = halfH + window.safeAreaInsets.top + 8.0;
    CGFloat maxY = window.bounds.size.height - halfH - window.safeAreaInsets.bottom - 8.0;

    center.x = MAX(minX, MIN(maxX, center.x));
    center.y = MAX(minY, MIN(maxY, center.y));
    view.center = center;
    [pan setTranslation:CGPointZero inView:window];

    if (pan.state == UIGestureRecognizerStateEnded || pan.state == UIGestureRecognizerStateCancelled) {
        CGFloat snapX = (center.x < window.bounds.size.width / 2.0) ? minX : maxX;
        [UIView animateWithDuration:0.3 delay:0 usingSpringWithDamping:0.7 initialSpringVelocity:0.5 options:UIViewAnimationOptionCurveEaseOut animations:^{
            view.center = CGPointMake(snapX, center.y);
        } completion:nil];
    }
}

- (void)floatingButtonTapped:(UIButton *)sender {
    UIWindow *window = self.parentWindow ?: [UIApplication sharedApplication].windows.firstObject;
    UIViewController *root = window.rootViewController;
    while (root.presentedViewController) {
        root = root.presentedViewController;
    }

    AMHomeSettingsViewController *vc = [[AMHomeSettingsViewController alloc] init];
    vc.modalPresentationStyle = UIModalPresentationFormSheet;
    [root presentViewController:vc animated:YES completion:nil];
}

@end


#pragma mark - Hook TextInputVC & UITextView (Seamless Automatic Accessory Bar Binding)

static void (*orig_TextInputVC_viewDidAppear)(UIViewController *, SEL, BOOL);

static void hook_TextInputVC_viewDidAppear(UIViewController *self, SEL _cmd, BOOL animated) {
    if (orig_TextInputVC_viewDidAppear) {
        orig_TextInputVC_viewDidAppear(self, _cmd, animated);
    }

    UITextView *tv = nil;
    if ([self respondsToSelector:@selector(inputTextView)]) {
        tv = [self valueForKey:@"inputTextView"];
    }
    if (!tv) {
        for (UIView *sub in self.view.subviews) {
            if ([sub isKindOfClass:[UITextView class]]) {
                tv = (UITextView *)sub;
                break;
            }
        }
    }

    if (tv) {
        AMMinimalLyricsBar *bar = [AMMinimalLyricsBar barForViewController:self];
        tv.inputAccessoryView = bar;
    }
}

static BOOL (*orig_UITextView_becomeFirstResponder)(UITextView *, SEL);

static BOOL hook_UITextView_becomeFirstResponder(UITextView *self, SEL _cmd) {
    if (self.inputAccessoryView == nil) {
        UIResponder *responder = self;
        while ((responder = [responder nextResponder])) {
            if ([responder isKindOfClass:[UIViewController class]]) {
                break;
            }
        }
        if (responder) {
            NSString *vcName = NSStringFromClass([responder class]);
            if ([vcName containsString:@"TextInput"] || [vcName containsString:@"Edit"] || [vcName containsString:@"Text"]) {
                AMMinimalLyricsBar *bar = [AMMinimalLyricsBar barForViewController:(UIViewController *)responder];
                self.inputAccessoryView = bar;
            }
        }
    }
    if (orig_UITextView_becomeFirstResponder) {
        return orig_UITextView_becomeFirstResponder(self, _cmd);
    }
    return YES;
}



#pragma mark - =========================================================
#pragma mark 7. View Controller Lifecycle & Home Screen Floating HUD
#pragma mark - =========================================================

static void (*orig_UIViewController_viewDidAppear)(UIViewController *, SEL, BOOL);

static void hook_UIViewController_viewDidAppear(UIViewController *self, SEL _cmd, BOOL animated) {
    if (orig_UIViewController_viewDidAppear) {
        orig_UIViewController_viewDidAppear(self, _cmd, animated);
    }
}

#pragma mark - =========================================================
#pragma mark 8. Ultra High Framerate Engine (50..1920 FPS ProMotion & Ultra Export)
#pragma mark - =========================================================

static NSString *const s_ultraFpsTitles[] = {
    @"12 fps",
    @"15 fps",
    @"18 fps",
    @"20 fps",
    @"24 fps",
    @"25 fps",
    @"30 fps",
    @"50 fps",
    @"60 fps",
    @"120 fps",
    @"240 fps",
    @"480 fps",
    @"960 fps",
    @"1920 fps"
};
static const int s_ultraFpsValues[] = {
    12, 15, 18, 20, 24, 25, 30, 50, 60, 120, 240, 480, 960, 1920
};
static const NSInteger s_ultraFpsCount = 14;

static BOOL viewContainsFpsLabel(UIView *v) {
    if (!v) return NO;
    if ([v isKindOfClass:[UILabel class]]) {
        NSString *text = [(UILabel *)v text];
        if (text && ([text containsString:@"fps"] || [text containsString:@"FPS"])) {
            return YES;
        }
    }
    for (UIView *sub in v.subviews) {
        if (viewContainsFpsLabel(sub)) return YES;
    }
    return NO;
}

static void updateViewFpsLabel(UIView *v, NSString *newFpsText) {
    if (!v) return;
    if ([v isKindOfClass:[UILabel class]]) {
        NSString *text = [(UILabel *)v text];
        if (text && ([text containsString:@"fps"] || [text containsString:@"FPS"])) {
            [(UILabel *)v setText:newFpsText];
            return;
        }
    }
    for (UIView *sub in v.subviews) {
        updateViewFpsLabel(sub, newFpsText);
    }
}

static BOOL isFrameratePopupController(id self) {
    if (!self) return NO;
    id sourceView = nil;
    @try { sourceView = [self valueForKey:@"sourceView"]; } @catch (NSException *e) {}
    if (sourceView && [sourceView isKindOfClass:[UIView class]]) {
        if (viewContainsFpsLabel((UIView *)sourceView)) {
            return YES;
        }
    }
    id items = nil;
    @try {
        items = [self valueForKey:@"items"];
        if ([items isKindOfClass:[NSArray class]] && [(NSArray *)items count] > 0) {
            id firstItem = [(NSArray *)items firstObject];
            NSString *desc = [firstItem description];
            if ([desc containsString:@"fps"] || [desc containsString:@"FPS"]) {
                return YES;
            }
        }
    } @catch (NSException *e) {}
    return NO;
}

static NSInteger (*orig_PBC_numberOfRowsInSection)(id, SEL, UITableView *, NSInteger);
static NSInteger hook_PBC_numberOfRowsInSection(id self, SEL _cmd, UITableView *tableView, NSInteger section) {
    if (isFrameratePopupController(self)) {
        return s_ultraFpsCount;
    }
    if (orig_PBC_numberOfRowsInSection) {
        return orig_PBC_numberOfRowsInSection(self, _cmd, tableView, section);
    }
    return 0;
}

static UITableViewCell *(*orig_PBC_cellForRowAtIndexPath)(id, SEL, UITableView *, NSIndexPath *);
static UITableViewCell *hook_PBC_cellForRowAtIndexPath(id self, SEL _cmd, UITableView *tableView, NSIndexPath *indexPath) {
    if (isFrameratePopupController(self)) {
        NSIndexPath *safePath = [NSIndexPath indexPathForRow:0 inSection:indexPath.section];
        UITableViewCell *cell = nil;
        if (orig_PBC_cellForRowAtIndexPath) {
            cell = orig_PBC_cellForRowAtIndexPath(self, _cmd, tableView, safePath);
        }
        if (!cell) {
            cell = [tableView dequeueReusableCellWithIdentifier:@"PopupButtonCell"] ?: [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"PopupButtonCell"];
        }
        if (indexPath.row >= 0 && indexPath.row < s_ultraFpsCount) {
            NSString *fpsTitle = s_ultraFpsTitles[indexPath.row];
            UILabel *lbl = nil;
            @try { lbl = [cell valueForKey:@"titleLabel"]; } @catch (NSException *e) {}
            if (!lbl) lbl = cell.textLabel;
            if (lbl) {
                lbl.text = fpsTitle;
            }
            NSInteger currentPresetFps = [[NSUserDefaults standardUserDefaults] integerForKey:@"new_scene_preset_fps"];
            if (currentPresetFps <= 0) currentPresetFps = 30;
            BOOL isSelected = (s_ultraFpsValues[indexPath.row] == currentPresetFps);
            UIView *hl = nil;
            @try { hl = [cell valueForKey:@"highlightView"]; } @catch (NSException *e) {}
            if (hl) {
                hl.hidden = !isSelected;
            }
        }
        return cell;
    }
    if (orig_PBC_cellForRowAtIndexPath) {
        return orig_PBC_cellForRowAtIndexPath(self, _cmd, tableView, indexPath);
    }
    return nil;
}

static void (*orig_PBC_didSelectRowAtIndexPath)(id, SEL, UITableView *, NSIndexPath *);
static void hook_PBC_didSelectRowAtIndexPath(id self, SEL _cmd, UITableView *tableView, NSIndexPath *indexPath) {
    if (isFrameratePopupController(self) && indexPath.row >= 0 && indexPath.row < s_ultraFpsCount) {
        int chosenFps = s_ultraFpsValues[indexPath.row];
        NSString *chosenTitle = s_ultraFpsTitles[indexPath.row];
        
        [[NSUserDefaults standardUserDefaults] setInteger:chosenFps forKey:@"new_scene_preset_fps"];
        [[NSUserDefaults standardUserDefaults] setInteger:chosenFps forKey:@"video_export_frameRate"];
        [[NSUserDefaults standardUserDefaults] synchronize];
        
        id sourceView = nil;
        @try { sourceView = [self valueForKey:@"sourceView"]; } @catch (NSException *e) {}
        if (sourceView && [sourceView isKindOfClass:[UIView class]]) {
            updateViewFpsLabel((UIView *)sourceView, chosenTitle);
            @try { [sourceView setValue:@(indexPath.row) forKey:@"index"]; } @catch (NSException *e) {}
        }
        @try { [self setValue:@(indexPath.row) forKey:@"selectedIndex"]; } @catch (NSException *e) {}
        
        UIView *popupView = nil;
        @try { popupView = [self valueForKey:@"popupView"]; } @catch (NSException *e) {}
        UIView *shadowView = nil;
        @try { shadowView = [self valueForKey:@"shadowView"]; } @catch (NSException *e) {}
        
        [UIView animateWithDuration:0.2 animations:^{
            if (popupView) popupView.alpha = 0.0;
            if (shadowView) shadowView.alpha = 0.0;
        } completion:^(BOOL finished) {
            if (popupView) [popupView removeFromSuperview];
            if (shadowView) [shadowView removeFromSuperview];
        }];
        return;
    }
    if (orig_PBC_didSelectRowAtIndexPath) {
        orig_PBC_didSelectRowAtIndexPath(self, _cmd, tableView, indexPath);
    }
}

// CreateVC & SceneSettingsVC viewWillAppear Hooks for Ultra FPS Preselection
static void (*orig_CreateVC_viewWillAppear)(UIViewController *, SEL, BOOL);
static void hook_CreateVC_viewWillAppear(UIViewController *self, SEL _cmd, BOOL animated) {
    if (orig_CreateVC_viewWillAppear) {
        orig_CreateVC_viewWillAppear(self, _cmd, animated);
    }
    NSInteger presetFps = [[NSUserDefaults standardUserDefaults] integerForKey:@"new_scene_preset_fps"];
    if (presetFps > 0) {
        NSString *fpsTitle = [NSString stringWithFormat:@"%ld fps", (long)presetFps];
        id frBtn = nil;
        @try { frBtn = [self valueForKey:@"valueFrameRateButton"]; } @catch (NSException *e) {}
        if (frBtn && [frBtn isKindOfClass:[UIView class]]) {
            updateViewFpsLabel((UIView *)frBtn, fpsTitle);
        }
    }
}

static void (*orig_SceneSettingsVC_viewWillAppear)(UIViewController *, SEL, BOOL);
static void hook_SceneSettingsVC_viewWillAppear(UIViewController *self, SEL _cmd, BOOL animated) {
    if (orig_SceneSettingsVC_viewWillAppear) {
        orig_SceneSettingsVC_viewWillAppear(self, _cmd, animated);
    }
    NSInteger presetFps = [[NSUserDefaults standardUserDefaults] integerForKey:@"new_scene_preset_fps"];
    if (presetFps > 0) {
        NSString *fpsTitle = [NSString stringWithFormat:@"%ld fps", (long)presetFps];
        id frBtn = nil;
        @try { frBtn = [self valueForKey:@"rateButton"]; } @catch (NSException *e) {}
        if (frBtn && [frBtn isKindOfClass:[UIView class]]) {
            updateViewFpsLabel((UIView *)frBtn, fpsTitle);
        }
    }
}

static void (*orig_ShareVideoVC_viewWillAppear)(UIViewController *, SEL, BOOL);
static void hook_ShareVideoVC_viewWillAppear(UIViewController *self, SEL _cmd, BOOL animated) {
    if (orig_ShareVideoVC_viewWillAppear) {
        orig_ShareVideoVC_viewWillAppear(self, _cmd, animated);
    }
    NSInteger presetFps = [[NSUserDefaults standardUserDefaults] integerForKey:@"video_export_frameRate"];
    if (presetFps <= 0) presetFps = [[NSUserDefaults standardUserDefaults] integerForKey:@"new_scene_preset_fps"];
    if (presetFps > 0) {
        UILabel *fpsLbl = nil;
        @try { fpsLbl = [self valueForKey:@"fpsLabel"]; } @catch (NSException *e) {}
        if (fpsLbl && [fpsLbl isKindOfClass:[UILabel class]]) {
            fpsLbl.text = [NSString stringWithFormat:@"%ld fps", (long)presetFps];
        }
    }
}

#pragma mark - =========================================================
#pragma mark 9. Safe Unified Constructor (Native ProMotion, Zero Third-Party Hooks)
#pragma mark - =========================================================

__attribute__((constructor)) static void initAlightMotionUltra() {
    // 1. Rebind Keychain functions using Fishhook
    rebind_symbols((struct rebinding[4]){
        {"SecItemAdd", (void *)hook_SecItemAdd, (void **)&orig_SecItemAdd},
        {"SecItemCopyMatching", (void *)hook_SecItemCopyMatching, (void **)&orig_SecItemCopyMatching},
        {"SecItemUpdate", (void *)hook_SecItemUpdate, (void **)&orig_SecItemUpdate},
        {"SecItemDelete", (void *)hook_SecItemDelete, (void **)&orig_SecItemDelete}
    }, 4);

    dispatch_async(dispatch_get_main_queue(), ^{
        // 2. Request Notifications & Photos permission
        // 2. Apply Pro Monetization state immediately and on launch notification
        AMApplyProSettings();
        [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidFinishLaunchingNotification
                                                          object:nil
                                                           queue:[NSOperationQueue mainQueue]
                                                      usingBlock:^(NSNotification * _Nonnull note) {
            AMApplyProSettings();
        }];

        // 3. Swizzle NSFileManager containerURLForSecurityApplicationGroupIdentifier:
        Method mContainer = class_getInstanceMethod([NSFileManager class], @selector(containerURLForSecurityApplicationGroupIdentifier:));
        if (mContainer) {
            orig_containerURLForSecurityApplicationGroupIdentifier = (void *)method_getImplementation(mContainer);
            method_setImplementation(mContainer, (IMP)hook_containerURLForSecurityApplicationGroupIdentifier);
        }

        // 5. Swizzle DTXWatermarkView
        Class wmkClass = objc_getClass("DTXWatermarkView");
        if (wmkClass) {
            Method mLayout = class_getInstanceMethod(wmkClass, @selector(layoutSubviews));
            if (mLayout) {
                orig_DTXWatermarkView_layoutSubviews = (void *)method_getImplementation(mLayout);
                method_setImplementation(mLayout, (IMP)hook_DTXWatermarkView_layoutSubviews);
            }
        }

        // 6. Swizzle WatermarkPopup layoutSubviews
        Class popClass = objc_getClass("_TtC12AlightMotion14WatermarkPopup");
        if (popClass) {
            Method mLayout = class_getInstanceMethod(popClass, @selector(layoutSubviews));
            if (mLayout) {
                orig_WatermarkPopup_layoutSubviews = (void *)method_getImplementation(mLayout);
                method_setImplementation(mLayout, (IMP)hook_WatermarkPopup_layoutSubviews);
            }
        }

        // 6.1 Swizzle UIViewController presentViewController:animated:completion: (iOS 18 Crash Guard)
        Method mPresent = class_getInstanceMethod([UIViewController class], @selector(presentViewController:animated:completion:));
        if (mPresent) {
            orig_UIViewController_presentViewController = (void *)method_getImplementation(mPresent);
            method_setImplementation(mPresent, (IMP)hook_UIViewController_presentViewController);
        }

        // 6.2 Suppress AppLovin Consent Flow crashes
        Class alStateClass = objc_getClass("ALConsentFlowStateMachine");
        if (alStateClass) {
            Method mTrans = class_getInstanceMethod(alStateClass, sel_registerName("transitionToState:"));
            if (mTrans) {
                orig_ALConsentFlowStateMachine_transitionToState = (void *)method_getImplementation(mTrans);
                method_setImplementation(mTrans, (IMP)hook_ALConsentFlowStateMachine_transitionToState);
            }
        }
        Class alMgrClass = objc_getClass("ALConsentFlowManager");
        if (alMgrClass) {
            Method mShow = class_getInstanceMethod(alMgrClass, sel_registerName("showConsentFlowIfNeededAndInitialize"));
            if (mShow) {
                orig_ALConsentFlowManager_showConsentFlow = (void *)method_getImplementation(mShow);
                method_setImplementation(mShow, (IMP)hook_ALConsentFlowManager_showConsentFlow);
            }
        }

        // 7. Swizzle UIActivityViewController (Auto Save)
        Class actClass = [UIActivityViewController class];
        Method mAct = class_getInstanceMethod(actClass, @selector(initWithActivityItems:applicationActivities:));
        if (mAct) {
            orig_UIActivityViewController_initWithActivityItems = (void *)method_getImplementation(mAct);
            method_setImplementation(mAct, (IMP)hook_UIActivityViewController_initWithActivityItems);
        }

        // 8. Swizzle UIViewController viewDidAppear
        Class vcClass = [UIViewController class];
        Method mAppear = class_getInstanceMethod(vcClass, @selector(viewDidAppear:));
        if (mAppear) {
            orig_UIViewController_viewDidAppear = (void *)method_getImplementation(mAppear);
            method_setImplementation(mAppear, (IMP)hook_UIViewController_viewDidAppear);
        }

        // 9. Hook TextInputVC & UITextView (Lyrics Accessory Bar)
        Class textInputClass = objc_getClass("_TtC12AlightMotion11TextInputVC");
        if (textInputClass) {
            Method textAppearMethod = class_getInstanceMethod(textInputClass, @selector(viewDidAppear:));
            if (textAppearMethod) {
                orig_TextInputVC_viewDidAppear = (void *)method_getImplementation(textAppearMethod);
                method_setImplementation(textAppearMethod, (IMP)hook_TextInputVC_viewDidAppear);
            }
        }

        Class tvClass = [UITextView class];
        if (tvClass) {
            Method becomeMethod = class_getInstanceMethod(tvClass, @selector(becomeFirstResponder));
            if (becomeMethod) {
                orig_UITextView_becomeFirstResponder = (void *)method_getImplementation(becomeMethod);
                method_setImplementation(becomeMethod, (IMP)hook_UITextView_becomeFirstResponder);
            }
        }

        // 10. Hook PopupButtonController for Ultra Framerates (50..1920 FPS)
        Class pbcClass = objc_getClass("_TtC12AlightMotion21PopupButtonController");
        if (pbcClass) {
            Method mRows = class_getInstanceMethod(pbcClass, @selector(tableView:numberOfRowsInSection:));
            if (mRows) {
                orig_PBC_numberOfRowsInSection = (void *)method_getImplementation(mRows);
                method_setImplementation(mRows, (IMP)hook_PBC_numberOfRowsInSection);
            }
            Method mCell = class_getInstanceMethod(pbcClass, @selector(tableView:cellForRowAtIndexPath:));
            if (mCell) {
                orig_PBC_cellForRowAtIndexPath = (void *)method_getImplementation(mCell);
                method_setImplementation(mCell, (IMP)hook_PBC_cellForRowAtIndexPath);
            }
            Method mSelect = class_getInstanceMethod(pbcClass, @selector(tableView:didSelectRowAtIndexPath:));
            if (mSelect) {
                orig_PBC_didSelectRowAtIndexPath = (void *)method_getImplementation(mSelect);
                method_setImplementation(mSelect, (IMP)hook_PBC_didSelectRowAtIndexPath);
            }
        }

        // 11. Hook CreateVC & SceneSettingsVC viewWillAppear for Ultra FPS UI Preselection
        Class createClass = objc_getClass("_TtC12AlightMotion8CreateVC");
        if (createClass) {
            Method mAppear = class_getInstanceMethod(createClass, @selector(viewWillAppear:));
            if (mAppear) {
                orig_CreateVC_viewWillAppear = (void *)method_getImplementation(mAppear);
                method_setImplementation(mAppear, (IMP)hook_CreateVC_viewWillAppear);
            }
        }
        Class sceneSetClass = objc_getClass("_TtC12AlightMotion15SceneSettingsVC");
        if (sceneSetClass) {
            Method mAppear = class_getInstanceMethod(sceneSetClass, @selector(viewWillAppear:));
            if (mAppear) {
                orig_SceneSettingsVC_viewWillAppear = (void *)method_getImplementation(mAppear);
                method_setImplementation(mAppear, (IMP)hook_SceneSettingsVC_viewWillAppear);
            }
        }
        Class shareVidClass = objc_getClass("_TtC12AlightMotion12ShareVideoVC");
        if (shareVidClass) {
            Method mAppear = class_getInstanceMethod(shareVidClass, @selector(viewWillAppear:));
            if (mAppear) {
                orig_ShareVideoVC_viewWillAppear = (void *)method_getImplementation(mAppear);
                method_setImplementation(mAppear, (IMP)hook_ShareVideoVC_viewWillAppear);
            }
        }

        NSLog(@"[AlightMotionUltra] Successfully initialized Standalone Clean Tweak with Ultra Framerate Engine (50..1920 FPS)!");
    });
}
