// Nexions performance HUD. Integrated into the existing iOS input view.
// MIT; original Slashplayed and Enhanced retain their copyright and licenses.
#if !TARGET_OS_VISION

static NSString *const SPNexionsMonitorPositionKey = @"sp_nexions_monitor_position";
static NSString *const SPNexionsMonitorOnStartKey = @"sp_nexions_monitor_on_start";

static NSString *sp_nexions_thermal(void) {
    switch (NSProcessInfo.processInfo.thermalState) {
        case NSProcessInfoThermalStateNominal: return @"Normal";
        case NSProcessInfoThermalStateFair: return @"Warm";
        case NSProcessInfoThermalStateSerious: return @"Hot";
        case NSProcessInfoThermalStateCritical: return @"Critical";
    }
    return @"Unknown";
}

static UIColor *sp_nexions_thermal_color(void) {
    switch (NSProcessInfo.processInfo.thermalState) {
        case NSProcessInfoThermalStateNominal: return [UIColor colorWithRed:.55 green:.91 blue:.68 alpha:1];
        case NSProcessInfoThermalStateFair: return [UIColor colorWithRed:1 green:.82 blue:.37 alpha:1];
        case NSProcessInfoThermalStateSerious: return [UIColor colorWithRed:1 green:.55 blue:.25 alpha:1];
        case NSProcessInfoThermalStateCritical: return [UIColor colorWithRed:1 green:.37 blue:.37 alpha:1];
    }
    return UIColor.whiteColor;
}

@interface SPNexionsMonitor : UIView
- (void)toggleGesture:(UILongPressGestureRecognizer *)gesture;
- (void)showMonitor;
- (void)hideMonitor;
- (void)layoutInRect:(CGRect)rect;
@end

@implementation SPNexionsMonitor {
    UILabel *_stats;
    UILabel *_thermal;
    NSTimer *_timer;
    CGRect _safe;
    CGPoint _anchor;
    CGPoint _dragStart;
    BOOL _shown;
    uint64_t _previousFrames;
    NSTimeInterval _previousTime;
}

- (instancetype)initWithFrame:(CGRect)frame {
    if (!(self = [super initWithFrame:frame])) return nil;
    self.hidden = YES;
    self.backgroundColor = [UIColor colorWithWhite:.055 alpha:.88];
    self.layer.cornerRadius = 6;
    self.layer.borderColor = [UIColor colorWithWhite:.65 alpha:.4].CGColor;
    self.layer.borderWidth = 1;
    self.layer.zPosition = 2500;
    self.clipsToBounds = YES;
    self.accessibilityIdentifier = @"NexionsPerformanceMonitor";
    _anchor = CGPointMake(.5, 0);
    NSArray *saved = [NSUserDefaults.standardUserDefaults arrayForKey:SPNexionsMonitorPositionKey];
    if (saved.count == 2 && [saved[0] isKindOfClass:NSNumber.class] &&
        [saved[1] isKindOfClass:NSNumber.class]) {
        double x = [saved[0] doubleValue], y = [saved[1] doubleValue];
        if (isfinite(x) && isfinite(y))
            _anchor = CGPointMake(MAX(0, MIN(1, x)), MAX(0, MIN(1, y)));
    }
    _stats = [self labelWithSize:11];
    _thermal = [self labelWithSize:11];
    _stats.textAlignment = NSTextAlignmentCenter;
    _thermal.textAlignment = NSTextAlignmentCenter;
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(dragMonitor:)];
    pan.minimumNumberOfTouches = 1;
    pan.maximumNumberOfTouches = 1;
    [self addGestureRecognizer:pan];
    return self;
}

- (UILabel *)labelWithSize:(CGFloat)size {
    UILabel *l = [[UILabel alloc] initWithFrame:CGRectZero];
    l.font = [UIFont monospacedDigitSystemFontOfSize:size weight:UIFontWeightMedium];
    l.textColor = [UIColor colorWithWhite:.92 alpha:1];
    l.adjustsFontSizeToFitWidth = YES;
    l.minimumScaleFactor = .75;
    l.userInteractionEnabled = NO;
    [self addSubview:l];
    return l;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat w = self.bounds.size.width;
    _stats.frame = CGRectMake(4, 0, 56, self.bounds.size.height);
    _thermal.frame = CGRectMake(62, 0, MAX(0, w - 66), self.bounds.size.height);
}

- (void)layoutInRect:(CGRect)rect {
    if (CGRectIsNull(rect) || CGRectIsEmpty(rect)) return;
    _safe = CGRectInset(rect, 8, 8);
    CGFloat w = MIN(120, CGRectGetWidth(_safe));
    CGFloat h = 23;
    if (w < 100 || CGRectGetHeight(_safe) < h) return;
    self.frame = CGRectMake(CGRectGetMinX(_safe) + _anchor.x * (CGRectGetWidth(_safe) - w),
                            CGRectGetMinY(_safe) + _anchor.y * (CGRectGetHeight(_safe) - h), w, h);
}

- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
    return [[UIBezierPath bezierPathWithRoundedRect:self.bounds cornerRadius:self.layer.cornerRadius] containsPoint:point];
}

- (void)dragMonitor:(UIPanGestureRecognizer *)pan {
    if (pan.state == UIGestureRecognizerStateBegan) _dragStart = self.frame.origin;
    if (pan.state == UIGestureRecognizerStateChanged || pan.state == UIGestureRecognizerStateEnded) {
        CGPoint delta = [pan translationInView:self.superview];
        CGFloat dx = MAX(0, CGRectGetWidth(_safe) - self.bounds.size.width);
        CGFloat dy = MAX(0, CGRectGetHeight(_safe) - self.bounds.size.height);
        if (dx > 0) _anchor.x = MAX(0, MIN(1, (_dragStart.x + delta.x - CGRectGetMinX(_safe)) / dx));
        if (dy > 0) _anchor.y = MAX(0, MIN(1, (_dragStart.y + delta.y - CGRectGetMinY(_safe)) / dy));
        CGRect frame = self.frame;
        frame.origin = CGPointMake(CGRectGetMinX(_safe) + _anchor.x * dx, CGRectGetMinY(_safe) + _anchor.y * dy);
        self.frame = frame;
        if (pan.state == UIGestureRecognizerStateEnded)
            [NSUserDefaults.standardUserDefaults setObject:@[@(_anchor.x), @(_anchor.y)] forKey:SPNexionsMonitorPositionKey];
    }
}

- (void)toggleGesture:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state != UIGestureRecognizerStateBegan || !atomic_load(&sp_game_presented)) return;
    if (_shown) [self hideMonitor]; else [self showMonitor];
}

- (void)showMonitor {
    if (_shown) return;
    _shown = YES;
    _previousFrames = atomic_load_explicit(&sp_nexions_frames, memory_order_relaxed);
    _previousTime = NSProcessInfo.processInfo.systemUptime;
    atomic_store_explicit(&sp_nexions_count_frames, true, memory_order_relaxed);
    self.hidden = NO;
    [self.superview setNeedsLayout];
    [self.superview bringSubviewToFront:self];
    [self refreshMonitor];
    __weak SPNexionsMonitor *weak = self;
    _timer = [NSTimer timerWithTimeInterval:1.0 repeats:YES block:^(NSTimer *timer) {
        [weak refreshMonitor];
    }];
    [NSRunLoop.mainRunLoop addTimer:_timer forMode:NSRunLoopCommonModes];
}

- (void)hideMonitor {
    if (!_shown) return;
    _shown = NO;
    self.hidden = YES;
    [_timer invalidate];
    _timer = nil;
    atomic_store_explicit(&sp_nexions_count_frames, false, memory_order_relaxed);
}

- (void)refreshMonitor {
    if (!_shown) return;
    NSTimeInterval now = NSProcessInfo.processInfo.systemUptime;
    uint64_t frames = atomic_load_explicit(&sp_nexions_frames, memory_order_relaxed);
    NSString *fps = now - _previousTime >= .5
        ? [NSString stringWithFormat:@"%.0f FPS", (double)(frames - _previousFrames)/(now - _previousTime)] : @"— FPS";
    if (now - _previousTime >= .5) { _previousFrames = frames; _previousTime = now; }
    _stats.text = fps;
    _thermal.text = sp_nexions_thermal();
    _thermal.textColor = sp_nexions_thermal_color();
}

- (void)dealloc {
    [_timer invalidate];
    if (_shown) atomic_store_explicit(&sp_nexions_count_frames, false, memory_order_relaxed);
}
@end
#endif
