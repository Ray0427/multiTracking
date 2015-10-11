//
//  ViewController.h
//  multiTracking
//
//  Created by RAY on 2015/8/26.
//  Copyright (c) 2015年 RAY. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <opencv2/highgui/cap_ios.h>
#import <opencv2/objdetect/objdetect.hpp>
#import <opencv2/imgproc/imgproc_c.h>
#import "multizTracking-Prefix.pch"
using namespace cv;
@interface ViewController : UIViewController <CvVideoCameraDelegate>
{
__weak IBOutlet UIImageView *imageView;
    CvVideoCamera* videoCamera;
    
    __weak IBOutlet UISlider *H;
    __weak IBOutlet UILabel *Hvalue;
    __weak IBOutlet UISlider *S;
    __weak IBOutlet UILabel *Svalue;
    __weak IBOutlet UISlider *V;
    __weak IBOutlet UILabel *Vvalue;
}
@property (nonatomic,retain) CvVideoCamera* videoCamera;
- (IBAction)actionStart:(id)sender;
- (IBAction)actionStop:(id)sender;
@property (strong, nonatomic) IBOutlet UISwitch *hsv;
- (IBAction)H:(UISlider *)sender;
- (IBAction)S:(UISlider *)sender;
- (IBAction)V:(UISlider *)sender;
@property (strong, nonatomic) IBOutlet UILabel *response;

@end

