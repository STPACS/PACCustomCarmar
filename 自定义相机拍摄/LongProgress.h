//
//  LongProgress.h
//  LongPress
//
//  Created by Mr. Chen on 2017/5/11.
//  Copyright © 2017年 liezhong. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface LongProgress : UIView
@property (nonatomic,assign)CGFloat progressValue;
@property (nonatomic, assign) CGFloat currentTime;
@property (assign, nonatomic) NSInteger timeMax;

- (void)clearProgress;
@end
