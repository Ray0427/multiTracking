//
//  PilotingViewController.h
//  multiTracking
//
//  Created by RAY on 2015/10/20.
//  Copyright (c) 2015年 RAY. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <libARDiscovery/ARDISCOVERY_BonjourDiscovery.h>
#import "VideoView.h"
#import <CoreLocation/CoreLocation.h>
#import <opencv2/highgui/cap_ios.h>
#import <opencv2/objdetect/objdetect.hpp>
#import <opencv2/imgproc/imgproc_c.h>
#import "multizTracking-Prefix.pch"

@interface PilotingViewController : UIViewController <CLLocationManagerDelegate,CvVideoCameraDelegate>
{
    __weak IBOutlet UIImageView *imageView;
    CvVideoCamera* videoCamera;
}
@property (nonatomic, strong) ARService* service;

@property (strong, nonatomic) IBOutlet UIView *pictureView;
@property (strong, nonatomic) IBOutlet UIView *takeoffView;
@property (nonatomic, strong) IBOutlet VideoView *videoView;

@property (nonatomic, strong) IBOutlet UILabel *batteryLabel;

@property (nonatomic, strong) CLLocationManager *locationManager;
@property eARCOMMANDS_ARDRONE3_PILOTINGSTATE_FLYINGSTATECHANGED_STATE flyingState;
@property float droneHeading;
@property float phoneHeading;
@property BOOL isTouch;
@property BOOL isFirstCalibration;
@property (nonatomic,retain) CvVideoCamera* videoCamera;

- (IBAction)emergencyClick:(id)sender;
- (IBAction)takeoffClick:(id)sender;
- (IBAction)landingClick:(id)sender;

- (IBAction)gazUpTouchDown:(id)sender;
- (IBAction)gazDownTouchDown:(id)sender;

- (IBAction)gazUpTouchUp:(id)sender;
- (IBAction)gazDownTouchUp:(id)sender;


- (IBAction)yawLeftTouchDown:(id)sender;
- (IBAction)yawRightTouchDown:(id)sender;

- (IBAction)yawLeftTouchUp:(id)sender;
- (IBAction)yawRightTouchUp:(id)sender;


- (IBAction)rollLeftTouchDown:(id)sender;
- (IBAction)rollRightTouchDown:(id)sender;

- (IBAction)rollLeftTouchUp:(id)sender;
- (IBAction)rollRightTouchUp:(id)sender;


- (IBAction)pitchForwardTouchDown:(id)sender;
- (IBAction)pitchBackTouchDown:(id)sender;

- (IBAction)pitchForwardTouchUp:(id)sender;
- (IBAction)pitchBackTouchUp:(id)sender;

- (IBAction)stillClicked:(id)sender;

@end
