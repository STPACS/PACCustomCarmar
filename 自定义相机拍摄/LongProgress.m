//
//  LongProgress.m
//  LongPress
//
//  Created by Mr. Chen on 2017/5/11.
//  Copyright © 2017年 liezhong. All rights reserved.
//

#import "LongProgress.h"


@implementation LongProgress


// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect {
    
    CGRect frame = CGRectMake(0, 0, self.frame.size.width, self.frame.size.width);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextAddEllipseInRect(context, frame);
    [[UIColor colorWithRed:0.85f green:0.83f blue:0.82f alpha:1.00f] set];
    CGContextFillPath(context);
    
    // Drawing code
    CGContextRef ctx = UIGraphicsGetCurrentContext();//获取上下文
    CGPoint center = CGPointMake(self.frame.size.width/2.0, self.frame.size.width/2.0);  //设置圆心位置
    CGFloat startA = - M_PI_2;  //圆起点位置
    CGFloat endA = -M_PI_2 + M_PI * 2 * _progressValue;  //圆终点位置
    
    UIBezierPath *path = [UIBezierPath bezierPathWithArcCenter:center radius:self.frame.size.width/2.0-2.5 startAngle:startA endAngle:endA clockwise:YES];
    
    CGContextSetLineWidth(ctx, 5); //设置线条宽度
    [[UIColor colorWithRed:0.16f green:0.64f blue:0.27f alpha:1.00f] setStroke]; //设置描边颜色
    
    CGContextAddPath(ctx, path.CGPath); //把路径添加到上下文
    
    CGContextStrokePath(ctx);  //渲染
    
    
    
    
}

- (void)setTimeMax:(NSInteger)timeMax {
    _timeMax = timeMax;
    self.currentTime = 0;
    self.progressValue = 0;
    [self setNeedsDisplay];
    [self performSelector:@selector(startProgress) withObject:nil afterDelay:0.1];
}

- (void)clearProgress {
    _currentTime = _timeMax;
}

- (void)startProgress {
    _currentTime += 0.1;
    if (_timeMax > _currentTime) {
        _progressValue = _currentTime/_timeMax;
        [self setNeedsDisplay];
        [self performSelector:@selector(startProgress) withObject:nil afterDelay:0.1];
    }
    
    if (_timeMax <= _currentTime) {
        [self clearProgress];
        
    }
}

@end
