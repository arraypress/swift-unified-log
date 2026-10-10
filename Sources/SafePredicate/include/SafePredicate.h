//
//  SafePredicate.h
//  UnifiedLog
//
//  Created by David Sherlock on 2026.
//
//  NSPredicate(format:) raises an Objective-C exception on a malformed
//  string, and Swift cannot catch one: a typo in a --predicate would crash
//  the process rather than be reported. This is the only Objective-C in the
//  package, and its only job is the @try.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SafePredicate : NSObject

/// The predicate for a format string, or nil when the string does not parse.
+ (nullable NSPredicate *)make:(NSString *)format;

@end

NS_ASSUME_NONNULL_END
