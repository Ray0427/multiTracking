//
//  ViewController.m
//  multiTracking
//
//  Created by RAY on 2015/8/26.
//  Copyright (c) 2015年 RAY. All rights reserved.
//

#import "ViewController.h"
#import "Object.h"
#import <vector>
#define CIRCLE_COLOR CV_RGB(255,0,0)
#define CIRCLE_SIZE 1
//default capture width and height
const int FRAME_WIDTH = 640;
const int FRAME_HEIGHT = 480;
//max number of objects to be detected in frame
const int MAX_NUM_OBJECTS=50;
//minimum and maximum object area
const int MIN_OBJECT_AREA = 30*30;
const int MAX_OBJECT_AREA = FRAME_HEIGHT*FRAME_WIDTH/1.5;
using namespace cv;

@interface ViewController ()

@end

@implementation ViewController
@synthesize videoCamera;

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    self.videoCamera =[[CvVideoCamera alloc]initWithParentView:imageView];
    self.videoCamera.defaultAVCaptureDevicePosition = AVCaptureDevicePositionBack;
    self.videoCamera.defaultAVCaptureSessionPreset = AVCaptureSessionPresetMedium;
    self.videoCamera.defaultAVCaptureVideoOrientation = AVCaptureVideoOrientationPortrait;
    self.videoCamera.defaultFPS = 30;
    self.videoCamera.grayscaleMode = NO;
    self.videoCamera.delegate = self;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

string intToString(int number){
    
    std::stringstream ss;
    ss << number;
    return ss.str();
}

void drawObject(vector<Object> theObjects,Mat &frame, Mat &temp, vector< vector<cv::Point> > contours, vector<Vec4i> hierarchy){
    
    for(int i =0; i<theObjects.size(); i++){
        cv::drawContours(frame,contours,i,theObjects.at(i).getColor(),3,8,hierarchy);
        cv::circle(frame,cv::Point(theObjects.at(i).getXPos(),theObjects.at(i).getYPos()),5,theObjects.at(i).getColor());
        cv::putText(frame,intToString(theObjects.at(i).getXPos())+ " , " + intToString(theObjects.at(i).getYPos()),cv::Point(theObjects.at(i).getXPos(),theObjects.at(i).getYPos()+20),1,1,theObjects.at(i).getColor());
        cv::putText(frame,theObjects.at(i).getType(),cv::Point(theObjects.at(i).getXPos(),theObjects.at(i).getYPos()-20),1,2,theObjects.at(i).getColor());
    }
}

void morphOps(Mat &thresh){
    Mat erodeElement=getStructuringElement(MORPH_RECT, cv::Size(3,3));
    Mat dilateElement = getStructuringElement( MORPH_RECT,cv::Size(8,8));
    
    erode(thresh,thresh,erodeElement);
    erode(thresh,thresh,erodeElement);
    
    dilate(thresh,thresh,dilateElement);
    dilate(thresh,thresh,dilateElement);
}


void trackFilteredObject(Object theObject,Mat threshold,Mat HSV, Mat &cameraFeed){
    
    vector <Object> objects;
    Mat temp;
    threshold.copyTo(temp);
    //these two vectors needed for output of findContours
    vector< vector<cv::Point> > contours;
    vector<Vec4i> hierarchy;
    //find contours of filtered image using openCV findContours function
    findContours(temp,contours,hierarchy,CV_RETR_CCOMP,CV_CHAIN_APPROX_SIMPLE );
    //use moments method to find our filtered object
    double refArea = 0;
    bool objectFound = false;
    if (hierarchy.size() > 0) {
        int numObjects = hierarchy.size();
        //if number of objects greater than MAX_NUM_OBJECTS we have a noisy filter
        if(numObjects<MAX_NUM_OBJECTS){
            for (int index = 0; index >= 0; index = hierarchy[index][0]) {
                
                Moments moment = moments((cv::Mat)contours[index]);
                double area = moment.m00;
                
                //if the area is less than 20 px by 20px then it is probably just noise
                //if the area is the same as the 3/2 of the image size, probably just a bad filter
                //we only want the object with the largest area so we safe a reference area each
                //iteration and compare it to the area in the next iteration.
                if(area>MIN_OBJECT_AREA){
                    
                    Object object;
                    
                    object.setXPos(moment.m10/area);
                    object.setYPos(moment.m01/area);
                    object.setType(theObject.getType());
                    object.setColor(theObject.getColor());
                    
                    objects.push_back(object);
                    
                    objectFound = true;
                    
                }else objectFound = false;
            }
            //let user know you found an object
            if(objectFound ==true){
                //draw object location on screen
                drawObject(objects,cameraFeed,temp,contours,hierarchy);}
            
        }else putText(cameraFeed,"TOO MUCH NOISE! ADJUST FILTER",cv::Point(0,50),1,2,Scalar(0,0,255),2);
    }
}
#ifdef __cplusplus
- (void)processImage:(Mat&)image;
{
    Mat threshold;
    Mat HSV;
    cvtColor(image,HSV,COLOR_BGR2HSV);
    Object orange("orange"),blue("blue");
//    Object blue("blue"), yellow("yellow"), red("red"), green("green");
    
    //first find blue objects
    cvtColor(image,HSV,COLOR_BGR2HSV);
    inRange(HSV,blue.getHSVmin(),blue.getHSVmax(),threshold);
    morphOps(threshold);
    trackFilteredObject(blue,threshold,HSV,image);
    //then oranges
    cvtColor(image,HSV,COLOR_BGR2HSV);
    inRange(HSV,orange.getHSVmin(),orange.getHSVmax(),threshold);
    morphOps(threshold);
    trackFilteredObject(orange,threshold,HSV,image);
    /*//then yellows
    cvtColor(image,HSV,COLOR_BGR2HSV);
    inRange(HSV,yellow.getHSVmin(),yellow.getHSVmax(),threshold);
    morphOps(threshold);
    trackFilteredObject(yellow,threshold,HSV,image);
    //then reds
    cvtColor(image,HSV,COLOR_BGR2HSV);
    inRange(HSV,red.getHSVmin(),red.getHSVmax(),threshold);
    morphOps(threshold);
    trackFilteredObject(red,threshold,HSV,image);
    //then greens
    cvtColor(image,HSV,COLOR_BGR2HSV);
    inRange(HSV,green.getHSVmin(),green.getHSVmax(),threshold);
    morphOps(threshold);
    trackFilteredObject(green,threshold,HSV,image);
    */
    
    /*
    CvMat cvimage=image;
    CvSize size = cvGetSize(&cvimage);
    CvScalar hsv_min = cvScalar(0,170,210,0);//cvScalar(0,100,220,0);
    CvScalar hsv_max = cvScalar(20,210,255,0);//cvScalar(40,170,255,0);
    CvScalar hsv_min2 = cvScalar(150, 200, 200);
    CvScalar hsv_max2 = cvScalar(200, 255, 256);
    CvPoint center;
    IplImage *hsv_frame = cvCreateImage(size, IPL_DEPTH_8U, 3);;
    
    IplImage*  thresholded   = cvCreateImage(size, IPL_DEPTH_8U, 1);
    IplImage*  thresholded2   = cvCreateImage(size, IPL_DEPTH_8U, 1);
    CvMemStorage* storage=cvCreateMemStorage(0);
    
    
    
    cvCvtColor(&cvimage, hsv_frame, CV_BGR2HSV);
    
    
 
    
    //    thresholded = hsv_frame;
    //inRange(hsv_frame, hsv_min, hsv_max, thresholded);
    cvInRangeS(hsv_frame, hsv_min, hsv_max, thresholded);
    cvInRangeS(hsv_frame, hsv_min2, hsv_max2, thresholded2);
    //    cvOr(thresholded, thresholded2, thresholded);
    //    image= Mat(thresholded);
    //equalizeHist(grayScaleFrame, grayScaleFrame);
    //IplImage tmp=IplImage(thresholded);
    //    IplImage tmp2=IplImage(thresholded2);
    cvSmooth(thresholded, thresholded,CV_GAUSSIAN, 9, 9);
    CvSeq* circles= cvHoughCircles(thresholded, storage, CV_HOUGH_GRADIENT, 2, (thresholded->height)/4,100,40,8,100);
    float maxRadius=0;
    for (int i=0; i<circles->total; i++) {
        float* p = (float*)cvGetSeqElem(circles, i);
        printf("w=%d h=%d x=%f y=%f r=%f\n",size.width,size.height,p[0],p[1],p[2]);
        if (p[2]>maxRadius) {
            maxRadius=p[2];
            center.x=p[0];
            center.y=p[1];
            cvCircle(&cvimage, center, 3, CIRCLE_COLOR);
            cvCircle(&cvimage, center, p[2], CIRCLE_COLOR, CIRCLE_SIZE);
        }
        
        
        //        cvCircle(thresholded, center, 3, CV_RGB(0, 255, 0));
        //        cvCircle(thresholded, center, p[2], CV_RGB(255, 255, 0));
        
    }
    
    //    Vec3f color= image.at<Vec3f>(0,0);
    //    printf("R=%u G=%u B=%f\n",color.val[0],color.val[1],color.val[2]);
    
    image = Mat(&cvimage);
    
    cvReleaseMemStorage(&storage);
    cvReleaseImage(&hsv_frame);
    cvReleaseImage(&thresholded);
    cvReleaseImage(&thresholded2);
    
    */
}
#endif
- (IBAction)actionStart:(id)sender;
{
    [self.videoCamera start];
}

- (IBAction)actionStop:(id)sender {
    [self.videoCamera stop];
}
@end
