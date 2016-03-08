#import "objc.h"

static int refTable = LUA_NOREF;

#pragma mark - Support Functions and Classes

#pragma mark - Module Functions

#pragma mark - Module Methods

static int objc_method_getName(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, METHOD_USERDATA_TAG, LS_TBREAK] ;
    Method meth = get_objectFromUserdata(Method, L, 1, METHOD_USERDATA_TAG) ;
    push_selector(L, method_getName(meth)) ;
    return 1 ;
}

static int objc_method_getTypeEncoding(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, METHOD_USERDATA_TAG, LS_TBREAK] ;
    Method meth = get_objectFromUserdata(Method, L, 1, METHOD_USERDATA_TAG) ;
    lua_pushstring(L, method_getTypeEncoding(meth)) ;
    return 1 ;
}

static int objc_method_getReturnType(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, METHOD_USERDATA_TAG, LS_TBREAK] ;
    Method meth = get_objectFromUserdata(Method, L, 1, METHOD_USERDATA_TAG) ;
    const char      *result = method_copyReturnType(meth) ;

    lua_pushstring(L, result) ;
    free((void *)result) ;
    return 1 ;
}

static int objc_method_getArgumentType(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, METHOD_USERDATA_TAG, LS_TNUMBER, LS_TBREAK] ;
    Method meth = get_objectFromUserdata(Method, L, 1, METHOD_USERDATA_TAG) ;
    const char      *result = method_copyArgumentType(meth, (UInt)luaL_checkinteger(L, 2)) ;

    lua_pushstring(L, result) ;
    free((void *)result) ;
    return 1 ;
}

static int objc_method_getNumberOfArguments(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, METHOD_USERDATA_TAG, LS_TBREAK] ;
    Method meth = get_objectFromUserdata(Method, L, 1, METHOD_USERDATA_TAG) ;
    lua_pushinteger(L, method_getNumberOfArguments(meth)) ;
    return 1 ;
}

static int objc_method_getDescription(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, METHOD_USERDATA_TAG, LS_TBREAK] ;
    Method meth = get_objectFromUserdata(Method, L, 1, METHOD_USERDATA_TAG) ;

    struct objc_method_description *result = method_getDescription(meth) ;
    lua_newtable(L) ;
      lua_pushstring(L, result->types) ; lua_setfield(L, -2, "types") ;
      push_selector(L, result->name)   ; lua_setfield(L, -2, "selector") ;
    return 1 ;
}

#pragma mark - Lua<->NSObject Conversion Functions

int push_method(lua_State *L, Method meth) {
#if defined(DEBUG_GC)
    [[LuaSkin shared] logDebug:[NSString stringWithFormat:@"method: create %@ (%p)",
                                                          NSStringFromSelector(method_getName(meth)),
                                                          meth]] ;
#endif
    if (meth) {
        void** thePtr = lua_newuserdata(L, sizeof(Method)) ;
        *thePtr = (void *)meth ;
        luaL_getmetatable(L, METHOD_USERDATA_TAG) ;
        lua_setmetatable(L, -2) ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

#pragma mark - Hammerspoon/Lua Infrastructure

static int method_userdata_tostring(lua_State* L) {
    Method meth = get_objectFromUserdata(Method, L, 1, METHOD_USERDATA_TAG) ;
    lua_pushfstring(L, "%s: %s (%p)", METHOD_USERDATA_TAG, method_getName(meth), meth) ;
    return 1 ;
}

static int method_userdata_eq(lua_State* L) {
    Method meth1 = get_objectFromUserdata(Method, L, 1, METHOD_USERDATA_TAG) ;
    Method meth2 = get_objectFromUserdata(Method, L, 2, METHOD_USERDATA_TAG) ;
    lua_pushboolean(L, (meth1 == meth2)) ;
    return 1 ;
}

static int method_userdata_gc(lua_State* L) {
// check to make sure we're not called with the wrong type for some reason...
    Method __unused meth = get_objectFromUserdata(Method, L, 1, METHOD_USERDATA_TAG) ;
#if defined(DEBUG_GC)
    [[LuaSkin shared] logDebug:[NSString stringWithFormat:@"method: remove %@ (%p)",
                                                          NSStringFromSelector(method_getName(meth)),
                                                          meth]] ;
#endif

// Remove the Metatable so future use of the variable in Lua won't think its valid
    lua_pushnil(L) ;
    lua_setmetatable(L, 1) ;

    return 0 ;
}

// static int method_meta_gc(lua_State* __unused L) {
//     return 0 ;
// }

// Metatable for userdata objects
static const luaL_Reg method_userdata_metaLib[] = {
    {"selector",          objc_method_getName},
    {"typeEncoding",      objc_method_getTypeEncoding},
    {"returnType",        objc_method_getReturnType},
    {"argumentType",      objc_method_getArgumentType},
    {"numberOfArguments", objc_method_getNumberOfArguments},
    {"description",       objc_method_getDescription},

    {"__tostring",        method_userdata_tostring},
    {"__eq",              method_userdata_eq},
    {"__gc",              method_userdata_gc},
    {NULL,                NULL}
};

// Functions for returned object when module loads
static luaL_Reg method_moduleLib[] = {
    {NULL, NULL}
};

// Metatable for module, if needed
// static const luaL_Reg method_module_metaLib[] = {
//     {"__gc", method_meta_gc},
//     {NULL,   NULL}
// };

int luaopen_hs__asm_objc_method(lua_State* __unused L) {
    LuaSkin *skin = [LuaSkin shared] ;
    refTable = [skin registerLibraryWithObject:METHOD_USERDATA_TAG
                                     functions:method_moduleLib
                                 metaFunctions:nil // method_module_metaLib
                               objectFunctions:method_userdata_metaLib];

    return 1;
}