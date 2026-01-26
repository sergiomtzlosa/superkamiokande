// render_scene.m — offscreen preview of the procedural Super-K scene.
// Usage: render_scene <output.png> [shellOpacity]
// Handy for checking geometry without launching the app.
#import <Cocoa/Cocoa.h>
#import <SceneKit/SceneKit.h>
#import <Metal/Metal.h>
#import "SKOTankBuilder.h"
#import "SKOCommon.h"

int main(int argc, const char *argv[])
{
    @autoreleasepool {
        if (argc < 2) {
            fprintf(stderr, "usage: %s <output.png> [shellOpacity]\n", argv[0]);
            return 2;
        }

        SCNScene *scene = [SCNScene scene];
        scene.background.contents = [NSColor colorWithCalibratedWhite:0.07 alpha:1.0];
        NSImage *environment = [[NSImage alloc] initWithContentsOfFile:
            @"SuperKamiokande/Textures/CavernEnvironment.jpg"];
        if (environment) {
            scene.lightingEnvironment.contents = environment;
            scene.lightingEnvironment.intensity = 0.55;
        }
        scene.fogStartDistance = 105;
        scene.fogEndDistance = 230;
        scene.fogColor = [NSColor colorWithCalibratedWhite:0.02 alpha:1.0];

        SCNNode *root = [SCNNode node];
        [SKOTankBuilder buildIntoRoot:root];
        [scene.rootNode addChildNode:root];

        CGFloat shell = argc > 2 ? atof(argv[2]) : 0.35;
        [SKOTankBuilder setShellOpacity:shell rootNode:root];

        NSString *event = NSProcessInfo.processInfo.environment[@"SKO_EVENT"];
        if (event.length > 0) {
            SCNVector3 vertex = SCNVector3Make(4.0, 20.0, 2.0);
            SCNVector3 dir = SCNVector3Make(0.55, 0.38, 0.74);
            SKColor *tint = [NSColor colorWithRed:0.25 green:0.85 blue:1.0 alpha:1.0];
            if ([event isEqualToString:@"muon"]) {
                tint = [NSColor colorWithRed:1.0 green:0.32 blue:0.72 alpha:1.0];
                [root addChildNode:[SKOTankBuilder makeMuonTrackWithEnergy:18
                                                               atPosition:vertex
                                                                 direction:dir
                                                                     color:tint]];
            } else if ([event isEqualToString:@"gamma"]) {
                tint = [NSColor colorWithRed:1.0 green:0.82 blue:0.30 alpha:1.0];
            }
            [root addChildNode:[SKOTankBuilder makeCherenkovRingWithEnergy:9
                                                               atPosition:vertex
                                                                 direction:dir
                                                                     color:tint]];
            [SKOTankBuilder flashPMTsInRoot:root direction:dir sensitivity:1.4 color:tint];
        }

        // Debug toggles: SKO_HIDE=wallPMT,water,shell,fiducial,cave,tunnel
        NSString *hide = NSProcessInfo.processInfo.environment[@"SKO_HIDE"];
        for (NSString *name in [hide componentsSeparatedByString:@","]) {
            if (name.length == 0) continue;
            [[root childNodeWithName:name recursively:YES] setHidden:YES];
        }

        if (NSProcessInfo.processInfo.environment[@"SKO_DEBUG"]) {
            for (SCNNode *child in root.childNodes) {
                SCNVector3 p = child.position;
                fprintf(stderr, "group %-10s pos=(%.1f %.1f %.1f) children=%lu\n",
                        child.name.UTF8String, p.x, p.y, p.z,
                        (unsigned long)child.childNodes.count);
            }
        }

        SCNNode *target = [SCNNode node];
        target.position = SCNVector3Make(0, SKOTankHeight / 2.0, 0);
        [scene.rootNode addChildNode:target];

        SCNNode *cameraNode = [SCNNode node];
        SCNCamera *camera = [SCNCamera camera];
        camera.fieldOfView = 55;
        camera.zNear = 0.1;
        camera.zFar = 400.0;
        camera.wantsHDR = YES;
        camera.bloomIntensity = 0.7;
        cameraNode.camera = camera;
        cameraNode.position = SCNVector3Make(58, 42, 74);
        SCNLookAtConstraint *lookAt =
            [SCNLookAtConstraint lookAtConstraintWithTarget:target];
        lookAt.gimbalLockEnabled = YES;
        cameraNode.constraints = @[lookAt];
        [scene.rootNode addChildNode:cameraNode];

        SCNNode *ambient = [SCNNode node];
        ambient.light = [SCNLight light];
        ambient.light.type = SCNLightTypeAmbient;
        ambient.light.color = [NSColor colorWithCalibratedWhite:0.72 alpha:1];
        ambient.light.intensity = 620;
        [scene.rootNode addChildNode:ambient];

        SCNNode *key = [SCNNode node];
        key.light = [SCNLight light];
        key.light.type = SCNLightTypeDirectional;
        key.light.color = [NSColor colorWithCalibratedWhite:1.0 alpha:1];
        key.light.intensity = 1100;
        key.position = SCNVector3Make(45, 80, 60);
        key.eulerAngles = SCNVector3Make(-0.7, 0.35, 0);
        [scene.rootNode addChildNode:key];

        id<MTLDevice> device = MTLCreateSystemDefaultDevice();
        SCNRenderer *renderer = [SCNRenderer rendererWithDevice:device options:nil];
        renderer.scene = scene;
        renderer.pointOfView = cameraNode;
        renderer.autoenablesDefaultLighting = NO;

        NSString *timeString = NSProcessInfo.processInfo.environment[@"SKO_TIME"];
        CGFloat time = timeString.length > 0 ? atof(timeString.UTF8String) : 0.35;
        NSImage *image = [renderer snapshotAtTime:time
                                         withSize:NSMakeSize(1440, 900)
                               antialiasingMode:SCNAntialiasingModeMultisampling4X];
        NSData *tiff = image.TIFFRepresentation;
        NSBitmapImageRep *rep = [NSBitmapImageRep imageRepWithData:tiff];
        NSData *png = [rep representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
        if (![png writeToFile:[NSString stringWithUTF8String:argv[1]] atomically:YES]) {
            fprintf(stderr, "failed to write %s\n", argv[1]);
            return 1;
        }
        printf("wrote %s (shell opacity %.2f)\n", argv[1], shell);
    }
    return 0;
}
