#import "SKOCommon.h"

const CGFloat SKOTankRadius  = 19.65;   // m
const CGFloat SKOTankHeight  = 41.4;    // m
const NSUInteger SKOIDPMTCount = 11129; // inner-detector PMTs

SKColor *SKOSteelColor(void)
{
    return [SKColor colorWithRed:0.62 green:0.66 blue:0.72 alpha:1.0];
}

SKColor *SKOWaterColor(void)
{
    return [SKColor colorWithRed:0.20 green:0.45 blue:0.85 alpha:0.30];
}

SKColor *SKOFiducialColor(void)
{
    return [SKColor colorWithRed:0.15 green:0.95 blue:0.45 alpha:0.8];
}
