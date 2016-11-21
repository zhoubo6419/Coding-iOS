//
//  Register.h
//  Coding_iOS
//
//  Created by 王 原闯 on 14-8-1.
//  Copyright (c) 2014年 Coding. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface Register : NSObject
//请求
@property (readwrite, nonatomic, strong) NSString *email, *j_captcha, *phone, *code, *password, *confirm_password;

/** 个信后缀*/
@property (readwrite, nonatomic, strong) NSString *global_key;
+ (NSString *)channel;

- (NSDictionary *)toParams;
@end
