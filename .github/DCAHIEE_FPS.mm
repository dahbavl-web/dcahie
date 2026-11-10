#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <Foundation/Foundation.h>

@interface DCLEDView : UIView
@property (nonatomic, strong) CAGradientLayer *gradientLayer;
@property (nonatomic, strong) CADisplayLink *displayLink;
@property (nonatomic, assign) CGFloat hue;
- (void)start;
- (void)stop;
@end

@implementation DCLEDView
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor blackColor];
        self.clipsToBounds = YES;
        self.layer.cornerRadius = frame.size.height / 2.0;
        _gradientLayer = [CAGradientLayer layer];
        _gradientLayer.frame = self.bounds;
        _gradientLayer.startPoint = CGPointMake(0.0, 0.5);
        _gradientLayer.endPoint = CGPointMake(1.0, 0.5);
        _gradientLayer.cornerRadius = frame.size.height / 2.0;
        [self.layer addSublayer:_gradientLayer];
    }
    return self;
}
- (void)start {
    if (self.displayLink) return;
    self.displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(tick)];
    [self.displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
}
- (void)tick {
    self.hue += 0.004;
    if (self.hue >= 1.0) self.hue -= 1.0;
    NSMutableArray *colors = [NSMutableArray array];
    for (int i = 0; i < 4; i++) {
        CGFloat h = fmod(self.hue + (i * 0.15), 1.0);
        UIColor *c = [UIColor colorWithHue:h saturation:1.0 brightness:1.0 alpha:1.0];
        [colors addObject:(id)c.CGColor];
    }
    self.gradientLayer.colors = colors;
    self.gradientLayer.locations = @[@0.0, @0.33, @0.66, @1.0];
}
- (void)stop { [self.displayLink invalidate]; self.displayLink = nil; }
- (void)layoutSubviews { [super layoutSubviews]; self.gradientLayer.frame = self.bounds; }
- (void)dealloc { [self stop]; }
@end

@interface DCOverlayWindow : UIWindow
@property (nonatomic, strong) UILabel *label;
@property (nonatomic, strong) DCLEDView *ledView;
@property (nonatomic, strong) CADisplayLink *fpsLink;
@property (nonatomic, assign) CFTimeInterval lastTimestamp;
@property (nonatomic, assign) NSInteger frameCount;
@property (nonatomic, assign) NSInteger currentFPS;
@property (nonatomic, strong) NSTimer *updateTimer;
@end

@implementation DCOverlayWindow
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.windowLevel = UIWindowLevelAlert + 1000;
        self.backgroundColor = [UIColor clearColor];
        self.userInteractionEnabled = NO;
        self.rootViewController = [[UIViewController alloc] init];
        self.rootViewController.view.backgroundColor = [UIColor clearColor];
        CGFloat screenW = [UIScreen mainScreen].bounds.size.width;
        CGRect barFrame = CGRectMake(8, 50, screenW - 16, 26.0);
        self.ledView = [[DCLEDView alloc] initWithFrame:barFrame];
        [self.rootViewController.view addSubview:self.ledView];
        [self.ledView start];
        self.label = [[UILabel alloc] initWithFrame:barFrame];
        self.label.textColor = [UIColor whiteColor];
        UIFont *italicFont = [UIFont italicSystemFontOfSize:13.5];
        if (!italicFont) italicFont = [UIFont systemFontOfSize:13.5];
        self.label.font = italicFont;
        self.label.textAlignment = NSTextAlignmentCenter;
        self.label.backgroundColor = [UIColor clearColor];
        self.label.adjustsFontSizeToFitWidth = YES;
        self.label.minimumScaleFactor = 0.7;
        self.label.shadowColor = [UIColor blackColor];
        self.label.shadowOffset = CGSizeMake(0, 0.5);
        self.label.text = @"dcahiee  FPS: --  |  --:--:--  --/--/----  |  Pin: --%";
        [self.rootViewController.view addSubview:self.label];
        [UIDevice currentDevice].batteryMonitoringEnabled = YES;
        self.fpsLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(fpsTick:)];
        [self.fpsLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
        self.updateTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(refreshLabel) userInfo:nil repeats:YES];
        [[NSRunLoop mainRunLoop] addTimer:self.updateTimer forMode:NSRunLoopCommonModes];
    }
    return self;
}
- (void)fpsTick:(CADisplayLink *)link {
    if (self.lastTimestamp == 0) { self.lastTimestamp = link.timestamp; return; }
    self.frameCount++;
    CFTimeInterval elapsed = link.timestamp - self.lastTimestamp;
    if (elapsed >= 0.5) {
        self.currentFPS = (NSInteger)(self.frameCount / elapsed);
        self.frameCount = 0;
        self.lastTimestamp = link.timestamp;
        [self refreshLabel];
    }
}
- (void)refreshLabel {
    static NSDateFormatter *fmt = nil;
    if (!fmt) { fmt = [[NSDateFormatter alloc] init]; fmt.dateFormat = @"HH:mm:ss  dd/MM/yyyy"; }
    NSString *timeStr = [fmt stringFromDate:[NSDate date]];
    float level = [UIDevice currentDevice].batteryLevel;
    NSString *batStr = (level < 0) ? @"--%" : [NSString stringWithFormat:@"%.0f%%", level * 100];
    self.label.text = [NSString stringWithFormat:@"dcahiee  FPS: %ld  |  %@  |  Pin: %@", (long)self.currentFPS, timeStr, batStr];
}
- (void)dealloc { [self.fpsLink invalidate]; [self.updateTimer invalidate]; [self.ledView stop]; }
@end

static DCOverlayWindow *gWindow = nil;
static void DCCreateOverlay(void) {
    if (gWindow) { gWindow.hidden = NO; return; }
    dispatch_async(dispatch_get_main_queue(), ^{
        if (gWindow) return;
        CGRect bounds = [UIScreen mainScreen].bounds;
        gWindow = [[DCOverlayWindow alloc] initWithFrame:bounds];
        gWindow.hidden = NO;
        gWindow.rootViewController.view.frame = bounds;
    });
}
__attribute__((constructor))
static void DCTweakInit(void) {
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidFinishLaunchingNotification
                                                      object:nil queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification * _Nonnull note) { DCCreateOverlay(); }];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{ DCCreateOverlay(); });
}
