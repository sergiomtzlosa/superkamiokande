#import <XCTest/XCTest.h>
#import <SceneKit/SceneKit.h>
#import "SKOEventEngine.h"
#import "SKOCommon.h"

@interface SKOEventEngineTests : XCTestCase <SKOEventEngineDelegate>
@property (nonatomic, strong) SKOEventEngine *engine;
@property (nonatomic, strong) SCNNode *root;
@property (nonatomic, assign) NSUInteger delegateCallCount;
@property (nonatomic, assign) CGFloat lastEnergy;
@property (nonatomic, assign) SKOEventKind lastKind;
@property (nonatomic, strong) SCNNode *lastRing;
@property (nonatomic, assign) NSUInteger lastTotal;
@end

@implementation SKOEventEngineTests

- (void)setUp
{
    [super setUp];
    self.root = [SCNNode node];
    SCNNode *wall = [SCNNode node];
    wall.name = @"wallPMT";
    for (NSUInteger i = 0; i < 28; ++i) {
        SCNNode *pmt = [SCNNode node];
        pmt.name = @"pmt";
        pmt.position = SCNVector3Make(sinf((CGFloat)i) * 18.0,
                                      SKOTankHeight * 0.5,
                                      cosf((CGFloat)i) * 18.0);
        [wall addChildNode:pmt];
    }
    [self.root addChildNode:wall];

    self.engine = [[SKOEventEngine alloc] init];
    self.engine.delegate = self;
    [self.engine attachSceneRoot:self.root];
    self.delegateCallCount = 0;
    self.lastEnergy = 0;
    self.lastRing = nil;
    self.lastTotal = 0;
}

- (void)tearDown
{
    [self.engine stop];
    self.engine = nil;
    self.root = nil;
    [super tearDown];
}

- (void)engineDidSpawnEventWithEnergy:(CGFloat)energyGeV
                                 kind:(SKOEventKind)kind
                             ringNode:(SCNNode *)ringNode
                          totalEvents:(NSUInteger)total
{
    self.delegateCallCount += 1;
    self.lastEnergy = energyGeV;
    self.lastKind = kind;
    self.lastRing = ringNode;
    self.lastTotal = total;
}

- (void)testDefaultsMatchTheSidebar
{
    XCTAssertEqualWithAccuracy(self.engine.eventRate, 3.0, 0.001);
    XCTAssertEqualWithAccuracy(self.engine.fiducialRadius, 8.0, 0.001);
    XCTAssertEqualWithAccuracy(self.engine.pmtSensitivity, 1.0, 0.001);
    XCTAssertEqualWithAccuracy(self.engine.waterTemperatureCelsius, 12.0, 0.001);
    XCTAssertFalse(self.engine.running);
}

- (void)testFireOncePublishesAnEventAndAddsVisuals
{
    NSUInteger before = self.root.childNodes.count;
    [self.engine fireOnce];

    XCTAssertEqual(self.engine.totalEvents, 1);
    XCTAssertEqual(self.delegateCallCount, 1);
    XCTAssertEqual(self.lastTotal, 1);
    XCTAssertGreaterThan(self.lastEnergy, 0.0);
    XCTAssertTrue(self.lastKind >= SKOEventKindMuon && self.lastKind <= SKOEventKindGamma);
    XCTAssertNotNil(self.lastRing);
    XCTAssertGreaterThan(self.root.childNodes.count, before);
    XCTAssertGreaterThanOrEqual(self.engine.waterTemperatureCelsius, 11.7);
    XCTAssertLessThanOrEqual(self.engine.waterTemperatureCelsius, 12.5);
}

- (void)testMultipleEventsKeepAnAccurateCounter
{
    for (NSUInteger i = 0; i < 5; ++i) {
        [self.engine fireOnce];
    }
    XCTAssertEqual(self.engine.totalEvents, 5);
    XCTAssertEqual(self.delegateCallCount, 5);
    XCTAssertEqual(self.lastTotal, 5);
}

- (void)testStartAndStopUpdateRunState
{
    self.engine.eventRate = 20.0;
    [self.engine start];
    XCTAssertTrue(self.engine.running);
    [self.engine stop];
    XCTAssertFalse(self.engine.running);
}

- (void)testFireOnceWithoutASceneRootIsIgnored
{
    [self.engine attachSceneRoot:nil];
    [self.engine fireOnce];
    XCTAssertEqual(self.engine.totalEvents, 0);
    XCTAssertEqual(self.delegateCallCount, 0);
}

- (void)testResetCountRestoresTheRunBaseline
{
    [self.engine fireOnce];
    [self.engine resetCount];
    XCTAssertEqual(self.engine.totalEvents, 0);
    XCTAssertEqualWithAccuracy(self.engine.waterTemperatureCelsius, 12.0, 0.001);
}

- (void)testRateAndRadiusAreClampedToSafeRanges
{
    self.engine.eventRate = 200.0;
    XCTAssertEqualWithAccuracy(self.engine.eventRate, 20.0, 0.001);
    self.engine.eventRate = -5.0;
    XCTAssertEqualWithAccuracy(self.engine.eventRate, 0.0, 0.001);

    self.engine.fiducialRadius = 100.0;
    XCTAssertEqualWithAccuracy(self.engine.fiducialRadius, 16.0, 0.001);
    self.engine.fiducialRadius = 0.0;
    XCTAssertEqualWithAccuracy(self.engine.fiducialRadius, 2.0, 0.001);
}

- (void)testEventKindNames
{
    XCTAssertEqualObjects(SKOEventKindSymbol(SKOEventKindMuon), @"μ");
    XCTAssertEqualObjects(SKOEventKindSymbol(SKOEventKindElectron), @"e⁻");
    XCTAssertEqualObjects(SKOEventKindSymbol(SKOEventKindGamma), @"γ");
    XCTAssertEqualObjects(SKOEventKindName(SKOEventKindMuon), @"muon");
    XCTAssertEqualObjects(SKOEventKindName(SKOEventKindElectron), @"electron");
    XCTAssertEqualObjects(SKOEventKindName(SKOEventKindGamma), @"gamma");
}

@end
