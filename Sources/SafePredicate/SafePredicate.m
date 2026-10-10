//
//  SafePredicate.m
//  UnifiedLog
//
//  Created by David Sherlock on 2026.
//

#import "SafePredicate.h"

@implementation SafePredicate

+ (nullable NSPredicate *)make:(NSString *)format {
    @try {
        return [NSPredicate predicateWithFormat:format];
    } @catch (NSException *exception) {
        return nil;
    }
}

@end
