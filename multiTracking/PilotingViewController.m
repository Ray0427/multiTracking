//
//  PilotingViewController.m
//  multiTracking
//
//  Created by RAY on 2015/10/20.
//  Copyright (c) 2015年 RAY. All rights reserved.
//

#import "PilotingViewController.h"
#import <libARDiscovery/ARDiscovery.h>
#import <libARController/ARController.h>
#import <uthash/uthash.h>
#define ALLOWANCE_THRESHOLD 10


@interface PilotingViewController ()
@property (nonatomic) ARCONTROLLER_Device_t *deviceController;
@property (nonatomic, strong) UIAlertView *alertView;
@property (nonatomic) dispatch_semaphore_t stateSem;
@property (nonatomic) dispatch_semaphore_t resolveSemaphore;

@end

@implementation PilotingViewController
@synthesize videoCamera;

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    //cv
    self.videoCamera =[[CvVideoCamera alloc]initWithParentView:imageView];
    self.videoCamera.defaultAVCaptureDevicePosition = AVCaptureDevicePositionBack;
    self.videoCamera.defaultAVCaptureSessionPreset = AVCaptureSessionPreset1280x720;
    self.videoCamera.defaultAVCaptureVideoOrientation = AVCaptureVideoOrientationPortrait;
    self.videoCamera.defaultFPS = 10;
    self.videoCamera.grayscaleMode = NO;
    self.videoCamera.delegate = self;
        [self.videoCamera start];

    
    [_batteryLabel setText:@"?%"];
    
    _alertView = [[UIAlertView alloc] initWithTitle:[_service name] message:@"Connecting ..."
                                           delegate:self cancelButtonTitle:nil otherButtonTitles:nil, nil];
    
    _deviceController = NULL;
    _stateSem = dispatch_semaphore_create(0);
    
    _locationManager = [[CLLocationManager alloc] init];
    _locationManager.delegate = self;
    
    _phoneHeading = 0;
    _droneHeading = 0;
    _isTouch = false;
    _isFirstCalibration = false;
    
    _takeoffView.hidden = false;
    [self.view bringSubviewToFront:_takeoffView];
    _pictureView.hidden = true;
    //    _videoView.hidden = true;
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(orientationChanged:) name:UIApplicationDidChangeStatusBarOrientationNotification object:nil];
}

- (void) viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    [_alertView show];
    
    // call createDeviceControllerWithService in background
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        // create the device controller
        [self createDeviceControllerWithService:_service];
    });
}

#pragma mark
- (void)createDeviceControllerWithService:(ARService*)service
{
    // first get a discovery device
    ARDISCOVERY_Device_t *discoveryDevice = [self createDiscoveryDeviceWithService:service];
    
    if (discoveryDevice != NULL)
    {
        eARCONTROLLER_ERROR error = ARCONTROLLER_OK;
        
        // create the device controller
        NSLog(@"- ARCONTROLLER_Device_New ... ");
        _deviceController = ARCONTROLLER_Device_New (discoveryDevice, &error);
        
        if ((error != ARCONTROLLER_OK) || (_deviceController == NULL))
        {
            NSLog(@"- error :%s", ARCONTROLLER_Error_ToString(error));
        }
        
        // add the state change callback to be informed when the device controller starts, stops...
        if (error == ARCONTROLLER_OK)
        {
            NSLog(@"- ARCONTROLLER_Device_AddStateChangedCallback ... ");
            error = ARCONTROLLER_Device_AddStateChangedCallback(_deviceController, stateChanged, (__bridge void *)(self));
            
            if (error != ARCONTROLLER_OK)
            {
                NSLog(@"- error :%s", ARCONTROLLER_Error_ToString(error));
            }
        }
        
        // add the command received callback to be informed when a command has been received from the device
        if (error == ARCONTROLLER_OK)
        {
            NSLog(@"- ARCONTROLLER_Device_AddCommandRecievedCallback ... ");
            error = ARCONTROLLER_Device_AddCommandReceivedCallback(_deviceController, onCommandReceived, (__bridge void *)(self));
            
            if (error != ARCONTROLLER_OK)
            {
                NSLog(@"- error :%s", ARCONTROLLER_Error_ToString(error));
            }
        }
        
        // add the received frame callback to be informed when a frame should be displayed
        if (error == ARCONTROLLER_OK)
        {
            NSLog(@"- ARCONTROLLER_Device_SetVideoReceiveCallback ... ");
            error = ARCONTROLLER_Device_SetVideoReceiveCallback (_deviceController, didReceiveFrameCallback, NULL , (__bridge void *)(self));
            
            if (error != ARCONTROLLER_OK)
            {
                NSLog(@"- error :%s", ARCONTROLLER_Error_ToString(error));
            }
        }
        
        // start the device controller (the callback stateChanged should be called soon)
        if (error == ARCONTROLLER_OK)
        {
            NSLog(@"- ARCONTROLLER_Device_Start ... ");
            error = ARCONTROLLER_Device_Start (_deviceController);
            
            if (error != ARCONTROLLER_OK)
            {
                NSLog(@"- error :%s", ARCONTROLLER_Error_ToString(error));
            }
        }
        
        // we don't need the discovery device anymore
        ARDISCOVERY_Device_Delete (&discoveryDevice);
        
        // if an error occured, go back
        if (error != ARCONTROLLER_OK)
        {
            [self goBack];
        }
    }
    else
    {
        [self goBack];
    }
}

- (ARDISCOVERY_Device_t *)createDiscoveryDeviceWithService:(ARService*)service
{
    ARDISCOVERY_Device_t *device = NULL;
    
    eARDISCOVERY_ERROR errorDiscovery = ARDISCOVERY_OK;
    
    NSLog(@"- init discovery device  ... ");
    
    device = ARDISCOVERY_Device_New (&errorDiscovery);
    if ((errorDiscovery != ARDISCOVERY_OK) || (device == NULL))
    {
        NSLog(@"device : %p", device);
        NSLog(@"Discovery error :%s", ARDISCOVERY_Error_ToString(errorDiscovery));
    }
    
    if (errorDiscovery == ARDISCOVERY_OK)
    {
        // init the discovery device
        if (service.product == ARDISCOVERY_PRODUCT_ARDRONE)
        {
            // need to resolve service to get the IP
            BOOL resolveSucceeded = [self resolveService:service];
            
            if (resolveSucceeded)
            {
                NSString *ip = [[ARDiscovery sharedInstance] convertNSNetServiceToIp:service];
                int port = (int)[(NSNetService *)service.service port];
                
                if (ip)
                {
                    // create a Wifi discovery device
                    errorDiscovery = ARDISCOVERY_Device_InitWifi (device, service.product, [service.name UTF8String], [ip UTF8String], port);
                }
                else
                {
                    NSLog(@"ip is null");
                    errorDiscovery = ARDISCOVERY_ERROR;
                }
            }
            else
            {
                NSLog(@"Resolve error");
                errorDiscovery = ARDISCOVERY_ERROR;
            }
        }
        
        if (errorDiscovery != ARDISCOVERY_OK)
        {
            NSLog(@"Discovery error :%s", ARDISCOVERY_Error_ToString(errorDiscovery));
            ARDISCOVERY_Device_Delete(&device);
        }
    }
    
    return device;
}

- (void) viewDidDisappear:(BOOL)animated
{
    if (_alertView && !_alertView.isHidden)
    {
        [_alertView dismissWithClickedButtonIndex:0 animated:NO];
    }
    _alertView = [[UIAlertView alloc] initWithTitle:[_service name] message:@"Disconnecting ..."
                                           delegate:self cancelButtonTitle:nil otherButtonTitles:nil, nil];
    [_alertView show];
    
    // in background
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        eARCONTROLLER_ERROR error = ARCONTROLLER_OK;
        
        // if the device controller is not stopped, stop it
        eARCONTROLLER_DEVICE_STATE state = ARCONTROLLER_Device_GetState(_deviceController, &error);
        if ((error == ARCONTROLLER_OK) && (state != ARCONTROLLER_DEVICE_STATE_STOPPED))
        {
            // after that, stateChanged should be called soon
            error = ARCONTROLLER_Device_Stop (_deviceController);
            
            if (error != ARCONTROLLER_OK)
            {
                NSLog(@"- error :%s", ARCONTROLLER_Error_ToString(error));
            }
            else
            {
                // wait for the state to change to stopped
                NSLog(@"- wait new state ... ");
                dispatch_semaphore_wait(_stateSem, DISPATCH_TIME_FOREVER);
            }
        }
        
        // once the device controller is stopped, we can delete it
        if (_deviceController != NULL)
        {
            ARCONTROLLER_Device_Delete(&_deviceController);
        }
        
        // dismiss the alert view in main thread
        dispatch_async(dispatch_get_main_queue(), ^{
            [_alertView dismissWithClickedButtonIndex:0 animated:TRUE];
        });
    });
}

- (void)goBack
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.navigationController popViewControllerAnimated:YES];
    });
}

#pragma mark Device controller callbacks
// called when the state of the device controller has changed
void stateChanged (eARCONTROLLER_DEVICE_STATE newState, eARCONTROLLER_ERROR error, void *customData)
{
    PilotingViewController *pilotingViewController = (__bridge PilotingViewController *)customData;
    
    NSLog (@"newState: %d",newState);
    
    if (pilotingViewController != nil)
    {
        switch (newState)
        {
            case ARCONTROLLER_DEVICE_STATE_RUNNING:
            {
                // dismiss the alert view in main thread
                dispatch_async(dispatch_get_main_queue(), ^{
                    [pilotingViewController.alertView dismissWithClickedButtonIndex:0 animated:TRUE];
                });
                break;
            }
            case ARCONTROLLER_DEVICE_STATE_STOPPED:
            {
                dispatch_semaphore_signal(pilotingViewController.stateSem);
                
                // Go back
                dispatch_async(dispatch_get_main_queue(), ^{
                    [pilotingViewController goBack];
                });
                
                break;
            }
                
            case ARCONTROLLER_DEVICE_STATE_STARTING:
                break;
                
            case ARCONTROLLER_DEVICE_STATE_STOPPING:
                break;
                
            default:
                NSLog(@"new State : %d not known", newState);
                break;
        }
    }
}

// called when a command has been received from the drone
void onCommandReceived (eARCONTROLLER_DICTIONARY_KEY commandKey, ARCONTROLLER_DICTIONARY_ELEMENT_t *elementDictionary, void *customData)
{
    PilotingViewController *pilotingViewController = (__bridge PilotingViewController *)customData;
    
    if (elementDictionary != NULL) {
        ARCONTROLLER_DICTIONARY_ARG_t *arg = NULL;
        ARCONTROLLER_DICTIONARY_ELEMENT_t *element = NULL;
        
        // get the command received in the device controller
        HASH_FIND_STR (elementDictionary, ARCONTROLLER_DICTIONARY_SINGLE_KEY, element);
        if (element != NULL) {
            switch (commandKey) {
                case // if the command received is a battery state changed
                ARCONTROLLER_DICTIONARY_KEY_COMMON_COMMONSTATE_BATTERYSTATECHANGED:
                {
                    // get the value
                    HASH_FIND_STR (element->arguments, ARCONTROLLER_DICTIONARY_KEY_COMMON_COMMONSTATE_BATTERYSTATECHANGED_PERCENT, arg);
                    if (arg != NULL) {
                        // update UI
                        [pilotingViewController onUpdateBatteryLevel:arg->value.U8];
                    }
                    break;
                }
                    
                case // if the command received is a attitude changed
                ARCONTROLLER_DICTIONARY_KEY_ARDRONE3_PILOTINGSTATE_ATTITUDECHANGED:
                {
                    HASH_FIND_STR(element->arguments, ARCONTROLLER_DICTIONARY_KEY_ARDRONE3_PILOTINGSTATE_ATTITUDECHANGED_YAW, arg);
                    if (arg != NULL) {
                        float fheading = (arg->value.Float * 180 / M_PI);
                        // convert to [0, 360]
                        if (fheading < 0) {
                            fheading = fheading + 360;
                        }
                        // update value of _droneHeading
                        pilotingViewController.droneHeading = fheading;
                        if (pilotingViewController.isTouch || pilotingViewController.isFirstCalibration) {
                            [pilotingViewController checkHeading];
                        }
                    }
                    break;
                }
                    
                case // if the command received is a flying state changed
                ARCONTROLLER_DICTIONARY_KEY_ARDRONE3_PILOTINGSTATE_FLYINGSTATECHANGED:
                {
                    HASH_FIND_STR(element->arguments, ARCONTROLLER_DICTIONARY_KEY_ARDRONE3_PILOTINGSTATE_FLYINGSTATECHANGED_STATE, arg);
                    if (arg != NULL) {
                        int32_t lastState = pilotingViewController.flyingState;
                        pilotingViewController.flyingState = (eARCOMMANDS_ARDRONE3_PILOTINGSTATE_FLYINGSTATECHANGED_STATE)(arg->value.I32);
                        if (lastState == ARCOMMANDS_ARDRONE3_PILOTINGSTATE_FLYINGSTATECHANGED_STATE_TAKINGOFF) {
                            // it means that takingoff is just completed
                            // set isFirstCallbration to TRUE to do first calibration
                            [pilotingViewController.locationManager startUpdatingHeading];
                            pilotingViewController.isFirstCalibration = true;
                        }
                        else if (lastState == ARCOMMANDS_ARDRONE3_PILOTINGSTATE_FLYINGSTATECHANGED_STATE_LANDING) {
                            pilotingViewController.takeoffView.hidden = false;
                            [pilotingViewController.view bringSubviewToFront: pilotingViewController.takeoffView];
                        }
                    }
                    break;
                }
                    
                default:
                    break;
            }
        }
    }
}

void didReceiveFrameCallback (ARCONTROLLER_Frame_t *frame, void *customData)
{
    PilotingViewController *pilotingViewController = (__bridge PilotingViewController *)customData;
    
    [pilotingViewController.videoView displayFrame:frame];
}

#pragma mark events

- (IBAction)emergencyClick:(id)sender
{
    // send an emergency command to the Bebop
    _deviceController->aRDrone3->sendPilotingEmergency(_deviceController->aRDrone3);
}

- (IBAction)takeoffClick:(id)sender
{
    //    _deviceController->aRDrone3->sendPilotingTakeOff(_deviceController->aRDrone3);
    _takeoffView.hidden = true;
    [self.view sendSubviewToBack:_takeoffView];
}

- (IBAction)landingClick:(id)sender
{
    //    _deviceController->aRDrone3->sendPilotingLanding(_deviceController->aRDrone3);
    self.takeoffView.hidden = false;
    [self.view bringSubviewToFront: _takeoffView];
}

//events for gaz:
- (IBAction)gazUpTouchDown:(id)sender
{
    // set the gaz value of the piloting command
    _deviceController->aRDrone3->setPilotingPCMDGaz(_deviceController->aRDrone3, 50);
}
- (IBAction)gazDownTouchDown:(id)sender
{
    _deviceController->aRDrone3->setPilotingPCMDGaz(_deviceController->aRDrone3, -50);
}

- (IBAction)gazUpTouchUp:(id)sender
{
    _deviceController->aRDrone3->setPilotingPCMDGaz(_deviceController->aRDrone3, 0);
}
- (IBAction)gazDownTouchUp:(id)sender
{
    _deviceController->aRDrone3->setPilotingPCMDGaz(_deviceController->aRDrone3, 0);
}

//events for yaw:
- (IBAction)yawLeftTouchDown:(id)sender
{
    _deviceController->aRDrone3->setPilotingPCMDYaw(_deviceController->aRDrone3, -50);
}
- (IBAction)yawRightTouchDown:(id)sender
{
    _deviceController->aRDrone3->setPilotingPCMDYaw(_deviceController->aRDrone3, 50);
}

- (IBAction)yawLeftTouchUp:(id)sender
{
    _deviceController->aRDrone3->setPilotingPCMDYaw(_deviceController->aRDrone3, 0);
}

- (IBAction)yawRightTouchUp:(id)sender
{
    _deviceController->aRDrone3->setPilotingPCMDYaw(_deviceController->aRDrone3, 0);
}

//events for yaw:
- (IBAction)rollLeftTouchDown:(id)sender
{
    _deviceController->aRDrone3->setPilotingPCMDFlag(_deviceController->aRDrone3, 1);
    _deviceController->aRDrone3->setPilotingPCMDRoll(_deviceController->aRDrone3, -30);
}
- (IBAction)rollRightTouchDown:(id)sender
{
    _deviceController->aRDrone3->setPilotingPCMDFlag(_deviceController->aRDrone3, 1);
    _deviceController->aRDrone3->setPilotingPCMDRoll(_deviceController->aRDrone3, 30);
}

- (IBAction)rollLeftTouchUp:(id)sender
{
    _deviceController->aRDrone3->setPilotingPCMDFlag(_deviceController->aRDrone3, 0);
    _deviceController->aRDrone3->setPilotingPCMDRoll(_deviceController->aRDrone3, 0);
}
- (IBAction)rollRightTouchUp:(id)sender
{
    _deviceController->aRDrone3->setPilotingPCMDFlag(_deviceController->aRDrone3, 0);
    _deviceController->aRDrone3->setPilotingPCMDRoll(_deviceController->aRDrone3, 0);
}

//events for pitch:
- (IBAction)pitchForwardTouchDown:(id)sender
{
    _deviceController->aRDrone3->setPilotingPCMDFlag(_deviceController->aRDrone3, 1);
    _deviceController->aRDrone3->setPilotingPCMDPitch(_deviceController->aRDrone3, 50);
}
- (IBAction)pitchBackTouchDown:(id)sender
{
    _deviceController->aRDrone3->setPilotingPCMDFlag(_deviceController->aRDrone3, 1);
    _deviceController->aRDrone3->setPilotingPCMDPitch(_deviceController->aRDrone3, -50);
}

- (IBAction)pitchForwardTouchUp:(id)sender
{
    _deviceController->aRDrone3->setPilotingPCMDFlag(_deviceController->aRDrone3, 0);
    _deviceController->aRDrone3->setPilotingPCMDPitch(_deviceController->aRDrone3, 0);
}
- (IBAction)pitchBackTouchUp:(id)sender
{
    _deviceController->aRDrone3->setPilotingPCMDFlag(_deviceController->aRDrone3, 0);
    _deviceController->aRDrone3->setPilotingPCMDPitch(_deviceController->aRDrone3, 0);
}

- (IBAction)stillClicked:(id)sender {
    //    _deviceController->aRDrone3->sendMediaRecordPictureV2(_deviceController->aRDrone3);
    UIImageWriteToSavedPhotosAlbum([self captureView:_videoView], self, @selector(image:didFinishSavingWithError:contextInfo:), nil);
}

- (UIImage*)captureView: (UIView *)view {
    CGRect rect = [view bounds];
    UIGraphicsBeginImageContextWithOptions(rect.size, NO, view.contentScaleFactor);
    //    UIGraphicsBeginImageContext(rect.size);
    //    CGContextRef context = UIGraphicsGetCurrentContext();
    //    [view.layer renderInContext:context];
    [view drawViewHierarchyInRect:view.bounds afterScreenUpdates:YES];
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    NSData* imageData =  UIImagePNGRepresentation(img);
    UIImage* pngImage = [UIImage imageWithData:imageData];
    UIGraphicsEndImageContext();
    return pngImage;
}

//自行建立判斷儲存成功與否的函式
- (void)image:(UIImage *)image didFinishSavingWithError:(NSError *)error contextInfo:(void *)contextInfo {
    UIAlertView *alert;
    
    //以error參數判斷是否成功儲存影像
    if (error) {
        alert = [[UIAlertView alloc] initWithTitle:@"錯誤"
                                           message:[error description]
                                          delegate:self
                                 cancelButtonTitle:@"確定"
                                 otherButtonTitles:nil];
    } else {
        alert = [[UIAlertView alloc] initWithTitle:@"成功"
                                           message:@"影像已存入相簿中"
                                          delegate:self
                                 cancelButtonTitle:@"確定"
                                 otherButtonTitles:nil];
    }
    [alert show];
}

// method will be called when device's orientation has changed
- (void) orientationChanged: (NSNotification *) note {
    UIDevice *device = [UIDevice currentDevice];
    
    if (device.orientation == UIDeviceOrientationPortrait || device.orientation == UIDeviceOrientationPortraitUpsideDown) {
        // display pilotingView
        _pictureView.hidden = true;
        [self.view sendSubviewToBack:_pictureView];
    }
    else if (device.orientation == UIDeviceOrientationLandscapeLeft || device.orientation == UIDeviceOrientationLandscapeRight) {
        // display VideoView
        _pictureView.hidden = false;
        [self.view bringSubviewToFront:_pictureView];
    }
}

#pragma mark UI updates from commands
- (void)onUpdateBatteryLevel:(uint8_t)percent;
{
    NSLog(@"onUpdateBattery ...");
    
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *text = [[NSString alloc] initWithFormat:@"%d%%", percent];
        [_batteryLabel setText:text];
    });
}

#pragma mark resolveService
- (BOOL)resolveService:(ARService*)service
{
    BOOL retval = NO;
    _resolveSemaphore = dispatch_semaphore_create(0);
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(discoveryDidResolve:) name:kARDiscoveryNotificationServiceResolved object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(discoveryDidNotResolve:) name:kARDiscoveryNotificationServiceNotResolved object:nil];
    
    [[ARDiscovery sharedInstance] resolveService:service];
    
    // this semaphore will be signaled in discoveryDidResolve and discoveryDidNotResolve
    dispatch_semaphore_wait(_resolveSemaphore, DISPATCH_TIME_FOREVER);
    
    NSString *ip = [[ARDiscovery sharedInstance] convertNSNetServiceToIp:service];
    if (ip != nil)
    {
        retval = YES;
    }
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kARDiscoveryNotificationServiceResolved object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kARDiscoveryNotificationServiceNotResolved object:nil];
    _resolveSemaphore = nil;
    return retval;
}

- (void)discoveryDidResolve:(NSNotification *)notification
{
    dispatch_semaphore_signal(_resolveSemaphore);
}

- (void)discoveryDidNotResolve:(NSNotification *)notification
{
    NSLog(@"Resolve failed");
    dispatch_semaphore_signal(_resolveSemaphore);
}

#pragma mark CLLocationManagerDelegate protocol method
- (void) locationManager:(CLLocationManager *)manager didUpdateHeading:(CLHeading *)newHeading {
    _phoneHeading = newHeading.magneticHeading;
}

#pragma mark touch events handle
- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    _isTouch = true;
    [_locationManager startUpdatingHeading];
}

//// stop update phone heading and calibration when touch is end
//// no matter whether calibration is completed or not
- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    _isTouch = false;
    [self stopHeadingCalibration];
    [_locationManager stopUpdatingHeading];
}

#pragma mark heading calibration method
- (void) checkHeading {
    // check whether the heading of drone need to calibration
    float expectedHeading;
    if (_phoneHeading >= 180) {
        expectedHeading = _phoneHeading - 180;
    }
    else {
        expectedHeading = _phoneHeading + 180;
    }
    
    float diff = expectedHeading - _droneHeading;
    if ( diff < -ALLOWANCE_THRESHOLD || diff > ALLOWANCE_THRESHOLD ) {
        [self headingCalibration:expectedHeading];
    }
    else {
        // if heading is ok, stop the rotation of yaw
        [self stopHeadingCalibration];
        if (_isFirstCalibration) {
            // first calibration completed, stop phoneHeading update and hide takeoffView
            NSLog(@"First calibration completed");
            _isFirstCalibration = false;
            [self.locationManager stopUpdatingHeading];
            _takeoffView.hidden = true;
            [self.view sendSubviewToBack:_takeoffView];
        }
    }
}

- (void) headingCalibration: (float) expectedHeading {
    if (expectedHeading <= 180) {
        if ( (_droneHeading < expectedHeading) || (_droneHeading > _phoneHeading) ) {
            // Clockwise
            _deviceController->aRDrone3->setPilotingPCMDYaw(_deviceController->aRDrone3, 50);
        }
        else {
            // Counterclockwise
            _deviceController->aRDrone3->setPilotingPCMDYaw(_deviceController->aRDrone3, -50);
        }
    }
    else {
        if ( (_droneHeading < expectedHeading) && (_droneHeading > _phoneHeading) ) {
            // Clockwise
            _deviceController->aRDrone3->setPilotingPCMDYaw(_deviceController->aRDrone3, 50);
        }
        else {
            // Counterclockwise
            _deviceController->aRDrone3->setPilotingPCMDYaw(_deviceController->aRDrone3, -50);
        }
    }
}

- (void) stopHeadingCalibration {
    _deviceController->aRDrone3->setPilotingPCMDYaw(_deviceController->aRDrone3, 0);
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}
#ifdef __cplusplus
- (void)processImage:(cv::Mat&)image;
{
    Mat threshold;
    Mat threshold2;
    Mat HSV;
    cvtColor(image,HSV,COLOR_BGR2HSV);
}
#endif
/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
