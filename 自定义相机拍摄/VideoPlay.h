//
//  VideoPlay.h
//  SmallVideo
//
//  Created by Mr. Chen on 2017/5/11.
//  Copyright © 2017年 liezhong. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface VideoPlay : UIView
- (instancetype)initWithFrame:(CGRect)frame withShowInView:(UIView *)bgView url:(NSURL *)url;

@property (copy, nonatomic) NSURL *videoUrl;

- (void)stopPlayer;
@end
