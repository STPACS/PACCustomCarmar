#import "FBGlowLabel.h"
#import <QuartzCore/QuartzCore.h>


@implementation FBGlowLabel

@synthesize redValue;
@synthesize greenValue;
@synthesize blueValue;
@synthesize size;


-(id) initWithFrame: (CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        //变量初始化
        redValue = 128/255.0f;
        greenValue = 128/255.0f;
        blueValue = 128/255.0f;
        size = 8;
    }
    return self;
}

//重写UILable类的drawTextInRect方法
-(void) drawTextInRect: (CGRect)rect {
    //定义阴影区域
    CGSize textShadowOffest = CGSizeMake(0, 0);
    //定义RGB颜色值
    CGFloat textColorValues[] = {redValue, greenValue, blueValue, 1.0};
    
    //获取绘制上下文
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    //保存上下文状态
    CGContextSaveGState(ctx);
    
    //为上下文设置阴影
    CGContextSetShadow(ctx, textShadowOffest, size);
    //设置颜色类型
    CGColorSpaceRef textColorSpace = CGColorSpaceCreateDeviceRGB();
    //根据颜色类型和颜色值创建CGColorRef颜色
    CGColorRef textColor = CGColorCreate(textColorSpace, textColorValues);
    //为上下文阴影设置颜色，阴影颜色，阴影大小
    CGContextSetShadowWithColor(ctx, textShadowOffest, size, textColor);
    
    [super drawTextInRect:rect];
    
    
    //释放
    CGColorRelease(textColor);
    CGColorSpaceRelease(textColorSpace);
    
    //重启上下文
    CGContextRestoreGState(ctx);
}



@end
