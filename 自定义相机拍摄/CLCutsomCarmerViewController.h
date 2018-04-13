//
//  CLCutsomCarmerViewController.h
//  自定义相机拍摄
//
//  Created by Mr. Chen on 2018/4/3.
//  Copyright © 2018年 Mr. Chen. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef void(^TakeOperationSureBlock)(id item,NSInteger type);
typedef void(^RecordingFinished)(NSString *path);

@interface CLCutsomCarmerViewController : UIViewController
@property (copy, nonatomic) TakeOperationSureBlock takeBlock;

@property (assign, nonatomic) NSInteger HSeconds;
@end
