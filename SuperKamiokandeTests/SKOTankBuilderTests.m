#import <XCTest/XCTest.h>
#import <SceneKit/SceneKit.h>
#import "SKOTankBuilder.h"
#import "SKOCommon.h"

static SCNNode *SKOGroup(SCNNode *root, NSString *name)
{
    return [root childNodeWithName:name recursively:YES];
}

@interface SKOTankBuilderTests : XCTestCase
@property (nonatomic, strong) SCNNode *root;
@end

@implementation SKOTankBuilderTests

- (void)setUp
{
    [super setUp];
    self.root = [SCNNode node];
    self.root.name = @"testRoot";
    [SKOTankBuilder buildIntoRoot:self.root];
}

- (void)tearDown
{
    self.root = nil;
    [super tearDown];
}

- (void)testAllModelGroupsArePresent
{
    NSArray<NSString *> *names = @[
        @"cave", @"shell", @"structure", @"wallPMT", @"bottomPMT",
        @"topPMT", @"outerPMT", @"water", @"fiducial", @"tunnel",
        @"facility", @"anchor",
    ];
    for (NSString *name in names) {
        XCTAssertNotNil(SKOGroup(self.root, name), @"Missing model group: %@", name);
    }
}

- (void)testInnerDetectorHasExactlyElevenThousandPMTs
{
    SCNNode *wall = SKOGroup(self.root, @"wallPMT");
    SCNNode *bottom = SKOGroup(self.root, @"bottomPMT");
    SCNNode *top = SKOGroup(self.root, @"topPMT");
    XCTAssertNotNil(wall);
    XCTAssertNotNil(bottom);
    XCTAssertNotNil(top);

    // 67 rows x 159 wall PMTs + 252 bottom + 224 top = 11,129.
    XCTAssertEqual(wall.childNodes.count, 67 * 159);
    XCTAssertEqual(bottom.childNodes.count, 9 * 28);
    XCTAssertEqual(top.childNodes.count, 8 * 28);
    XCTAssertEqual(wall.childNodes.count + bottom.childNodes.count + top.childNodes.count,
                   SKOIDPMTCount);
}

- (void)testOuterDetectorHasExactlyTheReferenceCount
{
    SCNNode *outer = SKOGroup(self.root, @"outerPMT");
    XCTAssertNotNil(outer);
    XCTAssertEqual(outer.childNodes.count, 29 * 65);
}

- (void)testWaterFillAndTransparencySetters
{
    SCNNode *water = SKOGroup(self.root, @"water");
    SCNNode *body = [water childNodeWithName:@"waterBody" recursively:NO];
    SCNNode *surface = [water childNodeWithName:@"waterSurface" recursively:NO];
    XCTAssertNotNil(body);
    XCTAssertNotNil(surface);
    XCTAssertTrue([body.geometry isKindOfClass:[SCNCylinder class]]);

    [SKOTankBuilder setWaterFill:0.5 rootNode:self.root];
    SCNCylinder *cylinder = (SCNCylinder *)body.geometry;
    CGFloat expectedHeight = (SKOTankHeight - 1.0) * 0.5;
    XCTAssertEqualWithAccuracy(cylinder.height, expectedHeight, 0.001);
    XCTAssertEqualWithAccuracy(body.position.y, 0.5 + expectedHeight / 2.0, 0.001);
    XCTAssertEqualWithAccuracy(surface.position.y, 0.5 + expectedHeight + 0.03, 0.001);
    XCTAssertEqualWithAccuracy(body.opacity, 1.0, 0.001);
    XCTAssertEqualWithAccuracy(surface.opacity, 1.0, 0.001);

    [SKOTankBuilder setWaterFill:0.0 rootNode:self.root];
    XCTAssertEqualWithAccuracy(body.opacity, 0.0, 0.001);
    XCTAssertEqualWithAccuracy(surface.opacity, 0.0, 0.001);

    [SKOTankBuilder setWaterTransparency:0.62 rootNode:self.root];
    XCTAssertEqualWithAccuracy(body.geometry.materials.firstObject.transparency, 0.62, 0.001);
}

- (void)testFiducialAndShellControls
{
    SCNNode *fiducial = [SKOGroup(self.root, @"fiducial")
        childNodeWithName:@"fiducialBody" recursively:NO];
    XCTAssertNotNil(fiducial);
    [SKOTankBuilder setFiducialRadius:12.5 rootNode:self.root];
    XCTAssertTrue([fiducial.geometry isKindOfClass:[SCNCylinder class]]);
    XCTAssertEqualWithAccuracy(((SCNCylinder *)fiducial.geometry).radius, 12.5, 0.001);

    SCNNode *shell = SKOGroup(self.root, @"shell");
    XCTAssertGreaterThan(shell.childNodes.count, 0);
    [SKOTankBuilder setShellOpacity:0.42 rootNode:self.root];
    for (SCNNode *child in shell.childNodes) {
        XCTAssertEqualWithAccuracy(child.opacity, 0.42, 0.001);
    }
}

- (void)testExplodeMovesPartGroups
{
    SCNNode *outer = SKOGroup(self.root, @"outerPMT");
    SCNNode *shell = SKOGroup(self.root, @"shell");
    XCTAssertEqualWithAccuracy(outer.position.x, 0.0, 0.0001);
    XCTAssertEqualWithAccuracy(shell.position.x, 0.0, 0.0001);

    [SKOTankBuilder setExplodeAmount:1.0 rootNode:self.root];
    XCTAssertGreaterThan(fabs(outer.position.x), 0.0);
    XCTAssertGreaterThan(fabs(shell.position.x), 0.0);

    [SKOTankBuilder setExplodeAmount:0.0 rootNode:self.root];
    XCTAssertEqualWithAccuracy(outer.position.x, 0.0, 0.0001);
    XCTAssertEqualWithAccuracy(shell.position.x, 0.0, 0.0001);
}

- (void)testPMTRadiusScaleAppliesToAllArrays
{
    [SKOTankBuilder setPMTRadiusScale:1.4 rootNode:self.root];
    for (NSString *name in @[@"wallPMT", @"bottomPMT", @"topPMT", @"outerPMT"]) {
        SCNNode *group = SKOGroup(self.root, name);
        for (SCNNode *node in group.childNodes) {
            XCTAssertEqualWithAccuracy(node.scale.x, 1.4, 0.001);
        }
    }
}

- (void)testCherenkovRingAndMuonTrack
{
    SCNNode *ring = [SKOTankBuilder makeCherenkovRingWithEnergy:6.0
                                                     atPosition:SCNVector3Make(0, 18, 0)
                                                       direction:SCNVector3Make(0, 0, -1)
                                                           color:[SKColor cyanColor]];
    XCTAssertNotNil(ring);
    XCTAssertTrue([ring.geometry isKindOfClass:[SCNTorus class]]);
    XCTAssertTrue(ring.hasActions);

    SCNNode *track = [SKOTankBuilder makeMuonTrackWithEnergy:12.0
                                                  atPosition:SCNVector3Make(0, 18, 0)
                                                    direction:SCNVector3Make(0, 1, 0)
                                                        color:[SKColor magentaColor]];
    XCTAssertNotNil(track);
    XCTAssertTrue([track.geometry isKindOfClass:[SCNCylinder class]]);
}

- (void)testPMTFlashSpawnIsBoundedAndNamed
{
    SCNNode *wall = SKOGroup(self.root, @"wallPMT");
    NSUInteger before = wall.childNodes.count;
    [SKOTankBuilder flashPMTsInRoot:self.root
                          direction:SCNVector3Make(0, 0, -1)
                        sensitivity:1.0
                              color:[SKColor cyanColor]];
    XCTAssertGreaterThan(wall.childNodes.count, before);
    NSUInteger flashes = 0;
    for (SCNNode *node in wall.childNodes) {
        if ([node.name isEqualToString:@"pmtFlash"]) flashes += 1;
    }
    XCTAssertGreaterThan(flashes, 0);
    XCTAssertLessThanOrEqual(flashes, 140);
}

@end
