//
//  ViewController.m
//  自定义相机拍摄
//
//  Created by Mr. Chen on 2018/4/3.
//  Copyright © 2018年 Mr. Chen. All rights reserved.
//

#import "ViewController.h"
#import "CLCutsomCarmerViewController.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.frame = CGRectMake(90, 90, 90, 90);
    [button setTitle:@"相机" forState:UIControlStateNormal];
    button.backgroundColor = [UIColor orangeColor];
    [self.view addSubview:button];
    
    [button addTarget:self action:@selector(buttonAction:) forControlEvents:UIControlEventTouchUpInside];
    
    // Do any additional setup after loading the view, typically from a nib.
}

- (void)buttonAction:(UIButton *)button {
    CLCutsomCarmerViewController *clcustomVC = [[CLCutsomCarmerViewController alloc]init];
    clcustomVC.HSeconds = 600;
    clcustomVC.takeBlock = ^(id item, NSInteger type) {
        if ([item isKindOfClass:[NSURL class]]) {
            NSURL *videoURL = item;
            //视频url
            NSLog(@"视频");
//            RHChatVideo *chatVideo = [[RHChatVideo alloc] initWithFile:[videoURL path] displayName:[videoURL lastPathComponent]];
//
//            [self sendVideoMessage:chatVideo];
            
        } else {
            //图片
            NSData *imageData = UIImageJPEGRepresentation(item, 0.5);
            UIImage *image = [UIImage imageWithData:imageData];
//            [self sendImageMessage:image localPath:nil];
        }
    };
    [self presentViewController:clcustomVC animated:YES completion:nil];
    
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
