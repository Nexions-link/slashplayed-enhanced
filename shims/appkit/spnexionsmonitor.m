// Nexions performance HUD. Integrated into the existing iOS input view.
// MIT; original Slashplayed and Enhanced retain their copyright and licenses.
#if !TARGET_OS_VISION
#import <mach/mach.h>
#import <mach/task_info.h>

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

static NSString *sp_nexions_memory(void) {
    task_vm_info_data_t info = {0};
    mach_msg_type_number_t count = TASK_VM_INFO_COUNT;
    if (task_info(mach_task_self(), TASK_VM_INFO, (task_info_t)&info, &count) != KERN_SUCCESS)
        return @"—";
    return [NSString stringWithFormat:@"%.2f GB", (double)info.phys_footprint / 1e9];
}

// The CASC store is shared between game flavors in Documents/Data.
// Allocated storage, not traffic or a percentage of the total Blizzard download.
// Walk it only on a background queue and only while the monitor is visible.
static BOOL sp_nexions_scan_store(unsigned long long *allocated) {
    NSURL *root = [NSURL fileURLWithPath:[NSHomeDirectory() stringByAppendingPathComponent:@"Documents/Data"] isDirectory:YES];
    NSArray<NSURLResourceKey> *keys = @[NSURLIsRegularFileKey, NSURLIsSymbolicLinkKey,
                                        NSURLTotalFileAllocatedSizeKey, NSURLFileAllocatedSizeKey];
    __block BOOL ok = YES;
    NSDirectoryEnumerator<NSURL *> *it = [NSFileManager.defaultManager enumeratorAtURL:root
        includingPropertiesForKeys:keys options:0 errorHandler:^BOOL(NSURL *url, NSError *error) {
            ok = NO; return NO;
        }];
    if (!it) return NO;
    unsigned long long total = 0;
    for (NSURL *file in it) {
        @autoreleasepool {
            NSDictionary *v = [file resourceValuesForKeys:keys error:nil];
            if (!v) continue; // file may have been replaced by CASC during the scan
            if ([v[NSURLIsSymbolicLinkKey] boolValue]) { [it skipDescendants]; continue; }
            if (![v[NSURLIsRegularFileKey] boolValue]) continue;
            NSNumber *size = v[NSURLTotalFileAllocatedSizeKey] ?: v[NSURLFileAllocatedSizeKey];
            total += size.unsignedLongLongValue;
        }
    }
    if (ok) *allocated = total;
    return ok;
}

@interface SPNexionsMonitor : UIView
- (void)toggleGesture:(UILongPressGestureRecognizer *)gesture;
- (void)showMonitor;
- (void)hideMonitor;
- (void)layoutInRect:(CGRect)rect;
@end

@implementation SPNexionsMonitor {
    UILabel *_head;
    UILabel *_stats;
    UILabel *_thermal;
    UILabel *_store;
    UIButton *_close;
    NSTimer *_timer;
    CGRect _safe;
    CGPoint _anchor;
    CGPoint _dragStart;
    BOOL _shown;
    BOOL _wasBatteryMonitoring;
    BOOL _scanning;
    BOOL _storeValid;
    BOOL _rateValid;
    NSUInteger _generation;
    uint64_t _previousFrames;
    NSTimeInterval _previousTime;
    NSTimeInterval _nextScan;
    NSTimeInterval _lastStoreTime;
    unsigned long long _allocated;
    double _rate;
}

- (instancetype)initWithFrame:(CGRect)frame {
    if (!(self = [super initWithFrame:frame])) return nil;
    self.hidden = YES;
    self.backgroundColor = [UIColor colorWithWhite:.055 alpha:.88];
    self.layer.cornerRadius = 9;
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
    _head = [self labelWithSize:10];
    _head.font = [UIFont systemFontOfSize:10 weight:UIFontWeightSemibold];
    _head.text = @"NEXIONS · PERFORMANCE";
    _head.textColor = [UIColor colorWithRed:.78 green:.84 blue:.91 alpha:1];
    _stats = [self labelWithSize:12];
    _thermal = [self labelWithSize:12];
    _store = [self labelWithSize:11];
    _store.numberOfLines = 2;
    _close = [UIButton buttonWithType:UIButtonTypeSystem];
    [_close setTitle:@"×" forState:UIControlStateNormal];
    _close.titleLabel.font = [UIFont systemFontOfSize:21 weight:UIFontWeightRegular];
    _close.tintColor = UIColor.whiteColor;
    _close.accessibilityLabel = @"Hide performance monitor";
    [_close addTarget:self action:@selector(closePressed:) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:_close];
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
    _head.frame = CGRectMake(10, 5, MAX(0, w - 47), 19);
    _close.frame = CGRectMake(w - 36, 0, 36, 32);
    _stats.frame = CGRectMake(10, 26, MAX(0, w - 20), 19);
    _thermal.frame = CGRectMake(10, 45, MAX(0, w - 20), 19);
    _store.frame = CGRectMake(10, 65, MAX(0, w - 20), 32);
}

- (void)layoutInRect:(CGRect)rect {
    if (CGRectIsNull(rect) || CGRectIsEmpty(rect)) return;
    _safe = CGRectInset(rect, 8, 8);
    CGFloat w = MIN(258, CGRectGetWidth(_safe));
    CGFloat h = 102;
    if (w < 140 || CGRectGetHeight(_safe) < h) return;
    self.frame = CGRectMake(CGRectGetMinX(_safe) + _anchor.x * (CGRectGetWidth(_safe) - w),
                            CGRectGetMinY(_safe) + _anchor.y * (CGRectGetHeight(_safe) - h), w, h);
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

- (void)closePressed:(UIButton *)sender { [self hideMonitor]; }

- (void)showMonitor {
    if (_shown) return;
    _shown = YES;
    _generation++;
    _nextScan = 0;
    _storeValid = NO;
    _rateValid = NO;
    _wasBatteryMonitoring = UIDevice.currentDevice.batteryMonitoringEnabled;
    UIDevice.currentDevice.batteryMonitoringEnabled = YES;
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
    _generation++;
    self.hidden = YES;
    [_timer invalidate];
    _timer = nil;
    atomic_store_explicit(&sp_nexions_count_frames, false, memory_order_relaxed);
    if (!_wasBatteryMonitoring) UIDevice.currentDevice.batteryMonitoringEnabled = NO;
}

- (void)refreshMonitor {
    if (!_shown) return;
    NSTimeInterval now = NSProcessInfo.processInfo.systemUptime;
    uint64_t frames = atomic_load_explicit(&sp_nexions_frames, memory_order_relaxed);
    NSString *fps = now - _previousTime >= .5
        ? [NSString stringWithFormat:@"%.0f FPS", (double)(frames - _previousFrames)/(now - _previousTime)] : @"— FPS";
    if (now - _previousTime >= .5) { _previousFrames = frames; _previousTime = now; }
    float level = UIDevice.currentDevice.batteryLevel;
    NSString *battery = level >= 0 ? [NSString stringWithFormat:@"%.0f%%", level * 100] : @"—";
    _stats.text = [NSString stringWithFormat:@"%@  •  RAM %@\n", fps, sp_nexions_memory()];
    _thermal.text = [NSString stringWithFormat:@"Heat: %@  •  Battery %@", sp_nexions_thermal(), battery];
    _thermal.textColor = sp_nexions_thermal_color();
    if (!_storeValid) _store.text = @"Game data: measuring…";
    else {
        NSString *growth = _rateValid ? [NSString stringWithFormat:@"%+.2f MB/s", _rate / 1e6] : @"—";
        _store.text = [NSString stringWithFormat:@"Game data: %.2f GB allocated\nDisk growth: %@ (20s avg)", (double)_allocated/1e9, growth];
    }
    if (_scanning || now < _nextScan) return;
    _scanning = YES;
    _nextScan = now + 20;
    NSUInteger generation = _generation;
    __weak SPNexionsMonitor *weak = self;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        unsigned long long bytes = 0;
        BOOL ok = sp_nexions_scan_store(&bytes);
        NSTimeInterval time = NSProcessInfo.processInfo.systemUptime;
        dispatch_async(dispatch_get_main_queue(), ^{
            SPNexionsMonitor *me = weak;
            if (!me) return;
            me->_scanning = NO;
            if (!me->_shown || me->_generation != generation) return;
            if (!ok) { me->_storeValid = NO; me->_rateValid = NO; return; }
            NSTimeInterval elapsed = time - me->_lastStoreTime;
            me->_rateValid = me->_storeValid && elapsed >= 1;
            if (me->_rateValid) me->_rate = ((double)bytes - (double)me->_allocated)/elapsed;
            me->_allocated = bytes;
            me->_lastStoreTime = time;
            me->_storeValid = YES;
        });
    });
}

- (void)dealloc {
    [_timer invalidate];
    if (_shown) atomic_store_explicit(&sp_nexions_count_frames, false, memory_order_relaxed);
}
@end
#endif
