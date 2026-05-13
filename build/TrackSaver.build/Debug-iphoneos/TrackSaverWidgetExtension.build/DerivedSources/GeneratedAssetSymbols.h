#import <Foundation/Foundation.h>

#if __has_attribute(swift_private)
#define AC_SWIFT_PRIVATE __attribute__((swift_private))
#else
#define AC_SWIFT_PRIVATE
#endif

/// The "Save_Icon" asset catalog image resource.
static NSString * const ACImageNameSaveIcon AC_SWIFT_PRIVATE = @"Save_Icon";

#undef AC_SWIFT_PRIVATE
