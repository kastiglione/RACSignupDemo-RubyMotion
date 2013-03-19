#import "RACSignal+ReactiveMotion.h"

@implementation RACSignal (ReactiveMotion)

+ (RACSignal *)combineLatest:(id<NSFastEnumeration>)signals reduce1:(id(^)(id))reduceBlock {
    return [self combineLatest:signals reduce:reduceBlock];
}

+ (RACSignal *)combineLatest:(id<NSFastEnumeration>)signals reduce2:(id(^)(id,id))reduceBlock {
    return [self combineLatest:signals reduce:reduceBlock];
}

+ (RACSignal *)combineLatest:(id<NSFastEnumeration>)signals reduce3:(id(^)(id,id,id))reduceBlock {
    return [self combineLatest:signals reduce:reduceBlock];
}

+ (RACSignal *)combineLatest:(id<NSFastEnumeration>)signals reduce4:(id(^)(id,id,id,id))reduceBlock {
    return [self combineLatest:signals reduce:reduceBlock];
}

+ (RACSignal *)combineLatest:(id<NSFastEnumeration>)signals reduce5:(id(^)(id,id,id,id,id))reduceBlock {
    return [self combineLatest:signals reduce:reduceBlock];
}

@end
