#import "SKOTankBuilder.h"
#import "SKOCommon.h"

static void doubleSide(SCNMaterial *m);


static const CGFloat kPMTRadius = 0.25;      // ~50 cm dome ⇒ 0.25 m radius
static NSString * const kGroupCave     = @"cave";
static NSString * const kGroupShell    = @"shell";
static NSString * const kGroupStructure= @"structure";
static NSString * const kGroupWallPMT  = @"wallPMT";
static NSString * const kGroupBottomPMT= @"bottomPMT";
static NSString * const kGroupTopPMT   = @"topPMT";
static NSString * const kGroupOuterPMT = @"outerPMT";
static NSString * const kGroupWater    = @"water";
static NSString * const kGroupFiducial = @"fiducial";
static NSString * const kGroupTunnel   = @"tunnel";
static NSString * const kGroupFacility = @"facility";
static NSString * const kGroupAnchor   = @"anchor";

static SCNNode *group(NSString *name, SCNNode *root)
{
    return [root childNodeWithName:name recursively:YES];
}

/// A partial cylindrical rock wall. Keeping the front 120° open preserves the
/// cutaway view while wrapping the detector in rock on every other side.
static SCNGeometry *SKOMakeArcWall(CGFloat radius, CGFloat height,
                                   CGFloat startDegrees, CGFloat endDegrees,
                                   NSUInteger segments)
{
    NSUInteger count = (segments + 1) * 2;
    SCNVector3 *positions = malloc(sizeof(SCNVector3) * count);
    SCNVector3 *normals   = malloc(sizeof(SCNVector3) * count);
    CGPoint    *uvs       = malloc(sizeof(CGPoint) * count);
    NSUInteger indexCount = segments * 6;
    uint32_t *indices = malloc(sizeof(uint32_t) * indexCount);

    CGFloat start = startDegrees * M_PI / 180.0;
    CGFloat end   = endDegrees * M_PI / 180.0;
    for (NSUInteger i = 0; i <= segments; ++i) {
        CGFloat t = (CGFloat)i / (CGFloat)segments;
        CGFloat angle = start + (end - start) * t;
        CGFloat x = radius * sin(angle);
        CGFloat z = radius * cos(angle);
        positions[i * 2 + 0] = SCNVector3Make(x, -height / 2.0, z);
        positions[i * 2 + 1] = SCNVector3Make(x,  height / 2.0, z);
        normals[i * 2 + 0] = SCNVector3Make(-sin(angle), 0, -cos(angle));
        normals[i * 2 + 1] = normals[i * 2 + 0];
        uvs[i * 2 + 0] = CGPointMake(t, 0);
        uvs[i * 2 + 1] = CGPointMake(t, 1);
        if (i < segments) {
            uint32_t a = (uint32_t)(i * 2);
            uint32_t b = a + 1;
            uint32_t c = a + 2;
            uint32_t d = a + 3;
            uint32_t *q = indices + i * 6;
            q[0] = a; q[1] = c; q[2] = b;
            q[3] = b; q[4] = c; q[5] = d;
        }
    }

    SCNGeometrySource *vertexSource =
        [SCNGeometrySource geometrySourceWithVertices:positions count:(NSInteger)count];
    SCNGeometrySource *normalSource =
        [SCNGeometrySource geometrySourceWithNormals:normals count:(NSInteger)count];
    SCNGeometrySource *uvSource =
        [SCNGeometrySource geometrySourceWithTextureCoordinates:uvs count:(NSInteger)count];
    NSData *indexData = [NSData dataWithBytes:indices
                                       length:sizeof(uint32_t) * indexCount];
    SCNGeometryElement *element =
        [SCNGeometryElement geometryElementWithData:indexData
                                      primitiveType:SCNGeometryPrimitiveTypeTriangles
                                     primitiveCount:segments * 2
                                      bytesPerIndex:sizeof(uint32_t)];
    SCNGeometry *geometry = [SCNGeometry geometryWithSources:@[vertexSource,
                                                               normalSource,
                                                               uvSource]
                                                   elements:@[element]];
    free(positions);
    free(normals);
    free(uvs);
    free(indices);
    return geometry;
}

/// Loads a texture from the app bundle or, for the offscreen preview / tests,
/// from the checked-in Textures folder relative to the current directory.
static NSImage *SKOTexture(NSString *name, NSString *extension)
{
    NSString *path = [[NSBundle mainBundle] pathForResource:name
                                                     ofType:extension
                                                inDirectory:@"Textures"];
    if (!path) {
        path = [[NSBundle mainBundle] pathForResource:name ofType:extension];
    }
    if (!path) {
        path = [NSString stringWithFormat:@"SuperKamiokande/Textures/%@.%@",
                name, extension];
    }
    return [[NSImage alloc] initWithContentsOfFile:path];
}

/// Shared brushed-metal material for the structural steel.
static SCNMaterial *SKOStructuralSteel(void)
{
    SCNMaterial *m = [SCNMaterial new];
    m.diffuse.contents   = [SKColor colorWithRed:0.42 green:0.47 blue:0.53 alpha:1.0];
    m.metalness.contents = @0.82;
    m.roughness.contents = @0.34;
    m.lightingModelName  = SCNLightingModelPhysicallyBased;
    return m;
}

/// A simple dark technical material for pipes and equipment housings.
static SCNMaterial *SKOMachineryMaterial(CGFloat r, CGFloat g, CGFloat b)
{
    SCNMaterial *m = [SCNMaterial new];
    m.diffuse.contents   = [SKColor colorWithRed:r green:g blue:b alpha:1.0];
    m.metalness.contents = @0.65;
    m.roughness.contents = @0.42;
    m.lightingModelName  = SCNLightingModelPhysicallyBased;
    return m;
}

/// Rotation that carries the torus/cylinder +Y axis onto `direction`.
static SCNVector4 SKORotationFromYToVector(SCNVector3 direction)
{
    CGFloat len = sqrt(direction.x * direction.x +
                       direction.y * direction.y +
                       direction.z * direction.z);
    if (len < 0.0001) return SCNVector4Make(0, 1, 0, 0);

    SCNVector3 n = SCNVector3Make(direction.x / len,
                                  direction.y / len,
                                  direction.z / len);
    CGFloat dot = MIN(MAX(n.y, -1.0), 1.0);
    CGFloat angle = acos(dot);
    SCNVector3 axis = SCNVector3Make(n.z, 0.0, -n.x);
    CGFloat axisLen = sqrt(axis.x * axis.x + axis.z * axis.z);

    if (axisLen > 0.0001) {
        return SCNVector4Make(axis.x / axisLen, 0.0, axis.z / axisLen, angle);
    }
    if (dot < 0.0) {
        return SCNVector4Make(1.0, 0.0, 0.0, M_PI);
    }
    return SCNVector4Make(0, 1, 0, 0);
}

@implementation SKOTankBuilder

+ (void)buildIntoRoot:(SCNNode *)root
{
    [self buildCavern:root];
    [self buildShell:root];
    [self buildStructure:root];
    [self buildWallPMTs:root];
    [self buildBottomPMTs:root];
    [self buildTopPMTs:root];
    [self buildOuterPMTs:root];
    [self buildWater:root];
    [self buildFiducial:root];
    [self buildTunnel:root];
    [self buildFacilities:root];
    [self buildAnchors:root];

    [self setWaterFill:1.0 rootNode:root];
    [self setFiducialRadius:8.0 rootNode:root];   // →22.5 kt equivalent
    [self setShellOpacity:0.35 rootNode:root];    // translucent enough to see the ID
}

#pragma mark - Cavern / mine overburden

+ (SCNMaterial *)SKORockMaterial:(CGFloat)transparency
{
    SCNMaterial *m = [SCNMaterial new];
    NSImage *rock = SKOTexture(@"CavernRock", @"png");
    if (rock) {
        m.diffuse.contents = rock;
        m.diffuse.wrapS = SCNWrapModeRepeat;
        m.diffuse.wrapT = SCNWrapModeRepeat;
        m.diffuse.contentsTransform = SCNMatrix4MakeScale(4.0, 2.0, 1.0);
    } else {
        m.diffuse.contents = [SKColor colorWithRed:0.24 green:0.23 blue:0.22 alpha:1.0];
    }
    m.roughness.contents = @0.96;
    m.metalness.contents = @0.03;
    m.transparency       = transparency;
    m.writesToDepthBuffer = NO;
    m.doubleSided        = YES;
    m.lightingModelName  = SCNLightingModelPhysicallyBased;
    return m;
}

+ (void)buildCavern:(SCNNode *)root
{
    SCNNode *cave = [SCNNode node];
    cave.name = kGroupCave;

    // Excavated cavern: a 184° rock wall with the front open for the cutaway
    // view, plus a rock ceiling over the back half.
    SCNGeometry *wallGeometry = SKOMakeArcWall(50.0, 62.0, 88.0, 272.0, 64);
    SCNMaterial *shellMat = [self SKORockMaterial:1.0];
    shellMat.writesToDepthBuffer = YES;
    shellMat.diffuse.contentsTransform = SCNMatrix4MakeScale(3.0, 2.0, 1.0);
    wallGeometry.materials = @[shellMat];
    SCNNode *wallNode = [SCNNode nodeWithGeometry:wallGeometry];
    wallNode.position = SCNVector3Make(0, 26.0, 0);
    [cave addChildNode:wallNode];

    SCNBox *ceiling = [SCNBox boxWithWidth:100.0 height:0.8 length:62.0
                             chamferRadius:0.2];
    SCNMaterial *ceilingMat = [self SKORockMaterial:1.0];
    ceilingMat.diffuse.contentsTransform = SCNMatrix4MakeScale(6.0, 6.0, 1.0);
    ceilingMat.doubleSided = YES;
    ceiling.materials = @[ceilingMat];
    SCNNode *ceilingNode = [SCNNode nodeWithGeometry:ceiling];
    ceilingNode.position = SCNVector3Make(0, 57.0, -23.0);
    [cave addChildNode:ceilingNode];

    // Cavern floor: rough rock disk with a smoother concrete apron under the
    // tank and facilities.
    SCNCylinder *floor = [SCNCylinder cylinderWithRadius:60.0 height:2.2];
    floor.radialSegmentCount = 72;
    SCNMaterial *rockFloor = [self SKORockMaterial:1.0];
    rockFloor.diffuse.contentsTransform = SCNMatrix4MakeScale(7.0, 7.0, 1.0);
    rockFloor.writesToDepthBuffer = YES;
    floor.materials = @[rockFloor];
    SCNNode *floorNode = [SCNNode nodeWithGeometry:floor];
    floorNode.position = SCNVector3Make(0, -1.1, 0);
    [cave addChildNode:floorNode];

    SCNCylinder *apron = [SCNCylinder cylinderWithRadius:30.0 height:0.5];
    apron.radialSegmentCount = 64;
    SCNMaterial *concrete = [SCNMaterial new];
    concrete.diffuse.contents   = [SKColor colorWithRed:0.30 green:0.31 blue:0.32 alpha:1.0];
    concrete.roughness.contents = @0.88;
    concrete.metalness.contents = @0.05;
    concrete.lightingModelName  = SCNLightingModelPhysicallyBased;
    apron.materials = @[concrete];
    SCNNode *apronNode = [SCNNode nodeWithGeometry:apron];
    apronNode.position = SCNVector3Make(0, 0.22, 0);
    [cave addChildNode:apronNode];

    // A few low-poly rock outcrops around the rim add parallax and scale.
    SCNSphere *boulder = [SCNSphere sphereWithRadius:1.0];
    boulder.segmentCount = 9;
    boulder.materials = @[[self SKORockMaterial:1.0]];
    SCNVector3 rockPositions[5] = {
        SCNVector3Make(-39, 2.5, -22),
        SCNVector3Make( 43, 3.0, -25),
        SCNVector3Make(-34, 1.8,  31),
        SCNVector3Make( 37, 2.2,  34),
        SCNVector3Make(  4, 1.5, -42),
    };
    SCNVector3 rockScales[5] = {
        SCNVector3Make(12, 7, 9),
        SCNVector3Make(14, 8, 10),
        SCNVector3Make(11, 6, 8),
        SCNVector3Make(15, 7, 11),
        SCNVector3Make(17, 8, 8),
    };
    for (NSUInteger i = 0; i < 5; ++i) {
        SCNNode *rock = [SCNNode nodeWithGeometry:boulder];
        rock.position = rockPositions[i];
        rock.scale = rockScales[i];
        rock.eulerAngles = SCNVector3Make(0.3 * i, 0.7 * i, 0.1 * i);
        [cave addChildNode:rock];
    }

    // Work lights wash the cavern walls in cool white.
    SCNVector3 lightPositions[3] = {
        SCNVector3Make(-26, 47, -20),
        SCNVector3Make( 28, 47, -18),
        SCNVector3Make(  0, 50,  22),
    };
    for (NSUInteger i = 0; i < 3; ++i) {
        SCNNode *lightNode = [SCNNode node];
        SCNLight *light = [SCNLight light];
        light.type = SCNLightTypeOmni;
        light.color = [SKColor colorWithRed:0.65 green:0.78 blue:0.95 alpha:1.0];
        light.intensity = 420;
        light.attenuationStartDistance = 12;
        light.attenuationEndDistance = 58;
        lightNode.light = light;
        lightNode.position = lightPositions[i];
        [cave addChildNode:lightNode];

        SCNSphere *lamp = [SCNSphere sphereWithRadius:0.22];
        lamp.segmentCount = 8;
        SCNMaterial *lampMat = [SCNMaterial new];
        lampMat.diffuse.contents = [SKColor colorWithRed:0.75 green:0.9 blue:1.0 alpha:1.0];
        lampMat.emission.contents = [SKColor colorWithRed:0.75 green:0.9 blue:1.0 alpha:1.0];
        lampMat.emission.intensity = 2.4;
        lampMat.lightingModelName = SCNLightingModelConstant;
        lamp.materials = @[lampMat];
        SCNNode *lampNode = [SCNNode nodeWithGeometry:lamp];
        lampNode.position = lightPositions[i];
        [cave addChildNode:lampNode];
    }

    [root addChildNode:cave];
}

#pragma mark - Steel shell (OD)

+ (void)buildShell:(SCNNode *)root
{
    SCNNode *shell = [SCNNode node];
    shell.name = kGroupShell;

    SCNCylinder *tank = [SCNCylinder cylinderWithRadius:SKOTankRadius
                                                 height:SKOTankHeight];
    tank.radialSegmentCount = 96;
    tank.heightSegmentCount = 1;

    SCNMaterial *steel = [SCNMaterial new];
    steel.diffuse.contents     = SKOSteelColor();
    steel.metalness.contents   = @0.88;
    steel.roughness.contents   = @0.26;
    steel.transparency         = 0.94;
    steel.writesToDepthBuffer  = NO;
    steel.lightingModelName    = SCNLightingModelPhysicallyBased;
    doubleSide(steel);
    tank.materials = @[steel];

    SCNNode *tankNode = [SCNNode nodeWithGeometry:tank];
    tankNode.position = SCNVector3Make(0, SKOTankHeight / 2.0, 0);
    [shell addChildNode:tankNode];

    // Reinforcing rings around the shell — the real tank is a segmented
    // stainless-steel pressure vessel, not a smooth cylinder.
    NSUInteger ringCount = 9;
    for (NSUInteger i = 0; i < ringCount; ++i) {
        CGFloat h = SKOTankHeight * (CGFloat)(i + 1) / (CGFloat)(ringCount + 1);
        SCNCylinder *ring = [SCNCylinder cylinderWithRadius:SKOTankRadius + 0.22 height:0.55];
        ring.radialSegmentCount = 96;
        SCNMaterial *ringMat = [SCNMaterial new];
        ringMat.diffuse.contents   = [SKColor colorWithRed:0.48 green:0.53 blue:0.60 alpha:1.0];
        ringMat.metalness.contents = @0.9;
        ringMat.roughness.contents = @0.24;
        ringMat.transparency       = 0.92;
        ringMat.lightingModelName  = SCNLightingModelPhysicallyBased;
        ring.materials = @[ringMat];
        SCNNode *ringNode = [SCNNode nodeWithGeometry:ring];
        ringNode.position = SCNVector3Make(0, h, 0);
        [shell addChildNode:ringNode];
    }

    // The tank top is an annular deck with a central opening for the water
    // surface and the top PMT array, just like the real detector.
    SCNTube *lid = [SCNTube tubeWithInnerRadius:7.2
                                   outerRadius:SKOTankRadius + 0.6
                                        height:0.55];
    lid.radialSegmentCount = 96;
    SCNMaterial *lidMat = [SCNMaterial new];
    lidMat.diffuse.contents   = [SKColor colorWithRed:0.44 green:0.49 blue:0.55 alpha:1.0];
    lidMat.metalness.contents = @0.82;
    lidMat.roughness.contents = @0.32;
    lidMat.lightingModelName  = SCNLightingModelPhysicallyBased;
    lid.materials = @[lidMat];
    SCNNode *lidNode = [SCNNode nodeWithGeometry:lid];
    lidNode.position = SCNVector3Make(0, SKOTankHeight + 0.28, 0);
    [shell addChildNode:lidNode];

    SCNTorus *rim = [SCNTorus torusWithRingRadius:SKOTankRadius + 0.55
                                       pipeRadius:0.35];
    rim.ringSegmentCount = 96;
    rim.pipeSegmentCount = 8;
    rim.materials = @[SKOStructuralSteel()];
    SCNNode *rimNode = [SCNNode nodeWithGeometry:rim];
    rimNode.position = SCNVector3Make(0, SKOTankHeight + 0.5, 0);
    [shell addChildNode:rimNode];

    [root addChildNode:shell];
}

static void doubleSide(SCNMaterial *m)
{
    m.diffuse.intensity      = 1.0;
    m.doubleSided            = YES;
}

#pragma mark - Support structure and top deck

+ (void)buildStructure:(SCNNode *)root
{
    SCNNode *groupNode = [SCNNode node];
    groupNode.name = kGroupStructure;
    SCNMaterial *steel = SKOStructuralSteel();

    // Vertical ribs around the tank wall.
    NSUInteger ribCount = 20;
    for (NSUInteger i = 0; i < ribCount; ++i) {
        CGFloat theta = 2.0 * M_PI * (CGFloat)i / (CGFloat)ribCount;
        SCNBox *rib = [SCNBox boxWithWidth:0.26 height:SKOTankHeight
                                   length:0.50 chamferRadius:0.04];
        rib.materials = @[steel];
        SCNNode *ribNode = [SCNNode nodeWithGeometry:rib];
        ribNode.position = SCNVector3Make((SKOTankRadius + 0.30) * sin(theta),
                                          SKOTankHeight / 2.0,
                                          (SKOTankRadius + 0.30) * cos(theta));
        ribNode.eulerAngles = SCNVector3Make(0, theta, 0);
        [groupNode addChildNode:ribNode];
    }

    // Top catwalk and guard rail.
    SCNTube *catwalk = [SCNTube tubeWithInnerRadius:20.2 outerRadius:22.2 height:0.40];
    catwalk.radialSegmentCount = 96;
    catwalk.materials = @[steel];
    SCNNode *catwalkNode = [SCNNode nodeWithGeometry:catwalk];
    catwalkNode.position = SCNVector3Make(0, SKOTankHeight - 0.6, 0);
    [groupNode addChildNode:catwalkNode];

    SCNTorus *handrail = [SCNTorus torusWithRingRadius:22.05 pipeRadius:0.07];
    handrail.ringSegmentCount = 96;
    handrail.pipeSegmentCount = 6;
    handrail.materials = @[steel];
    SCNNode *handrailNode = [SCNNode nodeWithGeometry:handrail];
    handrailNode.position = SCNVector3Make(0, SKOTankHeight + 0.75, 0);
    [groupNode addChildNode:handrailNode];

    for (NSUInteger i = 0; i < 32; ++i) {
        CGFloat theta = 2.0 * M_PI * (CGFloat)i / 32.0;
        SCNCylinder *post = [SCNCylinder cylinderWithRadius:0.05 height:1.35];
        post.radialSegmentCount = 6;
        post.materials = @[steel];
        SCNNode *postNode = [SCNNode nodeWithGeometry:post];
        postNode.position = SCNVector3Make(22.05 * sin(theta),
                                           SKOTankHeight + 0.10,
                                           22.05 * cos(theta));
        [groupNode addChildNode:postNode];
    }

    // Heavy support pylons around the back and sides.
    NSArray<NSNumber *> *pylonAngles = @[@70, @110, @150, @190, @230, @270];
    for (NSNumber *degrees in pylonAngles) {
        CGFloat theta = degrees.doubleValue * M_PI / 180.0;
        SCNBox *pylon = [SCNBox boxWithWidth:0.7 height:SKOTankHeight + 1.6
                                     length:0.7 chamferRadius:0.05];
        pylon.materials = @[steel];
        SCNNode *pylonNode = [SCNNode nodeWithGeometry:pylon];
        pylonNode.position = SCNVector3Make(23.3 * sin(theta),
                                            (SKOTankHeight + 1.6) / 2.0,
                                            23.3 * cos(theta));
        pylonNode.eulerAngles = SCNVector3Make(0, theta, 0);
        [groupNode addChildNode:pylonNode];

        for (NSUInteger level = 1; level <= 3; ++level) {
            SCNBox *brace = [SCNBox boxWithWidth:0.4 height:0.4 length:2.6
                                      chamferRadius:0.04];
            brace.materials = @[steel];
            SCNNode *braceNode = [SCNNode nodeWithGeometry:brace];
            braceNode.position = SCNVector3Make(22.4 * sin(theta),
                                                level * SKOTankHeight / 4.0,
                                                22.4 * cos(theta));
            braceNode.eulerAngles = SCNVector3Make(0, theta, 0);
            [groupNode addChildNode:braceNode];
        }
    }

    // Service ladder on the left side of the tank.
    CGFloat ladderTheta = 298.0 * M_PI / 180.0;
    for (NSUInteger i = 0; i < 2; ++i) {
        CGFloat side = (i == 0) ? -0.45 : 0.45;
        SCNCylinder *rail = [SCNCylinder cylinderWithRadius:0.06
                                                     height:SKOTankHeight - 2.0];
        rail.radialSegmentCount = 6;
        rail.materials = @[steel];
        SCNNode *railNode = [SCNNode nodeWithGeometry:rail];
        railNode.position = SCNVector3Make(21.2 * sin(ladderTheta) + side * cos(ladderTheta),
                                           SKOTankHeight / 2.0,
                                           21.2 * cos(ladderTheta) - side * sin(ladderTheta));
        [groupNode addChildNode:railNode];
    }
    for (NSUInteger i = 0; i < 24; ++i) {
        SCNBox *rung = [SCNBox boxWithWidth:0.85 height:0.05 length:0.08
                                  chamferRadius:0.01];
        rung.materials = @[steel];
        SCNNode *rungNode = [SCNNode nodeWithGeometry:rung];
        rungNode.position = SCNVector3Make(21.2 * sin(ladderTheta),
                                           1.4 + i * 1.6,
                                           21.2 * cos(ladderTheta));
        rungNode.eulerAngles = SCNVector3Make(0, ladderTheta, 0);
        [groupNode addChildNode:rungNode];
    }

    [root addChildNode:groupNode];
}

#pragma mark - Outer-detector PMTs (1,885 x 8-inch, instanced)

+ (void)buildOuterPMTs:(SCNNode *)root
{
    SCNNode *groupNode = [SCNNode node];
    groupNode.name = kGroupOuterPMT;

    SCNSphere *pmt = [SCNSphere sphereWithRadius:0.11];
    pmt.segmentCount = 6;
    SCNMaterial *m = [SCNMaterial new];
    m.diffuse.contents   = [SKColor colorWithRed:0.58 green:0.58 blue:0.46 alpha:1.0];
    m.emission.contents  = [SKColor colorWithRed:0.55 green:0.43 blue:0.19 alpha:1.0];
    m.emission.intensity = 0.35;
    m.lightingModelName  = SCNLightingModelConstant;
    pmt.materials = @[m];

    const NSUInteger rows = 29;
    const NSUInteger perRow = 65;              // 29 × 65 = 1,885
    for (NSUInteger r = 0; r < rows; ++r) {
        CGFloat y = 2.0 + (SKOTankHeight - 4.0) * (CGFloat)r / (CGFloat)(rows - 1);
        for (NSUInteger i = 0; i < perRow; ++i) {
            // Leave the front cutaway open, as in a real detector-hall view.
            CGFloat theta = M_PI / 4.0
                          + (1.5 * M_PI) * (CGFloat)i / (CGFloat)(perRow - 1);
            SCNNode *node = [SCNNode nodeWithGeometry:pmt];
            node.position = SCNVector3Make(22.8 * sin(theta), y, 22.8 * cos(theta));
            [groupNode addChildNode:node];
        }
    }

    [root addChildNode:groupNode];
}

#pragma mark - Inner-detector PMTs (11,129, instanced)

+ (void)buildWallPMTs:(SCNNode *)root
{
    SCNNode *groupNode = [SCNNode node];
    groupNode.name = kGroupWallPMT;

    // One PMT geometry + material, instantiated thousands of times.
    // Real ID PMTs are discs whose photocathode faces the tank centre.
    SCNGeometry *pmtGeom = [self pmtDiscGeometry:0.21 height:0.09];

    // The real ID has 11,129 20" PMTs. Top and bottom arrays contribute
    // 476 nodes, so size the wall grid to land close to the real total.
    NSUInteger perRow  = (NSUInteger)(2.0 * M_PI * (SKOTankRadius - 0.4)
                                     / (2.0 * 0.21 * 1.35));
    if (perRow < 40)  perRow = 40;
    // 10,653 wall PMTs divide evenly into 67 rows of 159; with 476 top and
    // bottom PMTs that lands exactly on the real 11,129.
    if (perRow > 159) perRow = 159;

    NSUInteger fixedArrays = 9 * 28 + 8 * 28;    // bottom + top rings
    NSUInteger wallTarget  = SKOIDPMTCount > fixedArrays
                           ? SKOIDPMTCount - fixedArrays : 1;
    NSUInteger rows = (wallTarget + perRow - 1) / perRow;

    for (NSUInteger r = 0; r < rows; ++r) {
        CGFloat y = 1.8 + (SKOTankHeight - 3.6) * r / (rows - 1.0);
        for (NSUInteger i = 0; i < perRow; ++i) {
            CGFloat theta = (2.0 * M_PI) * i / perRow;
            SCNVector3 p = SCNVector3Make((SKOTankRadius - 0.30) * sin(theta),
                                          y,
                                          (SKOTankRadius - 0.30) * cos(theta));
            // Point the photocathode disc radially inward toward the tank axis.
            SCNVector3 inward = SCNVector3Make(-sin(theta), 0, -cos(theta));
            SCNVector4 rot = SKORotationFromYToVector(inward);
            SCNNode *pmt = [self pmtNodeForGeometry:pmtGeom at:p rotation:rot];
            [groupNode addChildNode:pmt];
        }
    }

    [root addChildNode:groupNode];
}

+ (SCNNode *)pmtNodeForGeometry:(SCNGeometry *)geometry at:(SCNVector3)position rotation:(SCNVector4)rotation
{
    SCNNode *n = [SCNNode nodeWithGeometry:geometry];
    n.position = position;
    n.rotation = rotation;
    n.name = @"pmt";
    return n;
}

/// Photocathode disc (the part that faces the tank centre) with a small
/// metal housing on the rear. materials[0] = side, [1]/[2] = front/back face.
+ (SCNGeometry *)pmtDiscGeometry:(CGFloat)radius height:(CGFloat)height
{
    SCNCylinder *disc = [SCNCylinder cylinderWithRadius:radius height:height];
    disc.radialSegmentCount = 16;

    SCNMaterial *side = [SCNMaterial new];
    side.diffuse.contents   = [SKColor colorWithRed:0.50 green:0.52 blue:0.58 alpha:1.0];
    side.metalness.contents = @0.85;
    side.roughness.contents = @0.35;
    side.lightingModelName  = SCNLightingModelPhysicallyBased;

    SCNMaterial *face = [SCNMaterial new];
    face.diffuse.contents   = [SKColor colorWithRed:0.80 green:0.63 blue:0.28 alpha:1.0];
    face.emission.contents  = [SKColor colorWithRed:0.62 green:0.45 blue:0.16 alpha:1.0];
    face.emission.intensity = 0.38;
    face.metalness.contents = @0.45;
    face.roughness.contents = @0.30;
    face.lightingModelName  = SCNLightingModelPhysicallyBased;

    disc.materials = @[side, face, face];
    return disc;
}

#pragma mark - Bottom / top PMT arrays

+ (void)buildBottomPMTs:(SCNNode *)root
{
    SCNNode *groupNode = [SCNNode node];
    groupNode.name = kGroupBottomPMT;

    // Bottom PMTs: photocathode discs facing up into the tank.
    SCNGeometry *pmtGeom = [self pmtDiscGeometry:0.19 height:0.07];

    NSUInteger nSide = 28;                       // spokes per ring
    for (NSUInteger ring = 0; ring < 9; ++ring) {
        CGFloat radius = (ring + 1) * (SKOTankRadius * 0.9) / 9.0;
        for (NSUInteger i = 0; i < nSide; ++i) {
            CGFloat theta = (2.0 * M_PI) * i / nSide;
            SCNNode *pmt = [self pmtNodeForGeometry:pmtGeom
                                                at:SCNVector3Make(radius * sin(theta),
                                                                  0.35,
                                                                  radius * cos(theta))
                                           rotation:SCNVector4Make(0, 1, 0, 0)];
            if (radius > SKOTankRadius * 0.94) break;
            [groupNode addChildNode:pmt];
        }
    }
    [root addChildNode:groupNode];
}

+ (void)buildTopPMTs:(SCNNode *)root
{
    SCNNode *groupNode = [SCNNode node];
    groupNode.name = kGroupTopPMT;

    // Top "passive" region: photocathode discs facing down into the tank.
    SCNGeometry *pmtGeom = [self pmtDiscGeometry:0.19 height:0.07];

    NSUInteger nSide = 28;
    for (NSUInteger ring = 0; ring < 8; ++ring) {
        CGFloat radius = (ring + 1) * (SKOTankRadius * 0.92) / 8.0;
        for (NSUInteger i = 0; i < nSide; ++i) {
            CGFloat theta = (2.0 * M_PI) * i / nSide;
            SCNNode *pmt = [self pmtNodeForGeometry:pmtGeom
                                                at:SCNVector3Make(radius * sin(theta),
                                                                  SKOTankHeight - 0.35,
                                                                  radius * cos(theta))
                                           rotation:SCNVector4Make(1, 0, 0, M_PI)];
            if (radius > SKOTankRadius * 0.95) break;
            [groupNode addChildNode:pmt];
        }
    }
    [root addChildNode:groupNode];
}

#pragma mark - Water volume

+ (void)buildWater:(SCNNode *)root
{
    SCNCylinder *water = [SCNCylinder cylinderWithRadius:SKOTankRadius - 0.35
                                                 height:SKOTankHeight - 1.0];
    water.radialSegmentCount = 64;
    SCNMaterial *w = [SCNMaterial new];
    w.diffuse.contents        = SKOWaterColor();
    w.emission.contents       = [SKColor colorWithRed:0.03 green:0.15 blue:0.27 alpha:1.0];
    w.emission.intensity      = 0.35;
    w.transparency            = 0.30;
    w.writesToDepthBuffer     = NO;
    w.lightingModelName       = SCNLightingModelBlinn;
    w.doubleSided             = YES;
    water.materials = @[w];

    SCNNode *waterNode = [SCNNode nodeWithGeometry:water];
    waterNode.name = @"waterBody";
    waterNode.castsShadow = NO;

    // A luminous water surface built from the reference photograph.
    SCNCylinder *surface = [SCNCylinder cylinderWithRadius:SKOTankRadius - 0.5
                                                   height:0.06];
    surface.radialSegmentCount = 96;
    SCNMaterial *surfaceMat = [SCNMaterial new];
    NSImage *surfaceImage = SKOTexture(@"WaterSurface", @"png");
    if (surfaceImage) {
        surfaceMat.diffuse.contents = surfaceImage;
        surfaceMat.diffuse.wrapS = SCNWrapModeRepeat;
        surfaceMat.diffuse.wrapT = SCNWrapModeRepeat;
        surfaceMat.diffuse.contentsTransform = SCNMatrix4MakeScale(4.0, 1.0, 1.0);
    } else {
        surfaceMat.diffuse.contents = [SKColor colorWithRed:0.18 green:0.48 blue:0.82 alpha:1.0];
    }
    surfaceMat.emission.contents = [SKColor colorWithRed:0.08 green:0.35 blue:0.60 alpha:1.0];
    surfaceMat.emission.intensity = 0.55;
    surfaceMat.transparency = 0.82;
    surfaceMat.writesToDepthBuffer = NO;
    surfaceMat.lightingModelName = SCNLightingModelConstant;
    surfaceMat.doubleSided = YES;
    surface.materials = @[surfaceMat];

    SCNNode *surfaceNode = [SCNNode nodeWithGeometry:surface];
    surfaceNode.name = @"waterSurface";
    surfaceNode.castsShadow = NO;

    // The water glows faintly from Cherenkov light in the reference image.
    SCNNode *glowNode = [SCNNode node];
    SCNLight *glow = [SCNLight light];
    glow.type = SCNLightTypeOmni;
    glow.color = [SKColor colorWithRed:0.24 green:0.62 blue:1.0 alpha:1.0];
    glow.intensity = 380;
    glow.attenuationStartDistance = 8;
    glow.attenuationEndDistance = 42;
    glowNode.light = glow;
    glowNode.position = SCNVector3Make(0, SKOTankHeight * 0.72, 0);

    SCNNode *groupNode = [SCNNode node];
    groupNode.name = kGroupWater;
    [groupNode addChildNode:waterNode];
    [groupNode addChildNode:surfaceNode];
    [groupNode addChildNode:glowNode];
    [root addChildNode:groupNode];
}

#pragma mark - Fiducial volume

+ (void)buildFiducial:(SCNNode *)root
{
    SCNCylinder *fid = [SCNCylinder cylinderWithRadius:8.0 height:SKOTankHeight * 0.75];
    fid.radialSegmentCount = 32;

    SCNMaterial *m = [SCNMaterial new];
    m.diffuse.contents    = SKOFiducialColor();
    m.emission.contents   = SKOFiducialColor();
    m.emission.intensity  = 0.8;
    m.transparency        = 0.30;
    m.fillMode            = SCNFillModeLines;
    m.writesToDepthBuffer = NO;
    m.lightingModelName   = SCNLightingModelConstant;
    fid.materials = @[m];

    SCNNode *fidNode = [SCNNode nodeWithGeometry:fid];
    fidNode.name = @"fiducialBody";
    fidNode.position = SCNVector3Make(0, SKOTankHeight / 2.0, 0);

    SCNNode *groupNode = [SCNNode node];
    groupNode.name = kGroupFiducial;
    [groupNode addChildNode:fidNode];
    [root addChildNode:groupNode];
}

#pragma mark - Access tunnel

+ (void)buildTunnel:(SCNNode *)root
{
    SCNNode *groupNode = [SCNNode node];
    groupNode.name = kGroupTunnel;

    // A 26 m concrete service tunnel entering the cavern at tank-top height.
    SCNTube *tube = [SCNTube tubeWithInnerRadius:3.6 outerRadius:4.5 height:26.0];
    tube.radialSegmentCount = 48;
    SCNMaterial *concrete = [SCNMaterial new];
    concrete.diffuse.contents   = [SKColor colorWithRed:0.30 green:0.29 blue:0.28 alpha:1.0];
    concrete.roughness.contents = @0.90;
    concrete.metalness.contents = @0.06;
    concrete.lightingModelName  = SCNLightingModelPhysicallyBased;
    concrete.doubleSided        = YES;
    tube.materials = @[concrete];

    SCNNode *tubeNode = [SCNNode nodeWithGeometry:tube];
    tubeNode.position = SCNVector3Make(-33.0, SKOTankHeight - 3.2, 0);
    tubeNode.eulerAngles = SCNVector3Make(0, 0, M_PI_2);
    [groupNode addChildNode:tubeNode];

    // Interior road deck.
    SCNBox *floor = [SCNBox boxWithWidth:26.0 height:0.3 length:7.0 chamferRadius:0];
    floor.materials = @[SKOMachineryMaterial(0.22, 0.23, 0.24)];
    SCNNode *floorNode = [SCNNode nodeWithGeometry:floor];
    floorNode.position = SCNVector3Make(-33.0, SKOTankHeight - 6.8, 0);
    [groupNode addChildNode:floorNode];

    // Flanges at both ends.
    for (NSUInteger i = 0; i < 2; ++i) {
        SCNTorus *flange = [SCNTorus torusWithRingRadius:4.5 pipeRadius:0.35];
        flange.ringSegmentCount = 48;
        flange.pipeSegmentCount = 8;
        flange.materials = @[SKOStructuralSteel()];
        SCNNode *flangeNode = [SCNNode nodeWithGeometry:flange];
        flangeNode.position = SCNVector3Make(i == 0 ? -20.2 : -45.8,
                                             SKOTankHeight - 3.2, 0);
        flangeNode.eulerAngles = SCNVector3Make(0, 0, M_PI_2);
        [groupNode addChildNode:flangeNode];
    }

    // Ceiling light strips in the tunnel.
    for (NSUInteger i = 0; i < 6; ++i) {
        SCNBox *strip = [SCNBox boxWithWidth:1.8 height:0.08 length:0.30
                                 chamferRadius:0.02];
        SCNMaterial *stripMat = [SCNMaterial new];
        stripMat.diffuse.contents = [SKColor colorWithRed:0.72 green:0.86 blue:1.0 alpha:1];
        stripMat.emission.contents = [SKColor colorWithRed:0.72 green:0.86 blue:1.0 alpha:1];
        stripMat.emission.intensity = 1.8;
        stripMat.lightingModelName = SCNLightingModelConstant;
        strip.materials = @[stripMat];
        SCNNode *stripNode = [SCNNode nodeWithGeometry:strip];
        stripNode.position = SCNVector3Make(-23.5 - i * 4.0,
                                            SKOTankHeight - 0.5, 0);
        [groupNode addChildNode:stripNode];
    }

    // Collar where the tunnel meets the tank-top deck.
    SCNCylinder *collar = [SCNCylinder cylinderWithRadius:5.2 height:1.0];
    collar.radialSegmentCount = 48;
    collar.materials = @[SKOStructuralSteel()];
    SCNNode *collarNode = [SCNNode nodeWithGeometry:collar];
    collarNode.position = SCNVector3Make(-SKOTankRadius - 0.5,
                                         SKOTankHeight - 3.2, 0);
    collarNode.eulerAngles = SCNVector3Make(0, 0, M_PI_2);
    [groupNode addChildNode:collarNode];

    [root addChildNode:groupNode];
}

#pragma mark - Surface facilities, control room and access shaft

+ (void)buildFacilities:(SCNNode *)root
{
    SCNNode *groupNode = [SCNNode node];
    groupNode.name = kGroupFacility;

    SCNMaterial *concrete = [SCNMaterial new];
    concrete.diffuse.contents   = [SKColor colorWithRed:0.31 green:0.33 blue:0.35 alpha:1.0];
    concrete.roughness.contents = @0.82;
    concrete.metalness.contents = @0.05;
    concrete.lightingModelName  = SCNLightingModelPhysicallyBased;

    SCNMaterial *windowMat = [SCNMaterial new];
    windowMat.diffuse.contents = [SKColor colorWithRed:0.20 green:0.58 blue:0.78 alpha:1.0];
    windowMat.emission.contents = [SKColor colorWithRed:0.30 green:0.80 blue:1.0 alpha:1.0];
    windowMat.emission.intensity = 1.8;
    windowMat.lightingModelName = SCNLightingModelConstant;

    // Control room perched above the cavern, connected by a bridge.
    SCNBox *controlRoom = [SCNBox boxWithWidth:15.0 height:5.0 length:9.0
                                  chamferRadius:0.25];
    controlRoom.materials = @[concrete];
    SCNNode *controlNode = [SCNNode nodeWithGeometry:controlRoom];
    controlNode.position = SCNVector3Make(33.0, 44.5, -17.5);
    [groupNode addChildNode:controlNode];

    SCNBox *controlRoof = [SCNBox boxWithWidth:16.0 height:0.35 length:10.0
                                  chamferRadius:0.08];
    controlRoof.materials = @[SKOStructuralSteel()];
    SCNNode *roofNode = [SCNNode nodeWithGeometry:controlRoof];
    roofNode.position = SCNVector3Make(33.0, 47.2, -17.5);
    [groupNode addChildNode:roofNode];

    for (NSUInteger i = 0; i < 4; ++i) {
        SCNBox *pane = [SCNBox boxWithWidth:2.2 height:1.3 length:0.08
                               chamferRadius:0.02];
        pane.materials = @[windowMat];
        SCNNode *paneNode = [SCNNode nodeWithGeometry:pane];
        paneNode.position = SCNVector3Make(27.2 + i * 3.2, 45.3, -12.95);
        [groupNode addChildNode:paneNode];
    }

    // Antenna and beacon.
    SCNCylinder *mast = [SCNCylinder cylinderWithRadius:0.10 height:4.0];
    mast.radialSegmentCount = 8;
    mast.materials = @[SKOStructuralSteel()];
    SCNNode *mastNode = [SCNNode nodeWithGeometry:mast];
    mastNode.position = SCNVector3Make(38.0, 49.4, -19.5);
    [groupNode addChildNode:mastNode];

    // Support columns under the control room.
    for (NSUInteger i = 0; i < 2; ++i) {
        SCNCylinder *column = [SCNCylinder cylinderWithRadius:0.35 height:42.0];
        column.radialSegmentCount = 12;
        column.materials = @[SKOStructuralSteel()];
        SCNNode *columnNode = [SCNNode nodeWithGeometry:column];
        columnNode.position = SCNVector3Make(28.0 + i * 10.0, 21.0, -21.0);
        [groupNode addChildNode:columnNode];
    }

    // Walkway bridge from the tank top to the control room.
    SCNBox *bridge = [SCNBox boxWithWidth:15.5 height:0.35 length:2.4
                             chamferRadius:0.06];
    bridge.materials = @[SKOStructuralSteel()];
    SCNNode *bridgeNode = [SCNNode nodeWithGeometry:bridge];
    bridgeNode.position = SCNVector3Make(25.6, 42.1, -17.5);
    [groupNode addChildNode:bridgeNode];
    for (NSUInteger i = 0; i < 2; ++i) {
        SCNBox *rail = [SCNBox boxWithWidth:15.5 height:0.08 length:0.08
                               chamferRadius:0.01];
        rail.materials = @[SKOStructuralSteel()];
        SCNNode *railNode = [SCNNode nodeWithGeometry:rail];
        railNode.position = SCNVector3Make(25.6, 43.1, -18.6 + i * 2.2);
        [groupNode addChildNode:railNode];
    }

    // Top access shaft with a domed lid.
    SCNCylinder *shaft = [SCNCylinder cylinderWithRadius:2.3 height:6.4];
    shaft.radialSegmentCount = 32;
    shaft.materials = @[concrete];
    SCNNode *shaftNode = [SCNNode nodeWithGeometry:shaft];
    shaftNode.position = SCNVector3Make(10.0, 44.5, -7.0);
    [groupNode addChildNode:shaftNode];

    SCNSphere *cap = [SCNSphere sphereWithRadius:2.6];
    cap.segmentCount = 24;
    cap.materials = @[SKOStructuralSteel()];
    SCNNode *capNode = [SCNNode nodeWithGeometry:cap];
    capNode.position = SCNVector3Make(10.0, 47.4, -7.0);
    capNode.scale = SCNVector3Make(1.0, 0.55, 1.0);
    [groupNode addChildNode:capNode];

    for (NSUInteger i = 0; i < 8; ++i) {
        SCNBox *rung = [SCNBox boxWithWidth:1.0 height:0.06 length:0.10
                                chamferRadius:0.01];
        rung.materials = @[SKOStructuralSteel()];
        SCNNode *rungNode = [SCNNode nodeWithGeometry:rung];
        rungNode.position = SCNVector3Make(10.0, 41.8 + i * 0.72, -4.65);
        [groupNode addChildNode:rungNode];
    }

    // Water-purification skid.
    SCNBox *skid = [SCNBox boxWithWidth:13.0 height:1.0 length:6.5
                           chamferRadius:0.08];
    skid.materials = @[SKOMachineryMaterial(0.25, 0.30, 0.33)];
    SCNNode *skidNode = [SCNNode nodeWithGeometry:skid];
    skidNode.position = SCNVector3Make(28.0, 0.85, 13.0);
    [groupNode addChildNode:skidNode];

    SCNMaterial *tankMat = SKOMachineryMaterial(0.36, 0.47, 0.52);
    for (NSUInteger i = 0; i < 3; ++i) {
        SCNCylinder *tank = [SCNCylinder cylinderWithRadius:1.15 height:3.2];
        tank.radialSegmentCount = 24;
        tank.materials = @[tankMat];
        SCNNode *tankNode = [SCNNode nodeWithGeometry:tank];
        tankNode.position = SCNVector3Make(24.0 + i * 4.0, 2.9, 13.0);
        [groupNode addChildNode:tankNode];

        SCNTorus *band = [SCNTorus torusWithRingRadius:1.18 pipeRadius:0.08];
        band.ringSegmentCount = 24;
        band.pipeSegmentCount = 6;
        band.materials = @[SKOStructuralSteel()];
        SCNNode *bandNode = [SCNNode nodeWithGeometry:band];
        bandNode.position = SCNVector3Make(24.0 + i * 4.0, 3.9, 13.0);
        bandNode.eulerAngles = SCNVector3Make(M_PI_2, 0, 0);
        [groupNode addChildNode:bandNode];
    }

    for (NSUInteger i = 0; i < 3; ++i) {
        SCNCylinder *pipe = [SCNCylinder cylinderWithRadius:0.16 height:20.0];
        pipe.radialSegmentCount = 12;
        pipe.materials = @[SKOStructuralSteel()];
        SCNNode *pipeNode = [SCNNode nodeWithGeometry:pipe];
        pipeNode.position = SCNVector3Make(8.8 + i * 0.55, 0.55, 2.0);
        pipeNode.eulerAngles = SCNVector3Make(M_PI_2, 0, 0);
        [groupNode addChildNode:pipeNode];
    }

    // Readout electronics hut.
    SCNBox *hut = [SCNBox boxWithWidth:8.0 height:3.4 length:5.5
                          chamferRadius:0.15];
    hut.materials = @[concrete];
    SCNNode *hutNode = [SCNNode nodeWithGeometry:hut];
    hutNode.position = SCNVector3Make(5.0, 1.7, 25.0);
    [groupNode addChildNode:hutNode];

    SCNBox *hutRoof = [SCNBox boxWithWidth:8.8 height:0.25 length:6.2
                              chamferRadius:0.05];
    hutRoof.materials = @[SKOMachineryMaterial(0.22, 0.24, 0.27)];
    SCNNode *hutRoofNode = [SCNNode nodeWithGeometry:hutRoof];
    hutRoofNode.position = SCNVector3Make(5.0, 3.5, 25.0);
    [groupNode addChildNode:hutRoofNode];

    for (NSUInteger i = 0; i < 2; ++i) {
        SCNBox *pane = [SCNBox boxWithWidth:2.4 height:1.2 length:0.08
                               chamferRadius:0.02];
        pane.materials = @[windowMat];
        SCNNode *paneNode = [SCNNode nodeWithGeometry:pane];
        paneNode.position = SCNVector3Make(3.0 + i * 4.0, 1.9, 27.78);
        [groupNode addChildNode:paneNode];
    }

    // A couple of instrument cabinets between the skid and the hut.
    for (NSUInteger i = 0; i < 4; ++i) {
        SCNBox *cabinet = [SCNBox boxWithWidth:1.5 height:1.8 length:1.0
                                  chamferRadius:0.05];
        cabinet.materials = @[SKOMachineryMaterial(0.30, 0.33, 0.37)];
        SCNNode *cabinetNode = [SCNNode nodeWithGeometry:cabinet];
        cabinetNode.position = SCNVector3Make(16.5 + i * 1.8, 0.9, 21.0);
        [groupNode addChildNode:cabinetNode];
    }

    // Practical lamps on the control room and hut.
    SCNVector3 lampPositions[2] = {
        SCNVector3Make(33.0, 41.2, -12.7),
        SCNVector3Make(5.0, 3.3, 27.9),
    };
    for (NSUInteger i = 0; i < 2; ++i) {
        SCNNode *lampNode = [SCNNode node];
        SCNLight *lamp = [SCNLight light];
        lamp.type = SCNLightTypeOmni;
        lamp.color = [SKColor colorWithRed:0.65 green:0.82 blue:1.0 alpha:1.0];
        lamp.intensity = 260;
        lamp.attenuationStartDistance = 4;
        lamp.attenuationEndDistance = 20;
        lampNode.light = lamp;
        lampNode.position = lampPositions[i];
        [groupNode addChildNode:lampNode];
    }

    [root addChildNode:groupNode];
}

#pragma mark - Axis anchors / legend

+ (void)buildAnchors:(SCNNode *)root
{
    SCNNode *groupNode = [SCNNode node];
    groupNode.name = kGroupAnchor;

    // Small axis triad on the cavern floor, clear of the tank.
    SCNVector3 origin = SCNVector3Make(26.0, 0.2, 26.0);
    struct { SCNVector3 dir; SKColor *col; } axes[3] = {
        { SCNVector3Make( 1, 0, 0), [SKColor redColor]   },
        { SCNVector3Make( 0, 1, 0), [SKColor greenColor]},
        { SCNVector3Make( 0, 0, 1), [SKColor blueColor] },
    };
    for (NSUInteger i = 0; i < 3; ++i) {
        SCNVector3 dir = axes[i].dir;
        SCNVector3 from = origin;
        SCNVector3 to   = SCNVector3Make(origin.x + dir.x * 5.0,
                                         origin.y + dir.y * 5.0,
                                         origin.z + dir.z * 5.0);

        SCNGeometrySource *v = [SCNGeometrySource geometrySourceWithVertices:(SCNVector3[]){from, to}
                                                                     count:2];
        const int32_t idx[2] = {0, 1};
        SCNGeometryElement *e = [SCNGeometryElement geometryElementWithData:[NSData dataWithBytes:idx length:sizeof(idx)]
                                                          primitiveType:SCNGeometryPrimitiveTypeLine
                                                         primitiveCount:1
                                                          bytesPerIndex:sizeof(int32_t)];
        SCNGeometry *g = [SCNGeometry geometryWithSources:@[v] elements:@[e]];
        SCNMaterial *m = [SCNMaterial new];
        m.diffuse.contents = axes[i].col;
        m.emission.contents = axes[i].col;
        g.materials = @[m];
        [groupNode addChildNode:[SCNNode nodeWithGeometry:g]];
    }
    [root addChildNode:groupNode];
}

#pragma mark - Public setters

+ (void)setWaterFill:(CGFloat)f rootNode:(SCNNode *)root
{
    SCNNode *waterGroup = group(kGroupWater, root);
    SCNNode *waterBody = [waterGroup childNodeWithName:@"waterBody" recursively:NO];
    if (!waterBody) return;
    f = MIN(MAX(f, 0.0), 1.0);

    CGFloat innerH = SKOTankHeight - 1.0;
    CGFloat h = f * innerH;
    SCNCylinder *geo = (SCNCylinder *)waterBody.geometry;
    geo.height = MAX(h, 0.001);
    waterBody.position = SCNVector3Make(0, 0.5 + h / 2.0, 0);
    waterBody.opacity  = f > 0.001 ? 1.0 : 0.0;

    SCNNode *surface = [waterGroup childNodeWithName:@"waterSurface" recursively:NO];
    if (surface) {
        surface.position = SCNVector3Make(0, 0.5 + h + 0.03, 0);
        surface.opacity = f > 0.005 ? 1.0 : 0.0;
    }
}

+ (void)setWaterTransparency:(CGFloat)alpha rootNode:(SCNNode *)root
{
    SCNNode *waterBody = [group(kGroupWater, root) childNodeWithName:@"waterBody" recursively:NO];
    if (!waterBody) return;
    SCNCylinder *geo = (SCNCylinder *)waterBody.geometry;
    SCNMaterial *m = geo.materials.firstObject;
    m.transparency = MIN(MAX(alpha, 0.05), 1.0);
}

+ (void)setFiducialRadius:(CGFloat)meters rootNode:(SCNNode *)root
{
    SCNNode *fidNode = [group(kGroupFiducial, root) childNodeWithName:@"fiducialBody" recursively:NO];
    if (!fidNode) return;
    meters = MIN(MAX(meters, 2.0), SKOTankRadius - 2.0);
    SCNCylinder *geo = (SCNCylinder *)fidNode.geometry;
    geo.radius = meters;
}

+ (void)setPMTRadiusScale:(CGFloat)scale rootNode:(SCNNode *)root
{
    void (^apply)(SCNNode *) = ^(SCNNode *grp) {
        for (SCNNode *child in grp.childNodes) {
            child.scale = SCNVector3Make(scale, scale, scale);
        }
    };
    apply(group(kGroupWallPMT, root));
    apply(group(kGroupBottomPMT, root));
    apply(group(kGroupTopPMT, root));
    apply(group(kGroupOuterPMT, root));
}

+ (void)setExplodeAmount:(CGFloat)amount rootNode:(SCNNode *)root
{
    NSArray<NSString *> *order = @[kGroupOuterPMT, kGroupWallPMT, kGroupBottomPMT,
                                   kGroupTopPMT, kGroupFiducial, kGroupWater,
                                   kGroupShell];
    CGFloat step = amount * 4.5;
    for (NSUInteger i = 0; i < order.count; ++i) {
        SCNNode *grp = group(order[i], root);
        if (!grp) continue;
        // Move every group, including the outer detector at index 0, apart
        // in Y and slightly radially. The (i + 1) factor keeps the first
        // group from staying pinned at the origin.
        CGFloat factor = (CGFloat)(i + 1) / (CGFloat)order.count;
        CGFloat dir = (i % 2 == 0) ? 1.0 : -1.0;
        grp.position = SCNVector3Make(dir * step * factor,
                                      dir * step * ((i % 3) * 0.4),
                                      0);
    }
}

+ (void)setShellOpacity:(CGFloat)opacity rootNode:(SCNNode *)root
{
    SCNNode *shell = group(kGroupShell, root);
    if (!shell) return;
    for (SCNNode *child in shell.childNodes) {
        child.opacity = MIN(MAX(opacity, 0.05), 1.0);
    }
}

#pragma mark - Event visuals

+ (SCNNode *)makeCherenkovRingWithEnergy:(CGFloat)energyGeV
                             atPosition:(SCNVector3)position
                               direction:(SCNVector3)direction
                                   color:(SKColor *)color
{
    // The ring size grows with energy but stays inside the tank.
    CGFloat ringRadius = MIN(1.8 + energyGeV * 0.55, 10.0);

    SCNTorus *ring = [SCNTorus torusWithRingRadius:ringRadius pipeRadius:0.17];
    ring.ringSegmentCount = 64;
    ring.pipeSegmentCount = 8;

    SCNMaterial *m = [SCNMaterial new];
    m.diffuse.contents   = color;
    m.emission.contents  = color;
    m.emission.intensity = MIN(2.4 + energyGeV / 6.0, 5.0);
    m.lightingModelName  = SCNLightingModelConstant;
    m.blendMode          = SCNBlendModeAdd;
    m.writesToDepthBuffer = NO;
    m.readsFromDepthBuffer = NO;   // keep the event visible through the PMT wall
    ring.materials = @[m];

    SCNNode *ringNode = [SCNNode nodeWithGeometry:ring];
    ringNode.position = position;
    ringNode.rotation = SKORotationFromYToVector(direction);
    ringNode.castsShadow = NO;

    // Expand + fade animation.
    SCNAction *grow  = [SCNAction scaleBy:2.0 duration:2.4];
    SCNAction *fade  = [SCNAction fadeOutWithDuration:2.4];
    SCNAction *spin  = [SCNAction rotateByAngle:0.6
                                     aroundAxis:SCNVector3Make(0, 1, 0)
                                       duration:2.4];
    [ringNode runAction:[SCNAction group:@[grow, fade, spin]]];

    return ringNode;
}

+ (SCNNode *)makeMuonTrackWithEnergy:(CGFloat)energyGeV
                          atPosition:(SCNVector3)position
                            direction:(SCNVector3)direction
                                color:(SKColor *)color
{
    CGFloat length = SKOTankHeight * 1.25;   // punch through both tank walls
    SCNCylinder *track = [SCNCylinder cylinderWithRadius:0.16 height:length];
    track.radialSegmentCount = 8;

    SCNMaterial *m = [SCNMaterial new];
    m.diffuse.contents   = color;
    m.emission.contents  = color;
    m.emission.intensity = MIN(2.4 + energyGeV / 10.0, 5.0);
    m.lightingModelName  = SCNLightingModelConstant;
    m.blendMode          = SCNBlendModeAdd;
    m.writesToDepthBuffer = NO;
    m.readsFromDepthBuffer = NO;
    track.materials = @[m];

    SCNNode *trackNode = [SCNNode nodeWithGeometry:track];
    trackNode.position = position;
    trackNode.rotation = SKORotationFromYToVector(direction);
    trackNode.castsShadow = NO;

    SCNAction *fade = [SCNAction sequence:@[
        [SCNAction waitForDuration:0.8],
        [SCNAction fadeOutWithDuration:1.0]
    ]];
    [trackNode runAction:fade];

    return trackNode;
}

+ (void)flashPMTsInRoot:(SCNNode *)root
              direction:(SCNVector3)direction
            sensitivity:(CGFloat)sensitivity
                  color:(SKColor *)color
{
    SCNNode *wall = group(kGroupWallPMT, root);
    if (!wall || wall.childNodes.count == 0) return;

    SCNSphere *flashGeom = [SCNSphere sphereWithRadius:kPMTRadius * 1.55];
    flashGeom.segmentCount = 8;
    SCNMaterial *flashMat = [SCNMaterial new];
    flashMat.diffuse.contents      = color;
    flashMat.emission.contents     = color;
    flashMat.emission.intensity    = 2.4 + sensitivity * 1.6;
    flashMat.lightingModelName     = SCNLightingModelConstant;
    flashMat.blendMode             = SCNBlendModeAdd;
    flashMat.writesToDepthBuffer   = NO;
    flashMat.readsFromDepthBuffer  = NO;
    flashGeom.materials = @[flashMat];

    CGFloat len = sqrt(direction.x * direction.x +
                       direction.y * direction.y +
                       direction.z * direction.z);
    if (len < 0.0001) return;
    SCNVector3 dir = SCNVector3Make(direction.x / len,
                                    direction.y / len,
                                    direction.z / len);

    // Cherenkov cone half-angle in water is ~41.2°, so hit PMTs sit near
    // cos(θ) ≈ 0.75 away from the event direction. Sample the wall nodes
    // rather than walking all of them at high event rates.
    CGFloat target = 0.75;
    NSUInteger stride = MAX((NSUInteger)1, wall.childNodes.count / 140);
    NSUInteger index = 0;

    for (SCNNode *pmt in wall.childNodes) {
        if (![pmt.name isEqualToString:@"pmt"]) continue;   // skip live flashes
        if ((index++ % stride) != 0) continue;

        SCNVector3 rel = SCNVector3Make(pmt.position.x,
                                        pmt.position.y - SKOTankHeight / 2.0,
                                        pmt.position.z);
        CGFloat relLen = sqrt(rel.x * rel.x + rel.y * rel.y + rel.z * rel.z);
        if (relLen < 0.0001) continue;
        CGFloat dot = (rel.x * dir.x + rel.y * dir.y + rel.z * dir.z) / relLen;
        if (fabs(dot - target) > 0.14) continue;

        SCNNode *flash = [SCNNode nodeWithGeometry:flashGeom];
        flash.name = @"pmtFlash";
        flash.position = pmt.position;
        flash.scale = SCNVector3Make(0.35, 0.35, 0.35);
        flash.castsShadow = NO;
        [wall addChildNode:flash];

        SCNAction *pop = [SCNAction group:@[
            [SCNAction scaleTo:2.5 duration:0.55],
            [SCNAction fadeOutWithDuration:0.7]
        ]];
        [flash runAction:[SCNAction sequence:@[pop,
                                               [SCNAction removeFromParentNode]]]];

        // Safety net: SceneKit action time only advances while a renderer is
        // drawing the scene, so also retire the flash on the run loop.
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.9 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            [flash removeFromParentNode];
        });
    }
}

@end
