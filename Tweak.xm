#import <UIKit/UIKit.h>
#import <libcolorpicker.h>
#import <CoreFoundation/CoreFoundation.h>
#import <SpringBoard/SpringBoard.h>
#import <Foundation/Foundation.h>

#define kIdentifier @"com.lnx.showtouch"
#define kSettingsChangedNotification (CFStringRef)@"com.lnx.showtouch/ReloadPrefs"
#define kScreenRecordChanged (CFStringRef)@"captured"
#define kColorChangedNotification (CFStringRef)@"com.lnx.showtouch/colorChanged"
#define kSettingsResetNotification (CFStringRef)@"com.lnx.showtouch/settingsReset"

#define kColorPath @"/var/mobile/Library/Preferences/com.lnx.showtouch.color.plist"
#define kSettingsPath @"/var/mobile/Library/Preferences/com.lnx.showtouch.plist"

@interface TouchWindow : UIWindow
@property (nonatomic, strong) NSTimer *hideTimer;
@end
@implementation TouchWindow
-(BOOL)_ignoresHitTest {
    return YES;
}
@end
static TouchWindow *touchWindow1;
static TouchWindow *touchWindow2;
static TouchWindow *touchWindow3;

static CAShapeLayer *circleShape;
static UIColor *touchColor;
static NSInteger enabled;

static CGFloat touchSize;

static UIDeviceOrientation orientation;
static float screenW;
static float screenH;


@interface UITouchesEvent : UIEvent
-(id)_windows;
- (CGPoint)adjustTouch:(UITouch *)aTouch windowClass:(NSString *)name;
-(void)updateOrientation;
@end

@interface UIApplication (STUIApp)
-(SBApplication*)_accessibilityFrontMostApplication;
- (UIDeviceOrientation)_frontMostAppOrientation;
@end

static UITouchesEvent *touchEvent;

%hook UITouchesEvent

-(id)_init{
    return touchEvent = %orig;
}

%new
-(void)updateOrientation{
    orientation = [[UIApplication sharedApplication] _frontMostAppOrientation];
    screenW = [[UIScreen mainScreen] bounds].size.width;
    screenH = [[UIScreen mainScreen] bounds].size.height;
    if (screenW > screenH){
        float screenW_temp = screenW;
        screenW = screenH;
        screenH = screenW_temp;
        
    }
}

%new
- (CGPoint)adjustTouch:(UITouch *)aTouch windowClass:(NSString *)name{
    
    CGPoint oldTouchLocation = [[aTouch valueForKey:@"_locationInWindow"] CGPointValue];
    CGPoint touchLocation = CGPointZero;
    
    //special case
    BOOL isSBMainScreenActiveInterfaceOrientationWindow = [name isEqualToString:@"SBMainScreenActiveInterfaceOrientationWindow"];
    if (orientation == UIDeviceOrientationPortraitUpsideDown && isSBMainScreenActiveInterfaceOrientationWindow){
        touchLocation.x = screenW - oldTouchLocation.x;
        touchLocation.y = screenH - oldTouchLocation.y;
        return touchLocation;
    }else if (isSBMainScreenActiveInterfaceOrientationWindow){
        return oldTouchLocation;
    }
    
    //normal case
    switch (orientation) {
        case UIDeviceOrientationPortrait:
            touchLocation = oldTouchLocation;
            break;
        case UIDeviceOrientationPortraitUpsideDown:
            touchLocation.x = screenW - oldTouchLocation.x;
            touchLocation.y = screenH - oldTouchLocation.y;
            break;
        case UIDeviceOrientationLandscapeLeft:
            touchLocation.x = screenW - oldTouchLocation.y;
            touchLocation.y = oldTouchLocation.x;
            break;
        case UIDeviceOrientationLandscapeRight:
            touchLocation.x = oldTouchLocation.y;
            touchLocation.y = screenH - oldTouchLocation.x;
            break;
        default:
            break;
    }
    return touchLocation;
}

-(void)_setHIDEvent:(id)arg1 {
    if (enabled == 1){
        dispatch_async(dispatch_get_main_queue(), ^{
            
            SBApplication *currentApplication = [[objc_getClass("SpringBoard") sharedApplication] _accessibilityFrontMostApplication];
            
            NSMutableArray *currentTouches;
            if (@available(iOS 11.0, *)) {
                currentTouches = [[[self valueForKey:@"_allTouchesMutable"] allObjects] mutableCopy];
            } else {
                currentTouches = [[[self valueForKey:@"_touches"] allObjects] mutableCopy];
            }
            if (currentTouches.count == 0) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    touchWindow1.hidden = YES;
                    touchWindow2.hidden = YES;
                    touchWindow3.hidden = YES;
                    
                    touchWindow1 = nil;
                    touchWindow2 = nil;
                    touchWindow3 = nil;
                });
            }
            else {
                if (currentTouches.count == 1) {
                    touchWindow2.hidden = YES;
                    touchWindow2 = nil;
                    touchWindow3.hidden = YES;
                    touchWindow3 = nil;
                }
                else if (currentTouches.count == 2) {
                    touchWindow3.hidden = YES;
                    touchWindow3 = nil;
                }
                
                
                for (int i = 0; i < currentTouches.count; i++) {
                    UITouch *touch = currentTouches[i];
                    HBLogDebug(@"%@ - %@ - %@ - %@ - %@", NSStringFromClass([[UIApplication sharedApplication] class]), currentApplication, [UIApplication sharedApplication], touch.window, NSStringFromClass([touch.window class]));
                    BOOL shouldShowTouch = NO;
                    if (@available(iOS 11.0, *)) {
                        NSLog(@"ios 11");
                        shouldShowTouch = YES;
                    }
                    else {
                        NSLog(@"ios 10");
                        if ((!currentApplication && [touch.window isKindOfClass:%c(FBRootWindow)]) || ![touch.window isKindOfClass:%c(FBRootWindow)]) {
                            shouldShowTouch = YES;
                        }
                        else {
                            shouldShowTouch = NO;
                        }
                    }
                    if (shouldShowTouch) {
                        CGPoint touchLocation = CGPointZero;
                        NSArray *issueProneWindows = @[@"SBHomeScreenWindow", @"SBMainScreenActiveInterfaceOrientationWindow", @"SBControlCenterWindow", @"SBAlertItemWindow"];
                        NSString *windowName = NSStringFromClass([touch.window class]);
                        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad && [issueProneWindows containsObject:windowName]){
                            touchLocation = [self adjustTouch:touch windowClass:windowName];
                        }else{
                            touchLocation = [[touch valueForKey:@"_locationInWindow"] CGPointValue];
                        }
                        switch (i) {
                            case 0: {
                                dispatch_async(dispatch_get_main_queue(), ^{
                                    if (!touchWindow1) {
                                        touchWindow1 = [[TouchWindow alloc] initWithFrame:CGRectMake(touchLocation.x, touchLocation.y, touchSize, touchSize)];
                                    }
                                    CGRect touchFrame = touchWindow1.bounds;
                                    touchFrame.size.width = touchFrame.size.height = touchSize;
                                    touchWindow1.bounds = touchFrame;
                                    touchWindow1.backgroundColor = touchColor;
                                    touchWindow1.center = CGPointMake(touchLocation.x, touchLocation.y);
                                    touchWindow1.windowLevel = UIWindowLevelStatusBar + 100000;
                                    touchWindow1.userInteractionEnabled = NO;
                                    touchWindow1.layer.cornerRadius = touchWindow1.bounds.size.width / 2;
                                    touchWindow1.hidden = NO;
                                });
                                break;
                            }
                            case 1: {
                                dispatch_async(dispatch_get_main_queue(), ^{
                                    if (!touchWindow2) {
                                        touchWindow2 = [[TouchWindow alloc] initWithFrame:CGRectMake(touchLocation.x, touchLocation.y, touchSize, touchSize)];
                                    }
                                    CGRect touchFrame = touchWindow2.bounds;
                                    touchFrame.size.width = touchFrame.size.height = touchSize;
                                    touchWindow2.bounds = touchFrame;
                                    touchWindow2.backgroundColor = touchColor;
                                    touchWindow2.center = CGPointMake(touchLocation.x, touchLocation.y);
                                    touchWindow2.windowLevel = UIWindowLevelStatusBar + 100000;
                                    touchWindow2.userInteractionEnabled = NO;
                                    touchWindow2.layer.cornerRadius = touchWindow2.bounds.size.width / 2;
                                    touchWindow2.hidden = NO;
                                });
                                break;
                            }
                            case 2: {
                                dispatch_async(dispatch_get_main_queue(), ^{
                                    if (!touchWindow3) {
                                        touchWindow3 = [[TouchWindow alloc] initWithFrame:CGRectMake(touchLocation.x, touchLocation.y, touchSize, touchSize)];
                                    }
                                    CGRect touchFrame = touchWindow3.bounds;
                                    touchFrame.size.width = touchFrame.size.height = touchSize;
                                    touchWindow3.bounds = touchFrame;
                                    touchWindow3.backgroundColor = touchColor;
                                    touchWindow3.center = CGPointMake(touchLocation.x, touchLocation.y);
                                    touchWindow3.windowLevel = UIWindowLevelStatusBar + 100000;
                                    touchWindow3.userInteractionEnabled = NO;
                                    touchWindow3.layer.cornerRadius = touchWindow3.bounds.size.width / 2;
                                    touchWindow3.hidden = NO;
                                });
                                break;
                            }
                            default:
                                break;
                        }
                    }
                }
            }
        });
    }
    %orig;
}
%end

static void reloadColorPrefs() {
    NSDictionary *preferences = [NSDictionary dictionaryWithContentsOfFile:kColorPath];
    touchColor = [preferences objectForKey:@"touchColor"] ? LCPParseColorString([preferences objectForKey:@"touchColor"], @"#FFFFFF") : [UIColor redColor];
}

static void reloadPrefs() {
    CFPreferencesAppSynchronize((CFStringRef)kIdentifier);
    
    NSDictionary *prefs = nil;
    if ([NSHomeDirectory() isEqualToString:@"/var/mobile"]) {
        CFArrayRef keyList = CFPreferencesCopyKeyList((CFStringRef)kIdentifier, kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
        if (keyList != nil) {
            prefs = (NSDictionary *)CFBridgingRelease(CFPreferencesCopyMultiple(keyList, (CFStringRef)kIdentifier, kCFPreferencesCurrentUser, kCFPreferencesAnyHost));
            if (prefs == nil)
                prefs = [NSDictionary dictionary];
            CFRelease(keyList);
        }
    } else {
        prefs = [NSDictionary dictionaryWithContentsOfFile:kSettingsPath];
    }
    
    enabled = [prefs objectForKey:@"enabled"] ? [[prefs objectForKey:@"enabled"] integerValue] : 0;
    touchSize = [prefs objectForKey:@"touchSize"] ? [[prefs objectForKey:@"touchSize"] floatValue] : 30;
}

static void orientationChanged(){
    if (touchEvent){
        [touchEvent updateOrientation];
    }
}

%ctor {
    
    @autoreleasepool {
        NSArray *args = [[NSClassFromString(@"NSProcessInfo") processInfo] arguments];
        
        if (args.count != 0) {
            NSString *executablePath = args[0];
            
            if (executablePath) {
                NSString *processName = [executablePath lastPathComponent];
                
                BOOL isSpringBoard = [processName isEqualToString:@"SpringBoard"];
                BOOL isApplication = [executablePath rangeOfString:@"/Application"].location != NSNotFound;
                
                if (isSpringBoard || isApplication) {
                    reloadPrefs();
                    if (enabled){
                        reloadColorPrefs();
                        orientationChanged();
                        
                        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)reloadPrefs, kSettingsChangedNotification, NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
                        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)reloadColorPrefs, kColorChangedNotification, NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
                        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)&orientationChanged, CFSTR("com.apple.springboard.screenchanged"), NULL, 0);
                        CFNotificationCenterAddObserver(CFNotificationCenterGetLocalCenter(), NULL, (CFNotificationCallback)&orientationChanged, CFSTR("UIWindowDidRotateNotification"), NULL, CFNotificationSuspensionBehaviorCoalesce);
                        
                        NSLog(@"ios 11");
                        
                        if (enabled == 2) {
                            if (@available(iOS 11.0, *)) {
                                [[NSNotificationCenter defaultCenter] addObserverForName: UIScreenCapturedDidChangeNotification
                                                                                  object: nil
                                                                                   queue: nil
                                                                              usingBlock: ^ (NSNotification * notification) {
                                    enabled = UIScreen.mainScreen.captured ? 1 : 0;
                                }];
                            } else {
                            }
                        }
                    }
                }
            }
        }
        
    }
}
