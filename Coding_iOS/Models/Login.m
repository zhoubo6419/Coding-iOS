//
//  Login.m
//  Coding_iOS
//
//  Created by 王 原闯 on 14-7-31.
//  Copyright (c) 2014年 Coding. All rights reserved.
//

#import "Login.h"
#import "XGPush.h"
#import "AppDelegate.h"

#define kLoginStatus @"login_status" // 登录状态
#define kLoginPreUserEmail @"pre_user_email"
#define kLoginUserDict @"user_dict"
#define kLoginDataListPath @"login_data_list_path.plist"

static User *curLoginUser;

@implementation Login
- (instancetype)init
{
    self = [super init];
    if (self) {
        self.remember_me = [NSNumber numberWithBool:YES];
        self.email = @"";
        self.password = @"";
    }
    return self;
}

- (NSString *)toPath{
    return @"api/v2/account/login";
}
- (NSDictionary *)toParams{
    NSMutableDictionary *params = @{@"account": self.email,
                                    @"password" : [self.password sha1Str],
                                    @"remember_me" : self.remember_me? @"true" : @"false",}.mutableCopy;
    if (self.j_captcha.length > 0) {
        params[@"j_captcha"] = self.j_captcha;
    }
    return params;
}

- (NSString *)goToLoginTipWithCaptcha:(BOOL)needCaptcha{
    if (!_email || _email.length <= 0) {
        return @"请填写「手机号码/电子邮箱/个性后缀」";
    }
    if (!_password || _password.length <= 0) {
        return @"请填写密码";
    }
    if (needCaptcha && (!_j_captcha || _j_captcha.length <= 0)) {
        return @"请填写验证码";
    }
    return nil;
}
/** 判断是否登录*/
+ (BOOL)isLogin{
    NSNumber *loginStatus = [[NSUserDefaults standardUserDefaults] objectForKey:kLoginStatus];
    if (loginStatus.boolValue && [Login curLoginUser]) { // 是否存储了
        User *loginUser = [Login curLoginUser];
        if (loginUser.status && loginUser.status.integerValue == 0) { // 判断当前用户是否存在
            return NO;
        }
        return YES;
    }else{
        return NO;
    }
}

/**
 登录是时的操作

 @param loginData 登录成功后请求下载的数据
 */
+ (void)doLogin:(NSDictionary *)loginData{
    
//    NSArray *cookies = [[NSHTTPCookieStorage sharedHTTPCookieStorage] cookies];
//    [cookies enumerateObjectsUsingBlock:^(NSHTTPCookie *  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
//        NSLog(@"cookies : %@", obj.description);
//    }];
    
    if (loginData) {
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        [defaults setObject:[NSNumber numberWithBool:YES] forKey:kLoginStatus];
        [defaults setObject:loginData forKey:kLoginUserDict];
        curLoginUser = [NSObject objectOfClass:@"User" fromJSON:loginData]; // 字典转模型
        [defaults synchronize];
        [Login setXGAccountWithCurUser];
        
        [self saveLoginData:loginData];
    }else{
        [Login doLogout];
    }
}


/** 读取登录信息*/
+ (NSMutableDictionary *)readLoginDataList{
    NSMutableDictionary *loginDataList = [NSMutableDictionary dictionaryWithContentsOfFile:[self loginDataListPath]];
    if (!loginDataList) {
        loginDataList = [NSMutableDictionary dictionary];
    }
    return loginDataList;
}

/**
 保存登录信息

 @param loginData 请求下来的登录数据
 @return 是否保存
 */
+ (BOOL)saveLoginData:(NSDictionary *)loginData{
    BOOL saved = NO;
    if (loginData) {
        NSMutableDictionary *loginDataList = [self readLoginDataList];
        User *curUser = [NSObject objectOfClass:@"User" fromJSON:loginData];
        if (curUser.global_key.length > 0) {
            [loginDataList setObject:loginData forKey:curUser.global_key];
            saved = YES;
        }
        if (curUser.email.length > 0) {
            [loginDataList setObject:loginData forKey:curUser.email];
            saved = YES;
        }
        if (curUser.phone.length > 0) {
            [loginDataList setObject:loginData forKey:curUser.phone];
            saved = YES;
        }
        if (saved) {
            saved = [loginDataList writeToFile:[self loginDataListPath] atomically:YES];
        }
    }
    return saved;
}

/** 保存登录信息的路径*/
+ (NSString *)loginDataListPath{
    NSString *documentPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    return [documentPath stringByAppendingPathComponent:kLoginDataListPath];
}

+ (User *)userWithGlobaykeyOrEmail:(NSString *)textStr{
    if (textStr.length <= 0) {
        return nil;
    }
    NSMutableDictionary *loginDataList = [self readLoginDataList];
    NSDictionary *loginData = [loginDataList objectForKey:textStr];
    return [NSObject objectOfClass:@"User" fromJSON:loginData];
}

/** 推送*/
+ (void)setXGAccountWithCurUser{
    if ([self isLogin]) {
        User *user = [Login curLoginUser];
        if (user && user.global_key.length > 0) {
            NSString *global_key = user.global_key;
            [XGPush setAccount:global_key];
            [(AppDelegate *)[UIApplication sharedApplication].delegate registerPush];
        }
    }else{
        [XGPush setAccount:nil];
        [XGPush unRegisterDevice];
    }
}
/** 退出登录*/
+ (void)doLogout{
    [UIApplication sharedApplication].applicationIconBadgeNumber = 0;
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:[NSNumber numberWithBool:NO] forKey:kLoginStatus];
    [defaults synchronize];
    //删掉 coding 的 cookie
    NSArray *cookies = [[NSHTTPCookieStorage sharedHTTPCookieStorage] cookies];
    [cookies enumerateObjectsUsingBlock:^(NSHTTPCookie *  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([obj.domain hasSuffix:@".coding.net"]) {
            [[NSHTTPCookieStorage sharedHTTPCookieStorage] deleteCookie:obj];
        }
    }];
    [Login setXGAccountWithCurUser];
}
/** 记住账号*/
+ (void)setPreUserEmail:(NSString *)emailStr{
    if (emailStr.length <= 0) {
        return;
    }
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:emailStr forKey:kLoginPreUserEmail];
    [defaults synchronize];
}
/** 获取账号*/
+ (NSString *)preUserEmail{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    return [defaults objectForKey:kLoginPreUserEmail];
}
/**
 获取当前用户的信息

 @return 返回一个用户模型
 */
+ (User *)curLoginUser{
    if (!curLoginUser) {
        //取出存储的字典数据
        NSDictionary *loginData = [[NSUserDefaults standardUserDefaults] objectForKey:kLoginUserDict];
        // 字典转模型
        curLoginUser = loginData? [NSObject objectOfClass:@"User" fromJSON:loginData]: nil;
    }
    return curLoginUser;
}

+(BOOL)isLoginUserGlobalKey:(NSString *)global_key{
    if (global_key.length <= 0) {
        return NO;
    }
    return [[self curLoginUser].global_key isEqualToString:global_key];
}
@end
