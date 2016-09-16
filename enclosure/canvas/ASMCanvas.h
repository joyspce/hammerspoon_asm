@import Cocoa ;
@import LuaSkin ;

#if __clang_major__ < 8
#import "xcode7.h"
#endif

@interface ASMCanvasView : NSView
@property int                 mouseCallbackRef ;
@property int                 referenceCount ;
@property BOOL                mouseTracking ;
@property BOOL                canvasMouseDown ;
@property BOOL                canvasMouseUp ;
@property BOOL                canvasMouseEnterExit ;
@property BOOL                canvasMouseMove ;
@property NSUInteger          previousTrackedIndex ;
@property NSMutableDictionary *canvasDefaults ;
@property NSMutableArray      *elementList ;
@property NSMutableArray      *elementBounds ;
@property NSAffineTransform   *canvasTransform ;
@property NSMapTable          *imageAnimations ;

- (id)getElementValueFor:(NSString *)keyName atIndex:(NSUInteger)index ;
- (id)getElementValueFor:(NSString *)keyName atIndex:(NSUInteger)index onlyIfSet:(BOOL)onlyIfSet ;
- (id)getElementValueFor:(NSString *)keyName atIndex:(NSUInteger)index resolvePercentages:(BOOL)resolvePercentages ;
- (id)getElementValueFor:(NSString *)keyName atIndex:(NSUInteger)index resolvePercentages:(BOOL)resolvePercentages onlyIfSet:(BOOL)onlyIfSet ;
@end

@interface ASMCanvasView (imageAdditions)
- (void)drawImage:(NSImage *)theImage atIndex:(NSUInteger)idx inRect:(NSRect)cellFrame operation:(NSUInteger)compositeType ;
@end

@interface ASMCanvasView (viewNotifications)
- (void)willRemoveFromCanvas ;
- (void)didRemoveFromCanvas ;
- (void)willAddToCanvas ;
- (void)didAddToCanvas ;

- (void)canvasWillHide ;
- (void)canvasDidHide ;
- (void)canvasWillShow ;
- (void)canvasDidShow ;

@end

@interface ASMGifAnimator : NSObject
@property (weak) NSBitmapImageRep *animatingRepresentation ;
@property (weak) ASMCanvasView    *inCanvas ;
@property BOOL                    isRunning ;

-(instancetype)initWithImage:(NSImage *)image forCanvas:(ASMCanvasView *)canvas ;
-(void)startAnimating ;
-(void)stopAnimating ;
@end

#define ALL_TYPES  @[ @"arc", @"circle", @"ellipticalArc", @"image", @"oval", @"points", @"rectangle", @"resetClip", @"segments", @"text", @"view" ]
#define VISIBLE    @[ @"arc", @"circle", @"ellipticalArc", @"image", @"oval", @"points", @"rectangle", @"segments", @"text", @"view" ]
#define PRIMITIVES @[ @"arc", @"circle", @"ellipticalArc", @"oval", @"points", @"rectangle", @"segments" ]
#define CLOSED     @[ @"arc", @"circle", @"ellipticalArc", @"oval", @"rectangle", @"segments" ]

#define STROKE_JOIN_STYLES @{ \
    @"miter" : @(NSMiterLineJoinStyle), \
    @"round" : @(NSBevelLineJoinStyle), \
    @"bevel" : @(NSBevelLineJoinStyle), \
}

#define STROKE_CAP_STYLES @{ \
    @"butt"   : @(NSButtLineCapStyle), \
    @"round"  : @(NSRoundLineCapStyle), \
    @"square" : @(NSSquareLineCapStyle), \
}

#define COMPOSITING_TYPES @{ \
    @"clear"           : @(NSCompositingOperationClear), \
    @"copy"            : @(NSCompositingOperationCopy), \
    @"sourceOver"      : @(NSCompositingOperationSourceOver), \
    @"sourceIn"        : @(NSCompositingOperationSourceIn), \
    @"sourceOut"       : @(NSCompositingOperationSourceOut), \
    @"sourceAtop"      : @(NSCompositingOperationSourceAtop), \
    @"destinationOver" : @(NSCompositingOperationDestinationOver), \
    @"destinationIn"   : @(NSCompositingOperationDestinationIn), \
    @"destinationOut"  : @(NSCompositingOperationDestinationOut), \
    @"destinationAtop" : @(NSCompositingOperationDestinationAtop), \
    @"XOR"             : @(NSCompositingOperationXOR), \
    @"plusDarker"      : @(NSCompositingOperationPlusDarker), \
    @"plusLighter"     : @(NSCompositingOperationPlusLighter), \
}

#define WINDING_RULES @{ \
    @"evenOdd" : @(NSEvenOddWindingRule), \
    @"nonZero" : @(NSNonZeroWindingRule), \
}

#define TEXTALIGNMENT_TYPES @{ \
    @"left"      : @(NSTextAlignmentLeft), \
    @"right"     : @(NSTextAlignmentRight), \
    @"center"    : @(NSTextAlignmentCenter), \
    @"justified" : @(NSTextAlignmentJustified), \
    @"natural"   : @(NSTextAlignmentNatural), \
}

#define TEXTWRAP_TYPES @{ \
    @"wordWrap"       : @( NSLineBreakByWordWrapping), \
    @"charWrap"       : @(NSLineBreakByCharWrapping), \
    @"clip"           : @(NSLineBreakByClipping), \
    @"truncateHead"   : @(NSLineBreakByTruncatingHead), \
    @"truncateMiddle" : @(NSLineBreakByTruncatingMiddle), \
    @"truncateTail"   : @(NSLineBreakByTruncatingTail), \
}

#define IMAGEALIGNMENT_TYPES @{ \
    @"center"      : @(NSImageAlignCenter), \
    @"bottom"      : @(NSImageAlignBottom), \
    @"bottomLeft"  : @(NSImageAlignBottomLeft), \
    @"bottomRight" : @(NSImageAlignBottomRight), \
    @"left"        : @(NSImageAlignLeft), \
    @"right"       : @(NSImageAlignRight), \
    @"top"         : @(NSImageAlignTop), \
    @"topLeft"     : @(NSImageAlignTopLeft), \
    @"topRight"    : @(NSImageAlignTopRight), \
}

#define IMAGESCALING_TYPES @{ \
    @"none"                : @(NSImageScaleNone), \
    @"scaleToFit"          : @(NSImageScaleAxesIndependently), \
    @"scaleProportionally" : @(NSImageScaleProportionallyUpOrDown), \
    @"shrinkToFit"         : @(NSImageScaleProportionallyDown), \
}