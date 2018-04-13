//
//  CLCutsomCarmerViewController.m
//  自定义相机拍摄
//
//  Created by Mr. Chen on 2018/4/3.
//  Copyright © 2018年 Mr. Chen. All rights reserved.
//

#import "CLCutsomCarmerViewController.h"
#import "LongProgress.h"
#import "VideoPlay.h"
#import <AVFoundation/AVFoundation.h>
#import <Foundation/Foundation.h>
#import <AssetsLibrary/AssetsLibrary.h>
#import "Masonry.h"
#import "FBGlowLabel.h"
#import "MBProgressHUD.h"
#import "ICFileTool.h"

//屏幕宽高
#define screenWidth  [UIScreen mainScreen].bounds.size.width
#define screenHeight  [UIScreen mainScreen].bounds.size.height


static const CGFloat hideTime = 4;
static const CGFloat buttonWidth = 70;

#define UIColorFromRGB(rgbValue) [UIColor colorWithRed:((float)(((rgbValue) & 0xFF0000) >> 16))/255.0 green:((float)(((rgbValue) & 0xFF00) >> 8))/255.0 blue:((float)((rgbValue) & 0xFF))/255.0 alpha:1.0]

typedef void(^PropertyChangeBlock)(AVCaptureDevice *captureDevice);



@interface CLCutsomCarmerViewController ()<AVCaptureFileOutputRecordingDelegate>
@property (nonatomic, strong) UIButton *transformCamera;//切换摄像头
//@property (nonatomic, strong) UIButton *editButton;//编辑按钮
@property (nonatomic, strong) UIButton *rebackButton;
@property (nonatomic, strong) UIImageView *startView;
@property (nonatomic, strong) UIImageView *tipsImageView;
@property (nonatomic, strong) UIView *bgView;
@property (nonatomic, strong) UIButton *cancelButton;//重新录制或者拍照按钮
@property (nonatomic, strong) UIButton *doneButton;
//@property (nonatomic, strong) FBGlowLabel *tipLabel;
@property (strong,nonatomic) AVCaptureMovieFileOutput *captureMovieFileOutput;
@property (strong,nonatomic) AVCaptureDeviceInput *captureDeviceInput;
@property (strong, nonatomic) VideoPlay *player;
@property (nonatomic) AVCaptureSession *session;
@property (nonatomic) AVCaptureVideoPreviewLayer *previewLayer;
@property (assign, nonatomic) NSInteger seconds;
@property (strong, nonatomic) NSURL *saveVideoUrl;
@property (assign, nonatomic) BOOL isFocus;
@property (assign, nonatomic) BOOL isVideo;
@property (strong, nonatomic) UIImage *takeImage;
@property (strong, nonatomic) UIImageView *takeImageView;
@property (strong, nonatomic) UIImageView *focusCursor; //聚焦光标
@property (strong, nonatomic) LongProgress *progressView;

@end
//时间大于这个就是视频，否则为拍照
#define TimeMax 1

@implementation CLCutsomCarmerViewController

-(void)viewDidDisappear:(BOOL)animated{
    [super viewDidDisappear:animated];
    [self.session stopRunning];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [[UIApplication sharedApplication] setStatusBarHidden:NO];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor whiteColor];
    
     [[UIApplication sharedApplication] setStatusBarHidden:YES];
    
    [self _initViews];
    [self customCamera];
    [self.session startRunning];
    
    [self performSelector:@selector(onHiddenFocusCurSorAction) withObject:nil afterDelay:0.5];
    
    if (self.HSeconds == 0) {
        self.HSeconds = 0;
    }
    // Do any additional setup after loading the view.
}

- (void)customCamera {
    
    //初始化会话，用来结合输入输出
    self.session = [[AVCaptureSession alloc] init];
    //设置分辨率 (设备支持的最高分辨率)
    if ([self.session canSetSessionPreset:AVCaptureSessionPresetHigh]) {
        self.session.sessionPreset = AVCaptureSessionPresetHigh;
    }
    //取得后置摄像头
    AVCaptureDevice *captureDevice = [self getCameraDeviceWithPosition:AVCaptureDevicePositionBack];
    //添加一个音频输入设备
    AVCaptureDevice *audioCaptureDevice=[[AVCaptureDevice devicesWithMediaType:AVMediaTypeAudio] firstObject];
    
    //输出对象
    self.captureMovieFileOutput = [[AVCaptureMovieFileOutput alloc] init];//视频输出
    
    //初始化输入设备
    NSError *error = nil;
    self.captureDeviceInput = [[AVCaptureDeviceInput alloc] initWithDevice:captureDevice error:&error];
    if (error) {
        NSLog(@"取得设备输入对象时出错，错误原因：%@",error.localizedDescription);
    }
    
    //添加音频
    error = nil;
    AVCaptureDeviceInput *audioCaptureDeviceInput=[[AVCaptureDeviceInput alloc]initWithDevice:audioCaptureDevice error:&error];
    if (error) {
        NSLog(@"取得设备输入对象时出错，错误原因：%@",error.localizedDescription);
    }
 
    //将输入设备添加到会话
    if ([self.session canAddInput:self.captureDeviceInput]) {
        [self.session addInput:self.captureDeviceInput];
        //设置视频防抖
        AVCaptureConnection *connection = [self.captureMovieFileOutput connectionWithMediaType:AVMediaTypeVideo];
        if ([connection isVideoStabilizationSupported]) {
            connection.preferredVideoStabilizationMode = AVCaptureVideoStabilizationModeCinematic;
        }
    }
    
    if ([self.session canAddInput:audioCaptureDeviceInput]) {
        [self.session addInput:audioCaptureDeviceInput];
    }
    
    //将输出设备添加到会话 (刚开始 是照片为输出对象)
    if ([self.session canAddOutput:self.captureMovieFileOutput]) {
        [self.session addOutput:self.captureMovieFileOutput];
    }
    
    //创建视频预览层，用于实时展示摄像头状态
    self.previewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:self.session];
    self.previewLayer.frame = self.view.bounds;//CGRectMake(0, 0, self.view.width, self.view.height);
    self.previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;//填充模式
    [self.bgView.layer addSublayer:self.previewLayer];
    
    [self addNotificationToCaptureDevice:captureDevice];
    [self addGenstureRecognizer];
}

- (void)_initViews {
    
    self.bgView = [[UIView alloc]init];
    [self.view addSubview:self.bgView];
    
    [self.bgView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(self.view).with.insets(UIEdgeInsetsMake(0,0,0,0));
    }];
    
    self.focusCursor = [[UIImageView alloc]init];
    self.focusCursor.image = [UIImage imageNamed:@"Group"];
    [self.view addSubview:self.focusCursor];
    
    [self.focusCursor mas_makeConstraints:^(MASConstraintMaker *make) {
        make.size.mas_equalTo(CGSizeMake(90, 90));
        make.center.equalTo(self.view);
    }];
    
    [self.transformCamera mas_makeConstraints:^(MASConstraintMaker *make) {
        make.size.mas_equalTo(CGSizeMake(50, 50));
        make.right.equalTo(self.view.mas_right).and.offset(-20);
        make.top.equalTo(self.view.mas_top).and.offset(30);
    }];
    
//    [self.editButton setImage:[UIImage imageNamed:@"EditImageCameraIconEdit"] forState:UIControlStateNormal];
//    self.editButton.hidden = YES;
//    [self.editButton addTarget:self action:@selector(editButtonAction:) forControlEvents:UIControlEventTouchUpInside];
//    [self.editButton mas_makeConstraints:^(MASConstraintMaker *make) {
//        make.size.mas_equalTo(CGSizeMake(50, 50));
//        make.right.equalTo(self.view.mas_right).and.offset(-20);
//        make.top.equalTo(self.view.mas_top).and.offset(30);
//    }];
    
    [self.rebackButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.size.mas_equalTo(CGSizeMake(50, 50));
        make.left.equalTo(self.view).and.offset(screenWidth/4 - 25);
        make.bottom.equalTo(self.view).and.offset(-80);
    }];
    
    [self.progressView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.size.mas_equalTo(CGSizeMake(0, 0));
        make.centerX.mas_equalTo(self.view.mas_centerX);
        make.centerY.equalTo(self.rebackButton.mas_centerY);
        
    }];
    
    self.progressView.backgroundColor = [UIColor clearColor];;
    
    [self.startView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.size.mas_equalTo(CGSizeMake(buttonWidth, buttonWidth));
        make.centerX.mas_equalTo(self.view.mas_centerX);
        make.centerY.equalTo(self.rebackButton.mas_centerY);
        
    }];
    self.startView.backgroundColor = [UIColor whiteColor];
    self.startView.layer.cornerRadius = buttonWidth/2;
    
//    [self.tipsImageView mas_makeConstraints:^(MASConstraintMaker *make) {
//        make.size.mas_equalTo(CGSizeMake(buttonWidth, buttonWidth));
//        make.centerX.mas_equalTo(self.startView.mas_centerX);
//        make.centerY.equalTo(self.startView.mas_centerY);
//
//    }];
//    self.tipsImageView.layer.cornerRadius = 80/2;
    
    [self.transformCamera setImage:[UIImage imageNamed:@"cameraNavBarIconSwitch"] forState:UIControlStateNormal];
    [self.rebackButton setImage:[UIImage imageNamed:@"HVideo_back"] forState:UIControlStateNormal];
    [self.transformCamera addTarget:self action:@selector(tranFormAction:) forControlEvents:UIControlEventTouchUpInside];
    [self.rebackButton addTarget:self action:@selector(dissmissButtonAction:) forControlEvents:UIControlEventTouchUpInside];
    
    [self.cancelButton setImage:[UIImage imageNamed:@"sight_preview_cancel"] forState:UIControlStateNormal];
    [self.doneButton setImage:[UIImage imageNamed:@"sight_preview_done"] forState:UIControlStateNormal];
    
    self.cancelButton.backgroundColor = [UIColor colorWithRed:0.85f green:0.83f blue:0.82f alpha:1.00f];
    self.cancelButton.layer.cornerRadius = 35;
    self.cancelButton.layer.masksToBounds = YES;
    [self.cancelButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.size.mas_equalTo(CGSizeMake(buttonWidth, buttonWidth));
        make.centerX.mas_equalTo(self.view.mas_centerX);
        make.centerY.equalTo(self.rebackButton.mas_centerY);
    }];
    
    self.doneButton.backgroundColor = [UIColor whiteColor];
    self.doneButton.layer.cornerRadius = 35;
    self.doneButton.layer.masksToBounds = YES;
    [self.doneButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.size.mas_equalTo(CGSizeMake(buttonWidth, buttonWidth));
        make.centerX.equalTo(self.view.mas_centerX);
        make.centerY.equalTo(self.rebackButton.mas_centerY);
    }];
    

}

#pragma mark Event

- (BOOL)prefersStatusBarHidden
{
    return YES;
}

#pragma mark notificationCenter
- (void)changeNotifiacation:(NSNotification *)noti
{
//    TZAssetModel *model = noti.object;
//
//    //替换当前的image
//    self.takeImageView.image = model.image;
//    self.takeImage = model.image;
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    
//    if ([[touches anyObject] view] == self.startView) {
//        if (!self.isVideo) {
//            [self performSelector:@selector(endRecord) withObject:nil afterDelay:0.3];
//        } else {
//            [self endRecord];
//        }
//    }
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    
    if ([[touches anyObject] view] == self.startView) {
        
        self.rebackButton.hidden = YES;
        
        //根据设备输出获得连接
        AVCaptureConnection *connection = [self.captureMovieFileOutput connectionWithMediaType:AVMediaTypeAudio];
        //根据连接取得设备输出的数据
        if (![self.captureMovieFileOutput isRecording]) {
            
            //移除上次拍摄的视频
            if (self.saveVideoUrl) {
                [[NSFileManager defaultManager] removeItemAtURL:self.saveVideoUrl error:nil];
            }
            //预览图层和视频方向保持一致
            connection.videoOrientation = [self.previewLayer connection].videoOrientation;
            NSString *outputFielPath=[NSTemporaryDirectory() stringByAppendingString:@"myMovie.mov"];
            NSLog(@"save path is :%@",outputFielPath);
            NSURL *fileUrl=[NSURL fileURLWithPath:outputFielPath];
            NSLog(@"fileUrl:%@",fileUrl);
            [self.captureMovieFileOutput startRecordingToOutputFileURL:fileUrl recordingDelegate:self];
        } else {
            [self.captureMovieFileOutput stopRecording];
        }
    }
}

-(void)addGenstureRecognizer {
    
    UITapGestureRecognizer *tapGesture=[[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(tapScreen:)];
    [self.bgView addGestureRecognizer:tapGesture];
}

-(void)tapScreen:(UITapGestureRecognizer *)tapGesture {
    
    if ([self.session isRunning]) {
        CGPoint point= [tapGesture locationInView:self.bgView];
        //将UI坐标转化为摄像头坐标
        CGPoint cameraPoint= [self.previewLayer captureDevicePointOfInterestForPoint:point];
        [self setFocusCursorWithPoint:point];
        [self focusWithMode:AVCaptureFocusModeContinuousAutoFocus exposureMode:AVCaptureExposureModeContinuousAutoExposure atPoint:cameraPoint];
    }
}

-(void)focusWithMode:(AVCaptureFocusMode)focusMode exposureMode:(AVCaptureExposureMode)exposureMode atPoint:(CGPoint)point{
    [self changeDeviceProperty:^(AVCaptureDevice *captureDevice) {
        
        if ([captureDevice isExposureModeSupported:exposureMode]) {
            [captureDevice setExposureMode:exposureMode];
        }
        if ([captureDevice isFocusModeSupported:focusMode]) {
            [captureDevice setFocusMode:focusMode];
        }
    }];
}

/**
 *  设置聚焦光标位置
 *
 *  @param point 光标位置
 */
-(void)setFocusCursorWithPoint:(CGPoint)point{
    if (!self.isFocus) {
        self.isFocus = YES;
        self.focusCursor.center=point;
        self.focusCursor.transform = CGAffineTransformMakeScale(1.25, 1.25);
        self.focusCursor.alpha = 1.0;
        [UIView animateWithDuration:0.5 animations:^{
            self.focusCursor.transform = CGAffineTransformIdentity;
        } completion:^(BOOL finished) {
            [self performSelector:@selector(onHiddenFocusCurSorAction) withObject:nil afterDelay:0.5];
        }];
    }
}

- (void)onHiddenFocusCurSorAction {
    self.focusCursor.alpha=0;
    self.isFocus = NO;
}

/**
 *  给输入设备添加通知
 */
-(void)addNotificationToCaptureDevice:(AVCaptureDevice *)captureDevice{
    //注意添加区域改变捕获通知必须首先设置设备允许捕获
    [self changeDeviceProperty:^(AVCaptureDevice *captureDevice) {
        captureDevice.subjectAreaChangeMonitoringEnabled=YES;
    }];
    NSNotificationCenter *notificationCenter= [NSNotificationCenter defaultCenter];
    //捕获区域发生改变
    [notificationCenter addObserver:self selector:@selector(areaChange:) name:AVCaptureDeviceSubjectAreaDidChangeNotification object:captureDevice];
}

-(void)removeNotificationFromCaptureDevice:(AVCaptureDevice *)captureDevice{
    NSNotificationCenter *notificationCenter= [NSNotificationCenter defaultCenter];
    [notificationCenter removeObserver:self name:AVCaptureDeviceSubjectAreaDidChangeNotification object:captureDevice];
}

-(void)changeDeviceProperty:(PropertyChangeBlock)propertyChange{
    AVCaptureDevice *captureDevice= [self.captureDeviceInput device];
    NSError *error;
    //注意改变设备属性前一定要首先调用lockForConfiguration:调用完之后使用unlockForConfiguration方法解锁
    if ([captureDevice lockForConfiguration:&error]) {
        //自动白平衡
        if ([captureDevice isWhiteBalanceModeSupported:AVCaptureWhiteBalanceModeContinuousAutoWhiteBalance]) {
            [captureDevice setWhiteBalanceMode:AVCaptureWhiteBalanceModeContinuousAutoWhiteBalance];
        }
        //自动根据环境条件开启闪光灯
        if ([captureDevice isFlashModeSupported:AVCaptureFlashModeAuto]) {
            [captureDevice setFlashMode:AVCaptureFlashModeAuto];
        }
        
        propertyChange(captureDevice);
        [captureDevice unlockForConfiguration];
    }else{
        NSLog(@"设置设备属性过程发生错误，错误信息：%@",error.localizedDescription);
    }
}

/**
 *  取得指定位置的摄像头
 *
 *  @param position 摄像头位置
 *
 *  @return 摄像头设备
 */
-(AVCaptureDevice *)getCameraDeviceWithPosition:(AVCaptureDevicePosition )position{
    NSArray *cameras= [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for (AVCaptureDevice *camera in cameras) {
        if ([camera position] == position) {
            return camera;
        }
    }
    return nil;
}

/**
 *  设备连接成功
 *
 *  @param notification 通知对象
 */
-(void)deviceConnected:(NSNotification *)notification{
    NSLog(@"设备已连接...");
}
/**
 *  设备连接断开
 *
 *  @param notification 通知对象
 */
-(void)deviceDisconnected:(NSNotification *)notification{
    NSLog(@"设备已断开.");
}

/**
 *  捕获区域改变
 *
 *  @param notification 通知对象
 */

-(void)areaChange:(NSNotification *)notification{
    NSLog(@"捕获区域改变...");
}

/**
 *  会话出错
 *
 *  @param notification 通知对象
 */
-(void)sessionRuntimeError:(NSNotification *)notification{
    NSLog(@"会话发生错误.");
}

- (void)tranFormAction:(UIButton *)button
{
    AVCaptureDevice *currentDevice=[self.captureDeviceInput device];
    AVCaptureDevicePosition currentPosition=[currentDevice position];
    [self removeNotificationFromCaptureDevice:currentDevice];
    AVCaptureDevice *toChangeDevice;
    AVCaptureDevicePosition toChangePosition = AVCaptureDevicePositionFront;//前
    if (currentPosition == AVCaptureDevicePositionUnspecified || currentPosition == AVCaptureDevicePositionFront) {
        toChangePosition = AVCaptureDevicePositionBack;//后
    }
    toChangeDevice=[self getCameraDeviceWithPosition:toChangePosition];
    [self addNotificationToCaptureDevice:toChangeDevice];
    //获得要调整的设备输入对象
    AVCaptureDeviceInput *toChangeDeviceInput=[[AVCaptureDeviceInput alloc]initWithDevice:toChangeDevice error:nil];
    
    //改变会话的配置前一定要先开启配置，配置完成后提交配置改变
    [self.session beginConfiguration];
    //移除原有输入对象
    [self.session removeInput:self.captureDeviceInput];
    //添加新的输入对象
    if ([self.session canAddInput:toChangeDeviceInput]) {
        [self.session addInput:toChangeDeviceInput];
        self.captureDeviceInput = toChangeDeviceInput;
    }
    //提交会话配置
    [self.session commitConfiguration];
}

- (void)dissmissButtonAction:(UIButton *)button
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

//转换摄像头
- (UIButton *)transformCamera {
    if (_transformCamera == nil) {
        _transformCamera = [UIButton buttonWithType:UIButtonTypeCustom];
        [self.view addSubview:_transformCamera];
    }
    return _transformCamera;
}

//编辑
//- (UIButton *)editButton {
//    if (_editButton == nil) {
//        _editButton = [UIButton buttonWithType:UIButtonTypeCustom];
//        [self.view addSubview:_editButton];
//    }
//    return _editButton;
//}

//返回
- (UIButton *)rebackButton {
    if (_rebackButton == nil) {
        _rebackButton = [UIButton buttonWithType:UIButtonTypeCustom];
        [self.view addSubview:_rebackButton];
    }
    return _rebackButton;
}

//拍照或者摄像按钮
- (UIImageView *)startView {
    if (_startView == nil) {
        _startView = [[UIImageView alloc]init];
        _startView.userInteractionEnabled = YES;
        _startView.image = [UIImage imageNamed:@"开始"];
        [self.view addSubview:_startView];
        
        self.tipsImageView = [[UIImageView alloc]init];
        _tipsImageView.userInteractionEnabled = NO;
        _tipsImageView.image = [UIImage imageNamed:@"开始"];
//        [_startView addSubview:_tipsImageView];
    }
    return _startView;
}

//取消按钮
- (UIButton *)cancelButton {
    if (_cancelButton == nil) {
        _cancelButton = [UIButton buttonWithType:UIButtonTypeCustom];
        [self.view addSubview:_cancelButton];
        _cancelButton.hidden = YES;
        [_cancelButton addTarget:self action:@selector(cancelButtonAction:) forControlEvents:UIControlEventTouchUpInside];
    }
    return _cancelButton;
}

//进度显示
- (LongProgress *)progressView {
    if (_progressView == nil) {
        _progressView = [[LongProgress alloc]init];
        [self.view addSubview:_progressView];
    }
    return _progressView;
}

//取消按钮
- (void)cancelButtonAction:(UIButton *)button {
    
    // 删除压缩之后的文件
    if ([ICFileTool fileExistsAtPath:self.saveVideoUrl.path]) {
        [ICFileTool removeFileAtPath:self.saveVideoUrl.path];
    }
    
    [self recoverLayout];
}

//完成按钮
- (UIButton *)doneButton {
    if (_doneButton == nil) {
        _doneButton = [UIButton buttonWithType:UIButtonTypeCustom];
        [self.view addSubview:_doneButton];
        _doneButton.hidden = YES;
        
        [_doneButton addTarget:self action:@selector(doneButtonAction:) forControlEvents:UIControlEventTouchUpInside];
    }
    return _doneButton;
}


//返回uuID
- (NSString *)stringUUID {
    
    NSString * uuid = [[NSUUID UUID] UUIDString];
    return [uuid stringByReplacingOccurrencesOfString:@"-" withString:@""];
}

- (void)startRecod {
    
    //根据设备输出获得连接
    AVCaptureConnection *connection = [self.captureMovieFileOutput connectionWithMediaType:AVMediaTypeAudio];
    //根据连接取得设备输出的数据
    if (![self.captureMovieFileOutput isRecording]) {
        
        if (self.saveVideoUrl) {
            [[NSFileManager defaultManager] removeItemAtURL:self.saveVideoUrl error:nil];
        }
        //预览图层和视频方向保持一致
        connection.videoOrientation = [self.previewLayer connection].videoOrientation;
        
        NSURL *fileUrl=[NSURL fileURLWithPath:[self videoPathWithFileName:[self stringUUID]]];
        
        [self.captureMovieFileOutput startRecordingToOutputFileURL:fileUrl  recordingDelegate:self];
    } else {
        [self.captureMovieFileOutput stopRecording];
    }
}

- (void)stopRecod {
    
    if (!self.isVideo) {
        [self performSelector:@selector(endRecord) withObject:nil afterDelay:0.1];
    } else {
        [self endRecord];
    }
}

- (void)endRecord {
    
    [self.captureMovieFileOutput stopRecording];//停止录制
}

- (void)convertVideoToLowQuailtyWithInputURL:(NSURL*)inputURL
                                   outputURL:(NSURL*)outputURL finished:(RecordingFinished)finish
{
    //setup video writer
    AVAsset *videoAsset = [[AVURLAsset alloc] initWithURL:inputURL options:nil];
    
    AVAssetTrack *videoTrack = [[videoAsset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0];
    
    CGSize videoSize = videoTrack.naturalSize;
    
    NSDictionary *videoWriterCompressionSettings =  [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:1250000], AVVideoAverageBitRateKey, nil];
    
    NSDictionary *videoWriterSettings = [NSDictionary dictionaryWithObjectsAndKeys:AVVideoCodecH264, AVVideoCodecKey, videoWriterCompressionSettings, AVVideoCompressionPropertiesKey, [NSNumber numberWithFloat:videoSize.width], AVVideoWidthKey, [NSNumber numberWithFloat:videoSize.height], AVVideoHeightKey, nil];
    
    AVAssetWriterInput* videoWriterInput = [AVAssetWriterInput
                                            assetWriterInputWithMediaType:AVMediaTypeVideo
                                            outputSettings:videoWriterSettings];
    
    videoWriterInput.expectsMediaDataInRealTime = YES;
    
    videoWriterInput.transform = videoTrack.preferredTransform;
    
    AVAssetWriter *videoWriter = [[AVAssetWriter alloc] initWithURL:outputURL fileType:AVFileTypeQuickTimeMovie error:nil];
    
    [videoWriter addInput:videoWriterInput];
    
    //setup video reader
    NSDictionary *videoReaderSettings = [NSDictionary dictionaryWithObject:[NSNumber numberWithInt:kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange] forKey:(id)kCVPixelBufferPixelFormatTypeKey];
    
    AVAssetReaderTrackOutput *videoReaderOutput = [[AVAssetReaderTrackOutput alloc] initWithTrack:videoTrack outputSettings:videoReaderSettings];
    
    AVAssetReader *videoReader = [[AVAssetReader alloc] initWithAsset:videoAsset error:nil];
    
    [videoReader addOutput:videoReaderOutput];
    
    //setup audio writer
    AVAssetWriterInput* audioWriterInput = [AVAssetWriterInput
                                            assetWriterInputWithMediaType:AVMediaTypeAudio
                                            outputSettings:nil];
    
    audioWriterInput.expectsMediaDataInRealTime = NO;
    
    [videoWriter addInput:audioWriterInput];
    
    //setup audio reader
    AVAssetTrack* audioTrack = [[videoAsset tracksWithMediaType:AVMediaTypeAudio] objectAtIndex:0];
    AVAssetReaderOutput *audioReaderOutput;
    
    AVAssetReader *audioReader = [AVAssetReader assetReaderWithAsset:videoAsset error:nil];
    
    if (audioTrack != nil) {
        audioReaderOutput = [AVAssetReaderTrackOutput assetReaderTrackOutputWithTrack:audioTrack outputSettings:nil];
        [audioReader addOutput:audioReaderOutput];
    }
    
    [videoWriter startWriting];
    
    //start writing from video reader
    [videoReader startReading];
    
    [videoWriter startSessionAtSourceTime:kCMTimeZero];
    
    dispatch_queue_t processingQueue = dispatch_queue_create("processingQueue1", NULL);
    
    [videoWriterInput requestMediaDataWhenReadyOnQueue:processingQueue usingBlock:
     ^{
         
         while ([videoWriterInput isReadyForMoreMediaData]) {
             
             CMSampleBufferRef sampleBuffer;
             
             if ([videoReader status] == AVAssetReaderStatusReading &&
                 (sampleBuffer = [videoReaderOutput copyNextSampleBuffer])) {
                 
                 [videoWriterInput appendSampleBuffer:sampleBuffer];
                 CFRelease(sampleBuffer);
             }
             
             else {
                 
                 [videoWriterInput markAsFinished];
                 
                 if ([videoReader status] == AVAssetReaderStatusCompleted) {
                     
                     if (audioTrack != nil) {
                         
                         //start writing from audio reader
                         [audioReader startReading];
                         
                         [videoWriter startSessionAtSourceTime:kCMTimeZero];
                         
                         dispatch_queue_t processingQueue = dispatch_queue_create("processingQueue2", NULL);
                         
                         [audioWriterInput requestMediaDataWhenReadyOnQueue:processingQueue usingBlock:^{
                             
                             while (audioWriterInput.readyForMoreMediaData) {
                                 
                                 CMSampleBufferRef sampleBuffer;
                                 
                                 if ([audioReader status] == AVAssetReaderStatusReading &&
                                     (sampleBuffer = [audioReaderOutput copyNextSampleBuffer])) {
                                     
                                     [audioWriterInput appendSampleBuffer:sampleBuffer];
                                     CFRelease(sampleBuffer);
                                 }
                                 
                                 else {
                                     
                                     [audioWriterInput markAsFinished];
                                     
                                     if ([audioReader status] == AVAssetReaderStatusCompleted) {
                                         
                                         [videoWriter finishWritingWithCompletionHandler:^(){
                                             //                                         [self sendMovieFileAtURL:outputURL];
                                             dispatch_async(dispatch_get_main_queue(), ^{
                                                 // 这里完成了压缩
                                                 if (finish) finish([outputURL path]);
                                                 
                                             });
                                         }];
                                         
                                     }
                                 }
                             }
                             
                         }
                          ];
                     }else {
                         [videoWriter finishWritingWithCompletionHandler:^(){
                             //                                         [self sendMovieFileAtURL:outputURL];
                             dispatch_async(dispatch_get_main_queue(), ^{
                                 // 这里完成了压缩
                                 if (finish) finish([outputURL path]);
                                 
                             });
                         }];
                     }
                     
                     
                 }
             }
         }
     }
     ];
}


- (NSString *)compressVideo:(NSString *)path finished:(RecordingFinished)finish
{
    
    
    
    NSURL *url = [NSURL fileURLWithPath:path];
    // 获取文件资源
    AVURLAsset *avAsset = [[AVURLAsset alloc] initWithURL:url options:nil];
    // 导出资源属性
    NSArray *presets = [AVAssetExportSession exportPresetsCompatibleWithAsset:avAsset];
    // 是否包含中分辨率，如果是低分辨率AVAssetExportPresetLowQuality则不清晰
    if ([presets containsObject:AVAssetExportPresetMediumQuality]) {
        // 重定义资源属性
        
        AVAssetExportSession *exportSession = [[AVAssetExportSession alloc] initWithAsset:avAsset presetName:AVAssetExportPresetMediumQuality];
        // 压缩后的文件路径
        
        AVMutableVideoComposition *videoComposition = [self fixedCompositionWithAsset:avAsset];
        if (videoComposition.renderSize.width) {
            // 修正视频转向
            exportSession.videoComposition = videoComposition;
        }
        
        NSString *outPutPath = [self videoPathWithFileName:[NSString stringWithFormat:@"%@",[self stringUUID]]];
        exportSession.outputURL = [NSURL fileURLWithPath:outPutPath];
        exportSession.shouldOptimizeForNetworkUse = YES;// 是否对网络进行优化
        exportSession.outputFileType = AVFileTypeQuickTimeMovie; // 转成MP4
        // 导出
        [exportSession exportAsynchronouslyWithCompletionHandler:^{
            if ([exportSession status] == AVAssetExportSessionStatusCompleted) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    // 这里完成了压缩
                    if (finish) finish(outPutPath);
                    
                });
            }
        }];
        return outPutPath;
    }
    return nil;
}


/// 获取优化后的视频转向信息
- (AVMutableVideoComposition *)fixedCompositionWithAsset:(AVAsset *)videoAsset {
    AVMutableVideoComposition *videoComposition = [AVMutableVideoComposition videoComposition];
    // 视频转向
    int degrees = [self degressFromVideoFileWithAsset:videoAsset];
    if (degrees != 0) {
        CGAffineTransform translateToCenter;
        CGAffineTransform mixedTransform;
        videoComposition.frameDuration = CMTimeMake(1, 30);
        
        NSArray *tracks = [videoAsset tracksWithMediaType:AVMediaTypeVideo];
        AVAssetTrack *videoTrack = [tracks objectAtIndex:0];
        
        if (degrees == 90) {
            // 顺时针旋转90°
            translateToCenter = CGAffineTransformMakeTranslation(videoTrack.naturalSize.height, 0.0);
            mixedTransform = CGAffineTransformRotate(translateToCenter,M_PI_2);
            videoComposition.renderSize = CGSizeMake(videoTrack.naturalSize.height,videoTrack.naturalSize.width);
        } else if(degrees == 180){
            // 顺时针旋转180°
            translateToCenter = CGAffineTransformMakeTranslation(videoTrack.naturalSize.width, videoTrack.naturalSize.height);
            mixedTransform = CGAffineTransformRotate(translateToCenter,M_PI);
            videoComposition.renderSize = CGSizeMake(videoTrack.naturalSize.width,videoTrack.naturalSize.height);
        } else {
            // 顺时针旋转270°
            translateToCenter = CGAffineTransformMakeTranslation(0.0, videoTrack.naturalSize.width);
            mixedTransform = CGAffineTransformRotate(translateToCenter,M_PI_2*3.0);
            videoComposition.renderSize = CGSizeMake(videoTrack.naturalSize.height,videoTrack.naturalSize.width);
        }
        
        AVMutableVideoCompositionInstruction *roateInstruction = [AVMutableVideoCompositionInstruction videoCompositionInstruction];
        roateInstruction.timeRange = CMTimeRangeMake(kCMTimeZero, [videoAsset duration]);
        AVMutableVideoCompositionLayerInstruction *roateLayerInstruction = [AVMutableVideoCompositionLayerInstruction videoCompositionLayerInstructionWithAssetTrack:videoTrack];
        
        [roateLayerInstruction setTransform:mixedTransform atTime:kCMTimeZero];
        
        roateInstruction.layerInstructions = @[roateLayerInstruction];
        // 加入视频方向信息
        videoComposition.instructions = @[roateInstruction];
    }
    return videoComposition;
}

/// 获取视频角度
- (int)degressFromVideoFileWithAsset:(AVAsset *)asset {
    int degress = 0;
    NSArray *tracks = [asset tracksWithMediaType:AVMediaTypeVideo];
    if([tracks count] > 0) {
        AVAssetTrack *videoTrack = [tracks objectAtIndex:0];
        CGAffineTransform t = videoTrack.preferredTransform;
        if(t.a == 0 && t.b == 1.0 && t.c == -1.0 && t.d == 0){
            // Portrait
            degress = 90;
        } else if(t.a == 0 && t.b == -1.0 && t.c == 1.0 && t.d == 0){
            // PortraitUpsideDown
            degress = 270;
        } else if(t.a == 1.0 && t.b == 0 && t.c == 0 && t.d == 1.0){
            // LandscapeRight
            degress = 0;
        } else if(t.a == -1.0 && t.b == 0 && t.c == 0 && t.d == -1.0){
            // LandscapeLeft
            degress = 180;
        }
    }
    return degress;
}

- (CGFloat)getFileSize:(NSString *)path
{
    NSDictionary *outputFileAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil];
    return [outputFileAttributes fileSize]/1024.0/1024.0;
}

- (NSString *)videoPathWithFileName:(NSString *)videoName
{
    NSString *path = [[NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) lastObject] stringByAppendingPathComponent:@"Video"];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    BOOL isDirExist = [fileManager fileExistsAtPath:path];
    if (!isDirExist) {
        BOOL isCreatDir = [fileManager createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];
        if (!isCreatDir) {
            NSLog(@"create folder failed");
            return nil;
        }
    }
    return [path stringByAppendingPathComponent:[NSString stringWithFormat:@"%@%@",videoName,@".mp4"]];
}

#pragma mark - 视频输出代理
-(void)captureOutput:(AVCaptureFileOutput *)captureOutput didStartRecordingToOutputFileAtURL:(NSURL *)fileURL fromConnections:(NSArray *)connections{
    
    NSLog(@"开始录制...");
    self.seconds = self.HSeconds;
    [self performSelector:@selector(onStartTranscribe:) withObject:fileURL afterDelay:0.6];
}

-(void)captureOutput:(AVCaptureFileOutput *)captureOutput didFinishRecordingToOutputFileAtURL:(NSURL *)outputFileURL fromConnections:(NSArray *)connections error:(NSError *)error{
    
    
    if (self.isVideo) {
        [self changeLayout];
        
        UIView *view = [UIApplication sharedApplication].keyWindow;
        MBProgressHUD *HUD = [[MBProgressHUD alloc] initWithView:view];
        HUD.labelText = @"正在处理...";
        [view addSubview:HUD];
        [HUD show:YES];
        
        NSString *outPutPath = [self videoPathWithFileName:[NSString stringWithFormat:@"%@",[self stringUUID]]];
        
        [self convertVideoToLowQuailtyWithInputURL:outputFileURL outputURL:[NSURL fileURLWithPath:outPutPath] finished:^(NSString *path) {
            
            if (path) {
                
                NSURL *pathUrl = [NSURL fileURLWithPath:path];
                
                if (!self.player) {
                    self.player = [[VideoPlay alloc] initWithFrame:self.bgView.bounds withShowInView:self.bgView url:pathUrl];
                } else {
                    if (pathUrl) {
                        self.player.videoUrl = pathUrl;
                        
                        [UIView animateWithDuration:.1 animations:^{
                            self.player.alpha = 1;
                        }];
                    }
                }
                self.saveVideoUrl = pathUrl;
                
                NSLog(@"压缩后文件的大小：%f",[self getFileSize:path]);
                [HUD hide:YES];
                [self layoutFrame];
                
                // 删除原录制的文件
                if ([ICFileTool fileExistsAtPath:outputFileURL.path]) {
                    [ICFileTool removeFileAtPath:outputFileURL.path];
                }
            }
            
            
        }];
        
        
        return ;
        
        //第二种方式
        [self compressVideo:[outputFileURL path] finished:^(NSString *path) {
            if (path) {
                
                NSURL *pathUrl = [NSURL fileURLWithPath:path];
                
                if (!self.player) {
                    self.player = [[VideoPlay alloc] initWithFrame:self.bgView.bounds withShowInView:self.bgView url:pathUrl];
                } else {
                    if (pathUrl) {
                        self.player.videoUrl = pathUrl;
                        
                        [UIView animateWithDuration:.1 animations:^{
                            self.player.alpha = 1;
                        }];
                        
                    }
                }
                self.saveVideoUrl = pathUrl;
                
                NSLog(@"压缩后文件的大小：%f",[self getFileSize:path]);
                [HUD hide:YES];
                [self layoutFrame];
                
                // 删除原录制的文件
                if ([ICFileTool fileExistsAtPath:outputFileURL.path]) {
                    [ICFileTool removeFileAtPath:outputFileURL.path];
                }
            }
        }];
        
    } else {
        //照片
        self.saveVideoUrl = nil;
        
        [self videoHandlePhoto:outputFileURL];
        
        [self photoChangeLayout];
        
    }
}

//拍摄完成时调用
- (void)changeLayout {
    
    self.transformCamera.hidden = YES;
    self.rebackButton.hidden = YES;
    
    if (self.isVideo) {
        [self.progressView clearProgress];
        [self.progressView mas_updateConstraints:^(MASConstraintMaker *make) {
            make.size.mas_equalTo(CGSizeMake(buttonWidth, buttonWidth));
            make.centerX.mas_equalTo(self.view.mas_centerX);
            make.centerY.equalTo(self.rebackButton.mas_centerY);
            
        }];
        
        [UIView animateWithDuration:.1 animations:^{
            [self.view layoutIfNeeded];
            
        }completion:^(BOOL finished) {
            self.progressView.alpha = 0;
            self.startView.hidden = YES;
            
        }];
    } else {
//        self.editButton.hidden = NO;
    }
    [self.session stopRunning];
}

- (void)layoutFrame {
    
    self.cancelButton.hidden = NO;
    self.doneButton.hidden = NO;
    
    [self.cancelButton mas_updateConstraints:^(MASConstraintMaker *make) {
        make.centerX.equalTo(self.view.mas_centerX).offset(-self.view.frame.size.width /3);
    }];
    
    [self.doneButton mas_updateConstraints:^(MASConstraintMaker *make) {
        make.centerX.equalTo(self.view.mas_centerX).offset(self.view.frame.size.width /3);
    }];
    
    [UIView animateWithDuration:0.25 animations:^{
        [self.view layoutIfNeeded];
    }];
    
}

- (void)photoChangeLayout {
    
    self.startView.hidden = YES;
    self.transformCamera.hidden = YES;
    self.cancelButton.hidden = NO;
    self.doneButton.hidden = NO;
    self.rebackButton.hidden = YES;
    
//    self.editButton.hidden = NO;
    
    [self.cancelButton mas_updateConstraints:^(MASConstraintMaker *make) {
        make.centerX.equalTo(self.view.mas_centerX).offset(-self.view.frame.size.width /3);
    }];
    
    [self.doneButton mas_updateConstraints:^(MASConstraintMaker *make) {
        make.centerX.equalTo(self.view.mas_centerX).offset(self.view.frame.size.width /3);
        
    }];
    
    [UIView animateWithDuration:0.25 animations:^{
        [self.view layoutIfNeeded];
    }];
    
    [self.session stopRunning];
}

//重新拍摄时调用
- (void)recoverLayout {
    
    if (self.isVideo) {
        self.isVideo = NO;
        [self.player stopPlayer];
        _startView.image = [UIImage imageNamed:@"开始"];
        [UIView animateWithDuration:.1 animations:^{
            self.player.alpha = 0;
        }];
    }
    
    [self.session startRunning];
    
    if (!self.takeImageView.hidden) {
        self.takeImageView.hidden = YES;
    }
    self.saveVideoUrl = nil;
    
    [self.cancelButton mas_updateConstraints:^(MASConstraintMaker *make) {
        make.centerX.equalTo(self.view.mas_centerX);
        
    }];
    
    [self.doneButton mas_updateConstraints:^(MASConstraintMaker *make) {
        make.centerX.equalTo(self.view.mas_centerX);
        
    }];
    
    if (self.saveVideoUrl) {
        [[NSFileManager defaultManager] removeItemAtURL:self.saveVideoUrl error:nil];
    }
    
//    self.editButton.hidden = YES;
    self.startView.hidden = NO;
    self.transformCamera.hidden = NO;
    self.cancelButton.hidden = YES;
    self.doneButton.hidden = YES;
    self.rebackButton.hidden = NO;
    [UIView animateWithDuration:0.25 animations:^{
        [self.view layoutIfNeeded];
    }];
}

- (void)onStartTranscribe:(NSURL *)fileURL {
    
    if ([self.captureMovieFileOutput isRecording]) {
        -- self.seconds;
        
        if (self.seconds > 0) {
            if (self.HSeconds - self.seconds >= TimeMax && !self.isVideo) {
                self.isVideo = YES;//长按时间超过TimeMax 表示是视频录制
                self.progressView.timeMax = self.seconds;
                
                _startView.image = [UIImage imageNamed:@"结束"];
                
                self.progressView.alpha = 1;
                
                [self.progressView mas_updateConstraints:^(MASConstraintMaker *make) {
                    make.size.mas_equalTo(CGSizeMake(120, 120));
                    make.centerX.mas_equalTo(self.view.mas_centerX);
                    make.centerY.equalTo(self.rebackButton.mas_centerY);
                    
                }];
                
                [UIView animateWithDuration:.25 animations:^{
                    [self.view layoutIfNeeded];
                    
                }completion:^(BOOL finished) {
                    
                }];
                
            }
            
   
            
            [self performSelector:@selector(onStartTranscribe:) withObject:fileURL afterDelay:1.0];
        } else {
            
            _startView.image = [UIImage imageNamed:@"开始"];

            if ([self.captureMovieFileOutput isRecording]) {
                [self.captureMovieFileOutput stopRecording];
            }
        }
    }
}

- (void)videoHandlePhoto:(NSURL *)url {
    
    AVURLAsset *urlSet = [AVURLAsset assetWithURL:url];
    AVAssetImageGenerator *imageGenerator = [AVAssetImageGenerator assetImageGeneratorWithAsset:urlSet];
    imageGenerator.appliesPreferredTrackTransform = YES;    // 截图的时候调整到正确的方向
    NSError *error = nil;
    CMTime time = CMTimeMake(0,30);//缩略图创建时间 CMTime是表示电影时间信息的结构体，第一个参数表示是视频第几秒，第二个参数表示每秒帧数.(如果要获取某一秒的第几帧可以使用CMTimeMake方法)
    CMTime actucalTime; //缩略图实际生成的时间
    CGImageRef cgImage = [imageGenerator copyCGImageAtTime:time actualTime:&actucalTime error:&error];
    if (error) {
        NSLog(@"截取视频图片失败:%@",error.localizedDescription);
    }
    CMTimeShow(actucalTime);
    UIImage *image = [UIImage imageWithCGImage:cgImage];
    
    CGImageRelease(cgImage);
    if (image) {
        NSLog(@"视频截取成功");
    } else {
        NSLog(@"视频截取失败");
    }
    
    self.takeImage = image;
    
    //移除视频，只保留图片
    [[NSFileManager defaultManager] removeItemAtURL:url error:nil];
    
    if (!self.takeImageView) {
        self.takeImageView = [[UIImageView alloc] initWithFrame:self.view.frame];
        [self.bgView addSubview:self.takeImageView];
    }
    self.takeImageView.hidden = NO;
    self.takeImageView.image = self.takeImage;
}

//编辑
- (void)editButtonAction:(UIButton *)button {
    
//    TZEditPhotoViewController *tzEditePhotoVC = [[TZEditPhotoViewController alloc]init];
//    tzEditePhotoVC.image = self.takeImage;
//    tzEditePhotoVC.isRecentPhoto = YES;
//    [self presentViewController:tzEditePhotoVC animated:NO completion:nil];
}

- (void)doneButtonAction:(UIButton *)button {
    
    ALAuthorizationStatus author = [ALAssetsLibrary authorizationStatus];
    
    if (self.isVideo) {
        NSLog(@"发送视频");
        
        if (author == ALAuthorizationStatusRestricted || author == ALAuthorizationStatusDenied) {
            if (self.takeBlock) {
                self.takeBlock(self.saveVideoUrl,1);
            }
            [self dismissViewControllerAnimated:YES completion:nil];
            
        } else {
            if (self.saveVideoUrl) {
                
                UISaveVideoAtPathToSavedPhotosAlbum([self.saveVideoUrl path], self, @selector(video:didFinishSavingWithError:contextInfo:), nil);
            }
        }
        
    } else {
        NSLog(@"发送图片");
        //将照片写入相册
        
        if (author == ALAuthorizationStatusRestricted || author == ALAuthorizationStatusDenied) {
            
        } else {
            if (self.takeImage) {
                UIImageWriteToSavedPhotosAlbum(self.takeImage,self, @selector(image:didFinishSavingWithError:contextInfo:), nil);
            }
        }
        
        if (self.takeBlock) {
            self.takeBlock(self.takeImage,0);
        }
        [self dismissViewControllerAnimated:YES completion:nil];
    }
}

//保存图片
- (void)image:(UIImage *)image
didFinishSavingWithError:(NSError *)error
  contextInfo:(void *)contextInfo
{
    // Was there an error?
    if (error != NULL)
    {
        // Show error message...
        
    } else {
        
        // Show message image successfully saved
    }
}

//保存视频
- (void)video:(NSString *)videoPath didFinishSavingWithError:(NSError *)error contextInfo:(void *)contextInfo{
    // Was there an error?
    if (error != NULL)
    {
        // Show error message...
        if (self.takeBlock) {
            self.takeBlock(self.saveVideoUrl,1);
        }
        [self dismissViewControllerAnimated:YES completion:nil];
    }
    else  {
        if (self.takeBlock) {
            self.takeBlock(self.saveVideoUrl,1);
        }
        [self dismissViewControllerAnimated:YES completion:nil];
        
        // Show message image successfully saved
    }
}

-(void)dealloc{
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
