#import <ReactiveCocoa/RACSignal+Operations.h>

@interface RACSignal (ReactiveMotion)
+ (RACSignal *)combineLatest:(id<NSFastEnumeration>)signals reduce1:(id(^)(id))reduceBlock;
+ (RACSignal *)combineLatest:(id<NSFastEnumeration>)signals reduce2:(id(^)(id,id))reduceBlock;
+ (RACSignal *)combineLatest:(id<NSFastEnumeration>)signals reduce3:(id(^)(id,id,id))reduceBlock;
+ (RACSignal *)combineLatest:(id<NSFastEnumeration>)signals reduce4:(id(^)(id,id,id,id))reduceBlock;
+ (RACSignal *)combineLatest:(id<NSFastEnumeration>)signals reduce5:(id(^)(id,id,id,id,id))reduceBlock;
@end
