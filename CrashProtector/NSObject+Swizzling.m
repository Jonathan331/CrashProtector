//
//  NSObject+Swizzling.m
//  CrashProtector
//
//  Created by Jonathan on 2018/1/12.
//  Copyright © 2018年 Jonathan. All rights reserved.
//

#import "NSObject+Swizzling.h"
#import <objc/runtime.h>

@implementation StubProxy

- (int)emptyFunction
{
    NSLog(@"%@",_crashMsg);
    return 0;
}

@end

@implementation NSObject(Swizzling)

+ (void)load
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        
        [self swizzlingInstance:[self class]
               originalSelector:@selector(forwardingTargetForSelector:)
                replaceSelector:@selector(upw_forwardingTargetForSelector:)];
        
        [self swizzlingInstance:[NSNotificationCenter class]
               originalSelector:@selector(addObserver:selector:name:object:)
                replaceSelector:@selector(upw_addObserver:selector:name:object:)];
        
        [self swizzlingInstance:[self class]
               originalSelector:NSSelectorFromString(@"dealloc")
                replaceSelector:@selector(upw_dealloc)];
    });
}

+ (void)swizzlingInstance:(Class)class originalSelector:(SEL)originalSelector replaceSelector:(SEL)replaceSelector
{
    Method originalMethod = class_getInstanceMethod(class, originalSelector);
    Method swizzledMethod = class_getInstanceMethod(class, replaceSelector);
    
    BOOL didAddMethod = class_addMethod(class,
                                        originalSelector,
                                        method_getImplementation(swizzledMethod),
                                        method_getTypeEncoding(swizzledMethod));
    
    if (didAddMethod) {
        class_replaceMethod(class,
                            replaceSelector,
                            method_getImplementation(originalMethod),
                            method_getTypeEncoding(originalMethod));
    } else {
        method_exchangeImplementations(originalMethod, swizzledMethod);
    }
}

#pragma mark - unrecognized selector
- (id)upw_forwardingTargetForSelector:(SEL)aSelector
{
    StubProxy *stubProxy = [StubProxy new];
    stubProxy.crashMsg = [NSString stringWithFormat:@"CrashProtector: [%@ %p %@]: unrecognized selector sent to instance",NSStringFromClass([self class]),self,NSStringFromSelector(aSelector)];
    class_addMethod([StubProxy class], aSelector, [stubProxy methodForSelector:@selector(emptyFunction)], "i@:");
    return stubProxy;
}

#pragma mark - NSNotification
- (void)upw_dealloc
{
    if ([self isNSNotification]) {
        [[NSNotificationCenter defaultCenter] removeObserver:self];
    }
    [self upw_dealloc];
}

- (void)upw_addObserver:(id)observer selector:(SEL)aSelector name:(nullable NSNotificationName)aName object:(nullable id)anObject
{
    [self setIsNSNotification:YES];
    [self upw_addObserver:observer selector:aSelector name:aName object:anObject];
}

static const char *isNSNotification = "isNSNotication";
-(void)setIsNSNotification:(BOOL)yesOrNo
{
    objc_setAssociatedObject(self, isNSNotification, @(yesOrNo), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

-(BOOL)isNSNotification
{
    NSNumber *number = objc_getAssociatedObject(self, isNSNotification);;
    return  [number boolValue];
}
@end
