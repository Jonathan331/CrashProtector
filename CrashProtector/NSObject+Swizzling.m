//
//  NSObject+Swizzling.m
//  CrashProtector
//
//  Created by Jonathan on 2018/1/12.
//  Copyright © 2018年 Jonathan. All rights reserved.
//

#import "NSObject+Swizzling.h"
#import <objc/runtime.h>

@interface StubProxy : NSObject

@property (nonatomic, copy) NSString *crashMsg;

@property (nonatomic, weak) id target;
@property (nonatomic, weak) NSTimer *timer;
@property (nonatomic, assign) SEL selector;
@property (nonatomic, weak) id userInfo;

- (int)emptyFunction;

- (void)fireProxyTimer;

@end

@implementation StubProxy

- (int)emptyFunction
{
    NSLog(@"%@",_crashMsg);
    return 0;
}

- (void)fireProxyTimer
{
    if (self.target) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [self.target performSelector:self.selector withObject:self.userInfo];
#pragma clang diagnostic pop
    }else{
        [self.timer invalidate];
        NSLog(@"timer invalidate");
    }
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
        
        [self swizzlingClass:[NSTimer class]
            originalSelector:@selector(scheduledTimerWithTimeInterval:target:selector:userInfo:repeats:)
             replaceSelector:@selector(upw_scheduledTimerWithTimeInterval:target:selector:userInfo:repeats:)];
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

+ (void)swizzlingClass:(Class)class originalSelector:(SEL)originalSelector replaceSelector:(SEL)replaceSelector
{
    Method originalMethod = class_getClassMethod(class, originalSelector);
    Method swizzledMethod = class_getClassMethod(class, replaceSelector);
    
    class = object_getClass((id)class);
    
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

#pragma mark - NSTimer
+ (NSTimer *)upw_scheduledTimerWithTimeInterval:(NSTimeInterval)ti target:(id)aTarget selector:(SEL)aSelector userInfo:(nullable id)userInfo repeats:(BOOL)yesOrNo
{
    if (yesOrNo) {
        StubProxy *stubProxy = [StubProxy new];
        stubProxy.target = aTarget;
        NSTimer *timer = [NSTimer upw_scheduledTimerWithTimeInterval:ti target:stubProxy selector:@selector(fireProxyTimer) userInfo:userInfo repeats:yesOrNo];
        stubProxy.timer = timer;
        stubProxy.selector = aSelector;
        stubProxy.userInfo = userInfo;
        return timer;
    }else{
        return [NSTimer upw_scheduledTimerWithTimeInterval:ti target:aTarget selector:aSelector userInfo:userInfo repeats:yesOrNo];
    }
}

@end
