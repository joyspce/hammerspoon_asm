@import Cocoa ;
@import LuaSkin ;

static const char *USERDATA_TAG = "hs._asm.touchbar" ;
static int        refTable      = LUA_NOREF;

#define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))

#pragma mark - Support Functions and Classes

static BOOL is_supported() { return NSClassFromString(@"DFRElement") ? YES : NO ; }

static inline NSRect RectWithFlippedYCoordinate(NSRect theRect) {
    return NSMakeRect(theRect.origin.x,
                      [[NSScreen screens][0] frame].size.height - theRect.origin.y - theRect.size.height,
                      theRect.size.width,
                      theRect.size.height) ;
}

extern CGDisplayStreamRef SLSDFRDisplayStreamCreate(void *, dispatch_queue_t, CGDisplayStreamFrameAvailableHandler);
extern BOOL DFRSetStatus(int);
extern BOOL DFRFoundationPostEventWithMouseActivity(NSEventType type, NSPoint p);

@interface ASMTouchBarView : NSView
@end

@implementation ASMTouchBarView {
    CGDisplayStreamRef _stream;
    NSView *_displayView;
}

- (instancetype) init {
    self = [super init];
    if(self != nil) {
        _displayView = [NSView new];
        _displayView.frame = NSMakeRect(5, 5, 1085, 30);
        _displayView.wantsLayer = YES;
        [self addSubview:_displayView];

        _stream = SLSDFRDisplayStreamCreate(NULL, dispatch_get_main_queue(), ^(CGDisplayStreamFrameStatus status,
                                                                               __unused uint64_t displayTime,
                                                                               IOSurfaceRef frameSurface,
                                                                               __unused CGDisplayStreamUpdateRef updateRef) {
            if (status != kCGDisplayStreamFrameStatusFrameComplete) return;
            self->_displayView.layer.contents = (__bridge id)(frameSurface);
        });

        DFRSetStatus(2);
        CGDisplayStreamStart(_stream);

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wassign-enum"
        [self addTrackingArea:[[NSTrackingArea alloc] initWithRect:_displayView.frame
                                                           options:( NSTrackingMouseEnteredAndExited |
                                                                     NSTrackingActiveAlways |
                                                                     NSTrackingInVisibleRect )
                                                             owner:self
                                                          userInfo:nil]] ;
#pragma clang diagnostic pop
    }

    return self;
}

- (void)commonMouseEvent:(NSEvent *)event {
    NSPoint location = [_displayView convertPoint:[event locationInWindow] fromView:nil];
    DFRFoundationPostEventWithMouseActivity(event.type, location);
}

- (void)mouseDown:(NSEvent *)event {
    [self commonMouseEvent:event];
}

- (void)mouseUp:(NSEvent *)event {
    [self commonMouseEvent:event];
}

- (void)mouseDragged:(NSEvent *)event {
    [self commonMouseEvent:event];
}

@end

@interface NSWindow (Private)
- (void )_setPreventsActivation:(bool)preventsActivation;
@end

@interface ASMTouchBarWindow : NSWindow
@property CGFloat inactiveAlpha ;
@end

@implementation ASMTouchBarWindow

- (instancetype)init {
    self = [super init];
    if(self != nil) {
        self.styleMask = NSTitledWindowMask | NSFullSizeContentViewWindowMask;
        self.titlebarAppearsTransparent = YES;
        self.titleVisibility = NSWindowTitleHidden;
        [self standardWindowButton:NSWindowCloseButton].hidden = YES;
        [self standardWindowButton:NSWindowFullScreenButton].hidden = YES;
        [self standardWindowButton:NSWindowZoomButton].hidden = YES;
        [self standardWindowButton:NSWindowMiniaturizeButton].hidden = YES;

        self.movable = NO;
        self.acceptsMouseMovedEvents = YES;
        self.movableByWindowBackground = NO;
        self.level = CGWindowLevelForKey(kCGAssistiveTechHighWindowLevelKey);
        self.collectionBehavior = (NSWindowCollectionBehaviorCanJoinAllSpaces | NSWindowCollectionBehaviorStationary | NSWindowCollectionBehaviorIgnoresCycle | NSWindowCollectionBehaviorFullScreenDisallowsTiling);
        self.backgroundColor = [NSColor blackColor];
        [self _setPreventsActivation:YES];
        [self setFrame:NSMakeRect(0, 0, 1085 + 10, 30 + 10) display:YES];

        self.contentView = [ASMTouchBarView new];
        _inactiveAlpha = .5 ;
    }

    return self;
}

- (BOOL)canBecomeMainWindow {
    return NO;
}

- (BOOL)canBecomeKeyWindow {
    return NO;
}

- (void)mouseExited:(__unused NSEvent *)theEvent {
    self.alphaValue = _inactiveAlpha ;
}

- (void)mouseEntered:(__unused NSEvent *)theEvent {
    self.alphaValue = 1.0 ;
}

@end

#pragma mark - Module Functions

/// hs._asm.touchbar.supported([showLink]) -> boolean
/// Function
/// Returns a boolean value indicathing whether or not the Apple Touch Bar is supported on this Macintosh.
///
/// Parameters:
///  * `showLink` - a boolean, default false, specifying whether a dialog prompting the user to download the necessary update is presented if Apple Touch Bar support is not found in the current Operating System.
///
/// Returns:
///  * true if Apple Touch Bar support is found in the current Operating System or false if it is not.
///
/// Notes:
///  * the link in the prompt is https://support.apple.com/kb/dl1897
static int touchbar_supported(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    BOOL showDialog = (lua_gettop(L) == 1) ? (BOOL)lua_toboolean(L, 1) : NO ;
    lua_pushboolean(L, is_supported()) ;
    if (!lua_toboolean(L, -1)) {
        if (showDialog) {
            NSAlert *alert = [[NSAlert alloc] init];
            [alert setMessageText:@"Error: could not detect Touch Bar support"];
            [alert setInformativeText:[NSString stringWithFormat:@"We need at least macOS 10.12.1 (Build 16B2657).\n\nYou have: %@.\n", [NSProcessInfo processInfo].operatingSystemVersionString]];
            [alert addButtonWithTitle:@"Cancel"];
            [alert addButtonWithTitle:@"Get macOS Update"];
            NSModalResponse response = [alert runModal];
            if(response == NSAlertSecondButtonReturn) {
                NSURL *appleUpdateURL = [NSURL URLWithString:@"https://support.apple.com/kb/dl1897"] ;
                [[NSWorkspace sharedWorkspace] openURL:appleUpdateURL];
            }
        }
    }
    return 1 ;
}

/// hs._asm.touchbar.new() -> touchbarObject | nil
/// Function
/// Creates a new touchbarObject representing a window which displays the Apple Touch Bar.
///
/// Parameters:
///  * None
///
/// Returns:
///  * the touchbarObject or nil if one could not be created
///
/// Notes:
///  * The most common reason a touchbarObject cannot be created is if your macOS version is not new enough. Type the following into your Hammerspoon console to check: `require("hs._asm.touchbar").supported(true)`.
static int touchbar_new(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TBREAK] ;
    if (is_supported()) {
        [skin pushNSObject:[ASMTouchBarWindow new]] ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

#pragma mark - Module Methods

/// hs._asm.touchbar:show([duration]) -> touchbarObject
/// Method
/// Display the touch bar window with an optional fade-in delay.
///
/// Parameters:
///  * `duration` - an optional number, default 0.0, specifying the fade-in time for the touch bar window.
///
/// Returns:
///  * the touchbarObject
///
/// Notes:
///  * This method does nothing if the window is already visible.
static int touchbar_show(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    ASMTouchBarWindow *touchbar = [skin toNSObjectAtIndex:1] ;
    NSTimeInterval    duration  = (lua_gettop(L) == 2) ? lua_tonumber(L, 2) : 0.0 ;

    if (touchbar.visible == NO) {
        CGFloat initialAlpha = [touchbar.contentView hitTest:[NSEvent mouseLocation]] ? 1.0 : touchbar.inactiveAlpha ;
        touchbar.alphaValue = (duration > 0) ? 0.0 : initialAlpha ;
        [touchbar setIsVisible:YES] ;
        if (duration > 0.0) {
            [NSAnimationContext beginGrouping];
            [[NSAnimationContext currentContext] setDuration:duration];
            [[touchbar animator] setAlphaValue:1.0];
            [NSAnimationContext endGrouping];
        }
    }
    lua_pushvalue(L, 1) ;
    return 1 ;
}

/// hs._asm.touchbar:hide([duration]) -> touchbarObject
/// Method
/// Display the touch bar window with an optional fade-out delay.
///
/// Parameters:
///  * `duration` - an optional number, default 0.0, specifying the fade-out time for the touch bar window.
///
/// Returns:
///  * the touchbarObject
///
/// Notes:
///  * This method does nothing if the window is already hidden.
///  * The value used in the sample code referenced in the module header is 0.1.
static int touchbar_hide(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    ASMTouchBarWindow *touchbar = [skin toNSObjectAtIndex:1] ;
    NSTimeInterval    duration  = (lua_gettop(L) == 2) ? lua_tonumber(L, 2) : 0.0 ;

    if (touchbar.visible == YES) {
        if (duration > 0.0) {
            [NSAnimationContext runAnimationGroup:^(NSAnimationContext * _Nonnull context) {
                context.duration = duration ;
                [[touchbar animator] setAlphaValue:0.0] ;
            } completionHandler:^{
                if(touchbar.alphaValue == 0.0)
                    [touchbar setIsVisible:NO] ;
            }];
        } else {
            touchbar.alphaValue = 0.0 ;
            [touchbar setIsVisible:NO] ;
        }
    }
    lua_pushvalue(L, 1) ;
    return 1 ;
}

/// hs._asm.touchbar:topLeft([point]) -> table | touchbarObject
/// Method
/// Get or set the top-left of the touch bar window.
///
/// Parameters:
///  * `point` - an optional table specifying where the top left of the touch bar window should be moved to.
///
/// Returns:
///  * if a value is provided, returns the touchbarObject; otherwise returns the current value.
///
/// Notes:
///  * A point table is a table with at least `x` and `y` key-value pairs which specify the coordinates on the computer screen where the window should be moved to.  Hammerspoon considers the upper left corner of the primary screen to be { x = 0.0, y = 0.0 }.
static int touchbar_topLeft(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;
    ASMTouchBarWindow *touchbar = [skin toNSObjectAtIndex:1] ;

    NSRect frame = RectWithFlippedYCoordinate(touchbar.frame) ;
    if (lua_gettop(L) == 1) {
        [skin pushNSPoint:frame.origin] ;
    } else {
        NSPoint point  = [skin tableToPointAtIndex:2] ;
        frame.origin.x = point.x ;
        frame.origin.y = point.y ;
        [touchbar setFrame:RectWithFlippedYCoordinate(frame) display:YES animate:NO];
        lua_pushvalue(L, 1);
    }
    return 1;
}

/// hs._asm.touchbar:getFrame() -> table
/// Method
/// Gets the frame of the touch bar window
///
/// Parameters:
///  * None
///
/// Returns:
///  * a frame table with key-value pairs specifying the top left corner of the touch bar window and its width and height.
///
/// Notes:
///  * A frame table is a table with at least `x`, `y`, `h` and `w` key-value pairs which specify the coordinates on the computer screen of the window and its width (w) and height(h).
///  * This allows you to get the frame so that you can include its height and width in calculations - it does not allow you to change the size of the touch bar window itself.
static int touchbar_getFrame(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    ASMTouchBarWindow *touchbar = [skin toNSObjectAtIndex:1] ;

    NSRect frame = RectWithFlippedYCoordinate(touchbar.frame) ;
    if (lua_gettop(L) == 1) {
        [skin pushNSRect:frame] ;
    }
    return 1;
}

/// hs._asm.touchbar:isVisible() -> boolean
/// Method
/// Returns a boolean indicating whether or not the touch bar window is current visible.
///
/// Parameters:
///  * None
///
/// Returns:
///  * a boolean specifying whether the window is visible (true) or not (false).
static int touchbar_isVisible(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    ASMTouchBarWindow *touchbar = [skin toNSObjectAtIndex:1] ;
    lua_pushboolean(L, touchbar.visible) ;
    return 1;
}

/// hs._asm.touchbar:inactiveAlpha([alpha]) -> number | touchbarObject
/// Method
/// Get or set the alpha value for the touch bar window when the mouse is not hovering over it.
///
/// Parameters:
///  * alpha - an optional number between 0.0 and 1.0 inclusive specifying the alpha value for the touch bar window when the mouse is not over it.  Defaults to 0.5.
///
/// Returns:
///  * if a value is provided, returns the touchbarObject; otherwise returns the current value
static int touchbar_inactiveAlpha(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    ASMTouchBarWindow *touchbar = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, touchbar.inactiveAlpha) ;
    } else {
        CGFloat newAlpha = luaL_checknumber(L, 2);
        touchbar.inactiveAlpha = ((newAlpha < 0.0) ? 0.0 : ((newAlpha > 1.0) ? 1.0 : newAlpha)) ;
        touchbar.alphaValue = [touchbar.contentView hitTest:[NSEvent mouseLocation]] ? 1.0 : touchbar.inactiveAlpha ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

#pragma mark - Module Constants

#pragma mark - Lua<->NSObject Conversion Functions
// These must not throw a lua error to ensure LuaSkin can safely be used from Objective-C
// delegates and blocks.

static int pushASMTouchBarWindow(lua_State *L, id obj) {
    ASMTouchBarWindow *value = obj;
    void** valuePtr = lua_newuserdata(L, sizeof(ASMTouchBarWindow *));
    *valuePtr = (__bridge_retained void *)value;
    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);
    return 1;
}

id toASMTouchBarWindowFromLua(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin shared] ;
    ASMTouchBarWindow *value ;
    if (luaL_testudata(L, idx, USERDATA_TAG)) {
        value = get_objectFromUserdata(__bridge ASMTouchBarWindow, L, idx, USERDATA_TAG) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", USERDATA_TAG,
                                                   lua_typename(L, lua_type(L, idx))]] ;
    }
    return value ;
}

#pragma mark - Hammerspoon/Lua Infrastructure

static int userdata_tostring(lua_State* L) {
    LuaSkin *skin = [LuaSkin shared] ;
//     ASMTouchBarWindow *obj = [skin luaObjectAtIndex:1 toClass:"ASMTouchBarWindow"] ;
    NSString *title = @"TouchBar" ;
    [skin pushNSObject:[NSString stringWithFormat:@"%s: %@ (%p)", USERDATA_TAG, title, lua_topointer(L, 1)]] ;
    return 1 ;
}

static int userdata_eq(lua_State* L) {
// can't get here if at least one of us isn't a userdata type, and we only care if both types are ours,
// so use luaL_testudata before the macro causes a lua error
    if (luaL_testudata(L, 1, USERDATA_TAG) && luaL_testudata(L, 2, USERDATA_TAG)) {
        LuaSkin *skin = [LuaSkin shared] ;
        ASMTouchBarWindow *obj1 = [skin luaObjectAtIndex:1 toClass:"ASMTouchBarWindow"] ;
        ASMTouchBarWindow *obj2 = [skin luaObjectAtIndex:2 toClass:"ASMTouchBarWindow"] ;
        lua_pushboolean(L, [obj1 isEqualTo:obj2]) ;
    } else {
        lua_pushboolean(L, NO) ;
    }
    return 1 ;
}

static int userdata_gc(lua_State* L) {
    ASMTouchBarWindow *obj = get_objectFromUserdata(__bridge_transfer ASMTouchBarWindow, L, 1, USERDATA_TAG) ;
    if (obj) {
        obj.alphaValue = 0.0 ;
        [obj setIsVisible:NO] ;
        obj = nil ;
    }

    // Remove the Metatable so future use of the variable in Lua won't think its valid
    lua_pushnil(L) ;
    lua_setmetatable(L, 1) ;
    return 0 ;
}

// static int meta_gc(lua_State* __unused L) {
//     return 0 ;
// }

// Metatable for userdata objects
static const luaL_Reg userdata_metaLib[] = {
    {"show",          touchbar_show},
    {"hide",          touchbar_hide},
    {"topLeft",       touchbar_topLeft},
    {"getFrame",      touchbar_getFrame},
    {"inactiveAlpha", touchbar_inactiveAlpha},
    {"isVisible",     touchbar_isVisible},
    {"__tostring",    userdata_tostring},
    {"__eq",          userdata_eq},
    {"__gc",          userdata_gc},
    {NULL,            NULL}
};

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"supported", touchbar_supported},
    {"new",       touchbar_new},

    {NULL,        NULL}
};

// // Metatable for module, if needed
// static const luaL_Reg module_metaLib[] = {
//     {"__gc", meta_gc},
//     {NULL,   NULL}
// };

// NOTE: ** Make sure to change luaopen_..._internal **
int luaopen_hs__asm_touchbar_internal(lua_State* __unused L) {
    LuaSkin *skin = [LuaSkin shared] ;
    refTable = [skin registerLibraryWithObject:USERDATA_TAG
                                     functions:moduleLib
                                 metaFunctions:nil    // or module_metaLib
                               objectFunctions:userdata_metaLib];

    [skin registerPushNSHelper:pushASMTouchBarWindow         forClass:"ASMTouchBarWindow"];
    [skin registerLuaObjectHelper:toASMTouchBarWindowFromLua forClass:"ASMTouchBarWindow"
                                                  withUserdataMapping:USERDATA_TAG];

    return 1;
}