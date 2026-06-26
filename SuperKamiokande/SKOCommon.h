#import <Foundation/Foundation.h>
#import <SceneKit/SceneKit.h>

#if TARGET_OS_OSX
#import <AppKit/AppKit.h>
typedef NSColor SKColor;
#else
#import <UIKit/UIKit.h>
typedef UIColor SKColor;
#endif

NS_ASSUME_NONNULL_BEGIN

/// Shared constants/scale definitions for the Super-K model.
/// Real detector: cylinder D = 39.3 m (Ø 41.4 m actually), height 41.4 m,
/// 50,000 t water, 11,129 20" PMTs on ID walls, ~1,885 8" PMTs OD.
/// We scale 1 m → 1 SceneKit unit and shift so the tank bottom sits at y = 0.
extern const CGFloat SKOTankRadius;        // 19.65 m
extern const CGFloat SKOTankHeight;        // 41.4 m
extern const NSUInteger SKOIDPMTCount;     // 11129

/// Colors reused across the scene.
extern SKColor *SKOSteelColor(void);
extern SKColor *SKOWaterColor(void);
extern SKColor *SKOFiducialColor(void);

NS_ASSUME_NONNULL_END
