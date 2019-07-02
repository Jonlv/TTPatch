//
//  TTPatchUtils.m
//  TTPatch
//
//  Created by ty on 2019/5/18.
//  Copyright © 2019 TianyuBing. All rights reserved.
//

#import "TTPatchUtils.h"
#include <stdio.h>
#import <UIKit/UIKit.h>
#import "TTView.h"
#import <JavaScriptCore/JavaScriptCore.h>

#define TTPATCH_DERIVE_PRE @"TTPatch_Derive_"

#define guard(condfion) if(condfion){}
#define TTPatchInvocationException @"TTPatchInvocationException"
#define TTCheckArguments(flag,arguments)\
if (![arguments isKindOfClass:[NSNull class]] &&\
arguments != nil && \
arguments.count > 0) {  \
flag = YES;  \
}

#define CONDIF_ARGUMENT_TYPES_ENCODE(__clsTypeStr,__cls)\
else if ([clsType isEqualToString:__clsTypeStr]){\
[methodTypes appendString:[NSString stringWithUTF8String:@encode(__cls)]];}

static CGRect toOcCGReact(NSString *jsObjValue){

    if (jsObjValue) {
        return CGRectFromString(jsObjValue);
    }
    return CGRectZero;
}

static CGPoint toOcCGPoint(NSString *jsObjValue){
    if (jsObjValue){
        return CGPointFromString(jsObjValue);
    }
    return CGPointZero;
}

static CGSize toOcCGSize(NSString *jsObjValue){
    if (jsObjValue) {
        return CGSizeFromString(jsObjValue);
    }
    return CGSizeZero;
}

static void setInvocationArguments(NSInvocation *invocation,NSArray *arguments){
    for (int i = 0; i < arguments.count; i++) {
        __unsafe_unretained id argument = ([arguments objectAtIndex:i]);
        guard([argument isKindOfClass:NSDictionary.class]) else{
            [invocation setArgument:&argument atIndex:(2 + i)];
            continue;
        }
        NSString * clsType = [argument objectForKey:@"__className"];
        if (clsType) {
            NSString *str = [argument objectForKey:@"__isa"];
            if ([clsType isEqualToString:@"react"]){
                CGRect ocBaseData = toOcCGReact(str);

                [invocation setArgument:&ocBaseData atIndex:(2 + i)];
            }else if ([clsType isEqualToString:@"point"]){
                CGPoint ocBaseData = toOcCGPoint(str);
                [invocation setArgument:&ocBaseData atIndex:(2 + i)];
            }
            else if ([clsType isEqualToString:@"size"]){
                CGSize ocBaseData = toOcCGSize(str);
                [invocation setArgument:&ocBaseData atIndex:(2 + i)];
            }
        }
        else{
            [invocation setArgument:&argument atIndex:(2 + i)];
        }
        
    }
}

#define TT_ARG_Injection(charAbbreviation,type,func)\
case charAbbreviation:\
{\
NSNumber *jsObj = arguments[i];  \
type argument=[jsObj func]; \
[invocation setArgument:&argument atIndex:(2 + i)]; \
}   \
break;
static void setInvocationArgumentsMethod(NSInvocation *invocation,NSArray *arguments,Method method){
    //@:@ count=3 参数个数1
    int indexOffset = 2;
    int systemMethodArgCount = method_getNumberOfArguments(method);
    if (systemMethodArgCount>indexOffset) {
        systemMethodArgCount-=indexOffset;
    }else{
        
        systemMethodArgCount=0;
        return;
    }
    guard(systemMethodArgCount == arguments.count)else{
        NSCAssert(NO, [NSString stringWithFormat:@"参数个数不匹配,请检查!"]);
    }
    
    for (int i = 0; i < systemMethodArgCount; i++) {
        const char *argumentType = method_copyArgumentType(method, i+indexOffset);
        char flag = argumentType[0] == 'r' ? argumentType[1] : argumentType[0];
        switch(flag) {
            case _C_ID:
            {
                 id argument = ([arguments objectAtIndex:i]);
                [invocation setArgument:&argument atIndex:(2 + i)];
                
            }break;
            case _C_STRUCT_B:
            {
                 id argument = ([arguments objectAtIndex:i]);
             
                NSString * clsType = [argument objectForKey:@"__className"];
                guard(clsType)else{
                   NSCAssert(NO, [NSString stringWithFormat:@"***************方法签名入参为结构体,当前JS返回params未能获取当前结构体类型,请检查************"]);
                }
                NSString *str = [argument objectForKey:@"__isa"];
                if ([clsType isEqualToString:@"react"]){
                    CGRect ocBaseData = toOcCGReact(str);
                    
                    [invocation setArgument:&ocBaseData atIndex:(2 + i)];
                }else if ([clsType isEqualToString:@"point"]){
                    CGPoint ocBaseData = toOcCGPoint(str);
                    [invocation setArgument:&ocBaseData atIndex:(2 + i)];
                }
                else if ([clsType isEqualToString:@"size"]){
                    CGSize ocBaseData = toOcCGSize(str);
                    [invocation setArgument:&ocBaseData atIndex:(2 + i)];
                }
                
            }break;
            case 'c':{
                JSValue *jsObj = arguments[i];
                char argument[1000];
                strcpy(argument,(char *)[[jsObj toString] UTF8String]);
                [invocation setArgument:&argument atIndex:(2 + i)];
            }break;
            case _C_SEL:{
                 SEL argument = NSSelectorFromString([arguments objectAtIndex:i]);
                [invocation setArgument:&argument atIndex:(2 + i)];
            }break;
                TT_ARG_Injection(_C_SHT, short, shortValue);
                TT_ARG_Injection(_C_USHT, unsigned short, unsignedShortValue);
                TT_ARG_Injection(_C_INT, int, intValue);
                TT_ARG_Injection(_C_UINT, unsigned int, unsignedIntValue);
                TT_ARG_Injection(_C_LNG, long, longValue);
                TT_ARG_Injection(_C_ULNG, unsigned long, unsignedLongValue);
                TT_ARG_Injection(_C_LNG_LNG, long long, longLongValue);
                TT_ARG_Injection(_C_ULNG_LNG, unsigned long long, unsignedLongLongValue);
                TT_ARG_Injection(_C_FLT, float, floatValue);
                TT_ARG_Injection(_C_DBL, double, doubleValue);
                TT_ARG_Injection(_C_BOOL, BOOL, boolValue);
                
                
            default:
                break;
        }
    
    }
}

static char * GetMethodTypes(NSString *method,NSArray *arguments){
    BOOL hasReturnValue = NO;
    NSMutableString *methodTypes = [NSMutableString string];
    if ([method hasPrefix:@"$"]) {
        hasReturnValue = YES;
        method = [method stringByReplacingOccurrencesOfString:@"$" withString:@""];
        [methodTypes appendString:@"@"];
    }
    [methodTypes appendString:@"@:"];
    //如果有参数
    if ([method rangeOfString:@"_"].length > 0) {
        method = [method stringByReplacingOccurrencesOfString:@"_" withString:@":"];
    }
    for (int i = 0; i < arguments.count; i++) {
        __unsafe_unretained id argument = ([arguments objectAtIndex:i]);
        if ([argument isKindOfClass:NSDictionary.class]) {
            NSString * clsType = [argument objectForKey:@"__className"];
            guard(clsType==nil || [clsType isKindOfClass:[NSNull class]])
            CONDIF_ARGUMENT_TYPES_ENCODE(@"int", int)
            CONDIF_ARGUMENT_TYPES_ENCODE(@"long", long)
            CONDIF_ARGUMENT_TYPES_ENCODE(@"float", float)
            CONDIF_ARGUMENT_TYPES_ENCODE(@"char", char)
            CONDIF_ARGUMENT_TYPES_ENCODE(@"bool", BOOL)
            CONDIF_ARGUMENT_TYPES_ENCODE(@"void", void)
            CONDIF_ARGUMENT_TYPES_ENCODE(@"obj", NSString *)
            CONDIF_ARGUMENT_TYPES_ENCODE(@"class", typeof([NSObject class]))
            
        }
    }
 
    return "a";
}

static NSString * MethodFormatterToOcFunc(NSString *method){
    if ([method rangeOfString:@"_"].length > 0) {
        method = [method stringByReplacingOccurrencesOfString:@"_" withString:@":"];
    }
    return method;
}

static NSString * MethodFormatterToJSFunc(NSString *method){
    if ([method rangeOfString:@":"].length > 0) {
        method = [method stringByReplacingOccurrencesOfString:@":" withString:@"_"];
    }
    return method;
}

static Method GetInstanceOrClassMethodInfo(Class aClass,SEL aSel){
    Method instanceMethodInfo = class_getInstanceMethod(aClass, aSel);
    Method classMethodInfo    = class_getClassMethod(aClass, aSel);
    return instanceMethodInfo?instanceMethodInfo:classMethodInfo;
}

static NSDictionary* CGPointToJSObject(CGPoint point){
    return @{@"x":@(point.x),
             @"y":@(point.y)
             };
}

static NSDictionary* CGSizeToJSObject(CGSize size){
    return @{@"width":@(size.width),
             @"height":@(size.height)
             };
}

static NSDictionary* CGReactToJSObject(CGRect react){
    NSMutableDictionary *reactDic = [NSMutableDictionary dictionaryWithDictionary:CGPointToJSObject(react.origin)];
    [reactDic setDictionary:CGSizeToJSObject(react.size)];
    return reactDic;
}


static NSString* UIEdgeInsetsToJSObject(UIEdgeInsets edge){
    return @{@"top":@(edge.top),
             @"left":@(edge.left),
             @"bottom":@(edge.bottom),
             @"right":@(edge.right)
             };
}
@interface TTJSObject : NSObject
+ (NSDictionary *)createJSObject:(id)__isa
                       className:(NSString *)__className
                      isInstance:(BOOL)__isInstance;
@end
@implementation TTJSObject

+ (NSDictionary *)createJSObject:(id)__isa
                       className:(NSString *)__className
                      isInstance:(BOOL)__isInstance{
    return @{@"__isa":__isa?:[NSNull null],
             @"__className":__className,
             @"__isInstance":@(__isInstance)
             };
}

@end

static id ToJsObject(id returnValue,NSString *clsName){
    if (returnValue) {
        return [TTJSObject createJSObject:returnValue className:clsName isInstance:YES];;
    }
    return [TTJSObject createJSObject:nil className:clsName isInstance:NO];;
}

static NSString * ttpatch_get_derive_class_originalName(NSString *curName){
    if ([curName hasPrefix:TTPATCH_DERIVE_PRE]) {
        return [curName stringByReplacingOccurrencesOfString:TTPATCH_DERIVE_PRE withString:@""];
    }
    return curName;
}

static NSString * ttpatch_create_derive_class_name(NSString *curName){
    if ([curName hasPrefix:TTPATCH_DERIVE_PRE]) {
        return curName;
    }
    return [NSString stringWithFormat:@"%@%@",TTPATCH_DERIVE_PRE,curName];
}

static void ttpatch_exchange_method(Class self_class, Class super_class, SEL selector, BOOL isInstance) {
    NSCParameterAssert(selector);
    //获取父类方法实现
    Method targetMethodSuper = isInstance
    ? class_getInstanceMethod(super_class, selector) : class_getClassMethod(super_class, selector);
    Method targetMethodSelf = isInstance
    ? class_getInstanceMethod(self_class, selector) : class_getClassMethod(self_class, selector);
    
    {
        IMP targetMethodIMP = method_getImplementation(targetMethodSuper);
        const char *typeEncoding = method_getTypeEncoding(targetMethodSuper)?:"v@:";
        class_replaceMethod(self_class, selector, targetMethodIMP, typeEncoding);
    }
    {
        IMP targetMethodIMP = method_getImplementation(targetMethodSelf);
        const char *typeEncoding = method_getTypeEncoding(targetMethodSelf)?:"v@:";
        class_replaceMethod(super_class, selector, targetMethodIMP, typeEncoding);
    }
}

static void ttpatch_clean_derive_history(id classOrInstance,Class self_class, Class super_class, SEL selector,BOOL isInstance){
    ttpatch_exchange_method(super_class, self_class, selector, isInstance);
    Class originalClass = NSClassFromString(ttpatch_get_derive_class_originalName(NSStringFromClass([classOrInstance class])));
    object_setClass(classOrInstance, originalClass);
    objc_disposeClassPair(self_class);
}

static Class ttpatch_create_derive_class(id classOrInstance){
    Class aClass = objc_allocateClassPair([classOrInstance class], [ttpatch_create_derive_class_name(NSStringFromClass([classOrInstance class])) UTF8String], 0);
    objc_registerClassPair(aClass);
    object_setClass(classOrInstance, aClass);
    return aClass;
}




#define TT_RETURN_WRAP(typeChar,type)\
case typeChar:{   \
type instance; \
[invocation getReturnValue:&instance];  \
return @(instance); \
}break;

static id DynamicMethodInvocation(id classOrInstance,BOOL isSuper,BOOL isInstance, NSString *method, NSArray *arguments){
    Class ttpatch_cur_class = [classOrInstance class];
//    Class ttpatch_drive_class;
//    Class ttpatch_drive_super_class;
    if (isSuper) {
        //通过创建派生类的方式实现super
//        ttpatch_drive_super_class = [classOrInstance superclass];
//        ttpatch_drive_class = ttpatch_create_derive_class(classOrInstance);
//        ttpatch_exchange_method(ttpatch_drive_class, ttpatch_drive_super_class, NSSelectorFromString(method), isInstance);
        //通过直接替换当前isa为父类isa,实现super语法
        object_setClass(classOrInstance, [classOrInstance superclass]);
    }
    BOOL hasArgument = NO;
    TTCheckArguments(hasArgument,arguments);
    if([classOrInstance isKindOfClass:NSString.class]){
        classOrInstance = NSClassFromString(classOrInstance);
    }
    SEL sel_method = NSSelectorFromString(method);
    NSMethodSignature *signature = [classOrInstance methodSignatureForSelector:sel_method];
    Method classMethod = class_getClassMethod([classOrInstance class], sel_method);
    Method instanceMethod = class_getInstanceMethod([classOrInstance class], sel_method);
    Method methodInfo = classMethod?classMethod:instanceMethod;
    guard(signature) else{
        @throw [NSException exceptionWithName:TTPatchInvocationException reason:[NSString stringWithFormat:@"没有找到 '%@' 中的 %@ 方法", classOrInstance,  method] userInfo:nil];
    }
    
    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
    if ([classOrInstance respondsToSelector:sel_method]) {
#if TTPATCH_LOG
            NSLog(@"\n -----------------Message Queue Call Native ---------------\n | %@ \n | 参数个数:%ld \n | %s \n | %@ \n -----------------------------------" ,method,signature.numberOfArguments,method_getTypeEncoding(methodInfo),arguments);
#endif
        [invocation setTarget:classOrInstance];
        [invocation setSelector:sel_method];
        if (hasArgument) {
            setInvocationArgumentsMethod(invocation, arguments, methodInfo);
        }
        
        [invocation invoke];
        guard(strcmp(signature.methodReturnType,"v") == 0)else{
            
            const char *argumentType = signature.methodReturnType;
            char flag = argumentType[0] == 'r' ? argumentType[1] : argumentType[0];

            switch (flag) {
                case _C_ID:{
                    id returnValue;
                    void *result;
                    [invocation getReturnValue:&result];
                    if ([method isEqualToString:@"alloc"] || [method isEqualToString:@"new"]) {
                        returnValue = (__bridge_transfer id)result;
//                        NSLog(@"Alloc Retain count is %ld", CFGetRetainCount((__bridge CFTypeRef)returnValue));
                    } else {
                        returnValue = (__bridge id)result;
                    }
                    return returnValue?ToJsObject(returnValue,NSStringFromClass([returnValue class])):[NSNull null];
                }break;
                case _C_CLASS:{
                    __unsafe_unretained Class instance = nil;
                    [invocation getReturnValue:&instance];
                    return ToJsObject(nil,NSStringFromClass(instance));
                }break;
                case _C_STRUCT_B:{
                    NSString * returnStypeStr = [NSString stringWithUTF8String:signature.methodReturnType];
                    if ([returnStypeStr hasPrefix:@"{CGRect"]){
                        CGRect instance;
                        [invocation getReturnValue:&instance];
                        return ToJsObject(CGReactToJSObject(instance),@"react");
                    }
                    else if ([returnStypeStr hasPrefix:@"{CGPoint"]){
                        CGPoint instance;
                        [invocation getReturnValue:&instance];
                        return ToJsObject(CGPointToJSObject(instance),@"point");
                    }
                    else if ([returnStypeStr hasPrefix:@"{CGSize"]){
                        CGSize instance;
                        [invocation getReturnValue:&instance];
                        return ToJsObject(CGSizeToJSObject(instance),@"size");
                    }
                    else if ([returnStypeStr hasPrefix:@"{UIEdgeInsets"]){
                        UIEdgeInsets instance;
                        [invocation getReturnValue:&instance];
                        return NSStringFromUIEdgeInsets(instance);
                        return ToJsObject(UIEdgeInsetsToJSObject(instance),@"edge");
                    }
                    NSCAssert(NO, @"*******%@---当前结构体暂不支持",returnStypeStr);
                }break;
                    TT_RETURN_WRAP(_C_SHT, short);
                    TT_RETURN_WRAP(_C_USHT, unsigned short);
                    TT_RETURN_WRAP(_C_INT, int);
                    TT_RETURN_WRAP(_C_UINT, unsigned int);
                    TT_RETURN_WRAP(_C_LNG, long);
                    TT_RETURN_WRAP(_C_ULNG, unsigned long);
                    TT_RETURN_WRAP(_C_LNG_LNG, long long);
                    TT_RETURN_WRAP(_C_ULNG_LNG, unsigned long long);
                    TT_RETURN_WRAP(_C_FLT, float);
                    TT_RETURN_WRAP(_C_DBL, double);
                    TT_RETURN_WRAP(_C_BOOL, BOOL);
                default:
                    break;
            }
            
           
//            return ToJsObject(instance,signature.methodReturnType);
        }
    }else{
        
    }

    if (isSuper) {
//        ttpatch_clean_derive_history(classOrInstance,ttpatch_drive_class, ttpatch_drive_super_class, NSSelectorFromString(method),isInstance);
        object_setClass(classOrInstance, ttpatch_cur_class);
    }
    return nil;
    
}

//static BOOL aspect_isMsgForwardIMP(IMP impl) {
//    return impl == _objc_msgForward
//#if !defined(__arm64__)
//    || impl == (IMP)_objc_msgForward_stret
//#endif
//    ;
//}






const struct TTPatchUtils TTPatchUtils = {
    .TTPatchDynamicMethodInvocation               = DynamicMethodInvocation,
    .TTPatchGetMethodTypes                        = GetMethodTypes,
    .TTPatchMethodFormatterToOcFunc               = MethodFormatterToOcFunc,
    .TTPatchMethodFormatterToJSFunc               = MethodFormatterToJSFunc,
    .TTPatchGetInstanceOrClassMethodInfo          = GetInstanceOrClassMethodInfo,
//    .TTPatchToJsObject                            = ToJsObject
};


