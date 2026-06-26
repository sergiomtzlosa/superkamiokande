#import "SKOEventEngine.h"
#import "SKOTankBuilder.h"
#import "SKOCommon.h"

NSString *SKOEventKindSymbol(SKOEventKind kind)
{
    switch (kind) {
        case SKOEventKindMuon:     return @"μ";
        case SKOEventKindElectron: return @"e⁻";
        case SKOEventKindGamma:    return @"γ";
    }
    return @"?";
}

NSString *SKOEventKindName(SKOEventKind kind)
{
    switch (kind) {
        case SKOEventKindMuon:     return @"muon";
        case SKOEventKindElectron: return @"electron";
        case SKOEventKindGamma:    return @"gamma";
    }
    return @"event";
}

static SKColor *SKOColorForKind(SKOEventKind kind)
{
    switch (kind) {
        case SKOEventKindMuon:
            return [SKColor colorWithRed:1.00 green:0.32 blue:0.72 alpha:1.0];
        case SKOEventKindElectron:
            return [SKColor colorWithRed:0.25 green:0.85 blue:1.00 alpha:1.0];
        case SKOEventKindGamma:
            return [SKColor colorWithRed:1.00 green:0.82 blue:0.30 alpha:1.0];
    }
    return [SKColor whiteColor];
}

@interface SKOEventEngine ()
@property (nonatomic, strong) NSTimer *timer;
@property (nonatomic, strong) SCNNode  *sceneRoot;
@property (nonatomic, assign) NSUInteger totalEvents;
@property (nonatomic, assign) BOOL  running;
@property (nonatomic, assign) CGFloat waterTemperatureCelsius;
@end

@implementation SKOEventEngine

- (instancetype)init
{
    self = [super init];
    if (self) {
        _eventRate = 3.0;
        _pmtSensitivity = 1.0;
        _fiducialRadius = 8.0;
        _waterTemperatureCelsius = 12.0;
        srand48((long)NSDate.date.timeIntervalSince1970);
    }
    return self;
}

- (void)setEventRate:(CGFloat)rate
{
    _eventRate = MIN(MAX(rate, 0.0), 20.0);
    if (self.running) {
        [self restartTimer];
    }
}

- (void)setFiducialRadius:(CGFloat)radius
{
    _fiducialRadius = MIN(MAX(radius, 2.0), 16.0);
}

- (void)start
{
    self.running = YES;
    [self restartTimer];
}

- (void)stop
{
    self.running = NO;
    [self.timer invalidate];
    self.timer = nil;
}

- (void)resetCount
{
    self.totalEvents = 0;
    self.waterTemperatureCelsius = 12.0;
}

- (void)attachSceneRoot:(SCNNode *)root
{
    self.sceneRoot = root;
}

- (void)restartTimer
{
    [self.timer invalidate];
    self.timer = nil;
    if (!_running) return;

    if (_eventRate < 0.01) return;
    CGFloat interval = 1.0 / _eventRate;
    self.timer = [NSTimer timerWithTimeInterval:interval
                                        target:self
                                      selector:@selector(tick:)
                                      userInfo:nil
                                       repeats:YES];
    self.timer.tolerance = interval * 0.1;
    [[NSRunLoop mainRunLoop] addTimer:self.timer forMode:NSRunLoopCommonModes];
}

- (void)tick:(NSTimer *)timer
{
    [self fireOnce];
}

- (void)fireOnce
{
    if (!self.sceneRoot) return;

    // Choose an event type: electrons dominate, muons are rarer, gammas in
    // between. This roughly mirrors the atmospheric-neutrino sample.
    CGFloat roll = drand48();
    SKOEventKind kind;
    if (roll < 0.60) {
        kind = SKOEventKindElectron;
    } else if (roll < 0.85) {
        kind = SKOEventKindMuon;
    } else {
        kind = SKOEventKindGamma;
    }

    // Vertex inside the fiducial cylinder.
    CGFloat fidR = MIN(MAX(self.fiducialRadius, 2.0), SKOTankRadius - 2.0);
    CGFloat r    = fidR * sqrt(drand48());
    CGFloat th   = 2.0 * M_PI * drand48();
    CGFloat fidH = SKOTankHeight * 0.75;
    CGFloat y    = SKOTankHeight / 2.0 + (drand48() - 0.5) * fidH;

    // Isotropic direction.
    CGFloat uz  = drand48() * 2.0 - 1.0;
    CGFloat phi = 2.0 * M_PI * drand48();
    CGFloat rho = sqrt(1.0 - uz * uz);
    SCNVector3 dir = SCNVector3Make(rho * cos(phi), uz, rho * sin(phi));
    SCNVector3 vertex = SCNVector3Make(r * sin(th), y, r * cos(th));

    // Energy spectra differ by particle type.
    CGFloat energy;
    switch (kind) {
        case SKOEventKindMuon:
            energy = 1.0 + pow(drand48(), 1.5) * 49.0;   // 1–50 GeV
            break;
        case SKOEventKindGamma:
            energy = 0.5 + pow(drand48(), 2.0) * 7.5;    // 0.5–8 GeV
            break;
        case SKOEventKindElectron:
        default:
            energy = 0.5 + pow(drand48(), 1.8) * 11.5;   // 0.5–12 GeV
            break;
    }

    SKColor *tint = SKOColorForKind(kind);
    NSMutableArray<SCNNode *> *visuals = [NSMutableArray array];

    if (kind == SKOEventKindGamma) {
        // A gamma converts to an e⁺e⁻ pair: two closely spaced rings.
        SCNNode *first = [SKOTankBuilder makeCherenkovRingWithEnergy:energy * 0.55
                                                           atPosition:vertex
                                                             direction:dir
                                                                 color:tint];
        SCNVector3 other = SCNVector3Make(vertex.x - dir.x * 0.45,
                                          vertex.y - dir.y * 0.45,
                                          vertex.z - dir.z * 0.45);
        SCNNode *second = [SKOTankBuilder makeCherenkovRingWithEnergy:energy * 0.45
                                                            atPosition:other
                                                              direction:dir
                                                                  color:tint];
        if (first)  [visuals addObject:first];
        if (second) [visuals addObject:second];
    } else {
        SCNNode *ring = [SKOTankBuilder makeCherenkovRingWithEnergy:energy
                                                          atPosition:vertex
                                                            direction:dir
                                                                color:tint];
        if (ring) [visuals addObject:ring];

        if (kind == SKOEventKindMuon) {
            SCNNode *track = [SKOTankBuilder makeMuonTrackWithEnergy:energy
                                                           atPosition:vertex
                                                             direction:dir
                                                                 color:tint];
            if (track) [visuals addObject:track];
        }
    }

    for (SCNNode *node in visuals) {
        [self.sceneRoot addChildNode:node];
    }

    [SKOTankBuilder flashPMTsInRoot:self.sceneRoot
                          direction:dir
                        sensitivity:self.pmtSensitivity
                              color:tint];

    // Retire the event visuals after the animation has finished.
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.6 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        for (SCNNode *node in visuals) {
            [node removeFromParentNode];
        }
    });

    self.totalEvents += 1;
    self.waterTemperatureCelsius = MIN(MAX(self.waterTemperatureCelsius
                                           + (drand48() - 0.5) * 0.02, 11.7), 12.5);
    if ([self.delegate respondsToSelector:@selector(engineDidSpawnEventWithEnergy:kind:ringNode:totalEvents:)]) {
        [self.delegate engineDidSpawnEventWithEnergy:energy
                                                kind:kind
                                            ringNode:visuals.firstObject
                                         totalEvents:self.totalEvents];
    }
}

@end
