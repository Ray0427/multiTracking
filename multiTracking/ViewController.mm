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
//#import <math.h>
#define CIRCLE_COLOR CV_RGB(255,0,0)
#define CIRCLE_SIZE 1
//default capture width and height
const int FRAME_WIDTH = 640;
const int FRAME_HEIGHT = 480;
//max number of objects to be detected in frame
const int MAX_NUM_OBJECTS=50;
//minimum and maximum object area
const int MIN_OBJECT_AREA = 3*3;
const int MAX_OBJECT_AREA = FRAME_HEIGHT*FRAME_WIDTH/1.5;
const double SIZE_DIFF=0.05;
const int centerRange=20;
bool orangeFlag=false,blueFlag=false;

using namespace cv;

@interface ViewController ()

@end

@implementation ViewController
@synthesize videoCamera,response;

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    self.videoCamera =[[CvVideoCamera alloc]initWithParentView:imageView];
    self.videoCamera.defaultAVCaptureDevicePosition = AVCaptureDevicePositionBack;
    self.videoCamera.defaultAVCaptureSessionPreset = AVCaptureSessionPreset1280x720;
    self.videoCamera.defaultAVCaptureVideoOrientation = AVCaptureVideoOrientationPortrait;
    self.videoCamera.defaultFPS = 10;
    self.videoCamera.grayscaleMode = NO;
    self.videoCamera.delegate = self;
//    [self.videoCamera start];
    self->H.minimumValue = 0;
    self->H.maximumValue = 40;
    self->S.minimumValue = 100;
    self->S.maximumValue = 255;
    self->V.minimumValue = 160;
    self->V.maximumValue = 255;

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
//        cv::circle(frame,cv::Point(theObjects.at(i).getXPos(),theObjects.at(i).getYPos()),5,theObjects.at(i).getColor());
//        cv::putText(frame,intToString(theObjects.at(i).getXPos())+ " , " + intToString(theObjects.at(i).getYPos()),cv::Point(theObjects.at(i).getXPos(),theObjects.at(i).getYPos()+20),1,1,theObjects.at(i).getColor());
//        cv::putText(frame,theObjects.at(i).getType()+std::to_string(i),cv::Point(theObjects.at(i).getXPos(),theObjects.at(i).getYPos()-20),1,2,theObjects.at(i).getColor());
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


vector<Object> trackFilteredObject(Object theObject,Mat threshold,Mat HSV, Mat &cameraFeed){
    
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
                
                //if the area is less than 3 px by 3px then it is probably just noise
                //if the area is the same as the 3/2 of the image size, probably just a bad filter
                //we only want the object with the largest area so we safe a reference area each
                //iteration and compare it to the area in the next iteration.
                if(area>MIN_OBJECT_AREA){
                    
                    Object object;
                    
                    object.setXPos(moment.m10/area);
                    object.setYPos(moment.m01/area);
                    object.setArea(area);
                    object.setType(theObject.getType());
                    object.setColor(theObject.getColor());
                    
                    objects.push_back(object);
                    
                    objectFound = true;
                    
                }else objectFound = false;
            }
            //let user know you found an object
            if(objectFound ==true){
                //draw object location on screen
                //drawObject(objects,cameraFeed,temp,contours,hierarchy);
            }
            
        }else putText(cameraFeed,"TOO MUCH NOISE! ADJUST FILTER",cv::Point(0,50),1,2,Scalar(0,0,255),2);
    }
    return objects;
}
#ifdef __cplusplus
- (void)processImage:(Mat&)image;
{
    vector<Object> orangeObjects,blueObjects;
    Mat threshold;
    Mat threshold2;
    Mat HSV;
    cvtColor(image,HSV,COLOR_BGR2HSV);
    Object orange("orange"),blue("blue");
    int row=image.rows,
    col=image.cols;
    orangeFlag=false;
    blueFlag=false;
    
    cvtColor(image,HSV,COLOR_BGR2HSV);
    inRange(HSV,Scalar(H.value,S.value,V.value),orange.getHSVmax(),threshold);
    morphOps(threshold);
    inRange(HSV,blue.getHSVmin(),blue.getHSVmax(),threshold2);
    morphOps(threshold2);
    
    if(_hsv.on){
        image=threshold;
    }
    orangeObjects=trackFilteredObject(orange,threshold,HSV,image);
    if (orangeObjects.size()>1) {
        orangeFlag=true;
        log(1);
        for (int i=0; i<orangeObjects.size()-1; i++) {
            for (int j=i+1; j<orangeObjects.size(); j++) {
                int posX=(orangeObjects.at(i).getXPos()+orangeObjects.at(j).getXPos())/2;
                int posY=(orangeObjects.at(i).getYPos()+orangeObjects.at(j).getYPos())/2;
                
//                printf("(%d,%d)",(orangeObjects.at(i).getXPos()+orangeObjects.at(j).getXPos())/2,(orangeObjects.at(i).getYPos()+orangeObjects.at(j).getYPos())/2);
//                printf("%d\n",threshold2.at<uchar>((orangeObjects.at(i).getYPos()+orangeObjects.at(j).getYPos())/2, (orangeObjects.at(i).getXPos()+orangeObjects.at(j).getXPos())/2));
                //中心是藍色
                if (threshold2.at<uchar>(posY, posX)==255) {
                    blueFlag=true;
                    //兩個橘色面積差小於0.05
                    int area1=orangeObjects.at(i).getArea(),
                    area2=orangeObjects.at(j).getArea();
                    if(abs((area1-area2)/area2)<SIZE_DIFF){
                        //printf("%d,%d,%f\n",orangeObjects.at(i).getArea(),orangeObjects.at(j).getArea(),pow(orangeObjects.at(i).getXPos()-orangeObjects.at(j).getXPos(),2)+pow(orangeObjects.at(i).getYPos()-orangeObjects.at(j).getYPos(),2));
                        //printf("%f\n",(pow(orangeObjects.at(i).getXPos()-orangeObjects.at(j).getXPos(),2)+pow(orangeObjects.at(i).getYPos()-orangeObjects.at(j).getYPos(),2))/(orangeObjects.at(i).getArea()+orangeObjects.at(j).getArea()));
                        //距離與大小比小於5
                        if ((pow(orangeObjects.at(i).getXPos()-orangeObjects.at(j).getXPos(),2)+pow(orangeObjects.at(i).getYPos()-orangeObjects.at(j).getYPos(),2))/(area1+area2)<5) {
                            cv::circle(image,cv::Point(posX,posY),10,Scalar(0,0,255));
                            cv::putText(image,intToString(posX)+ " , " + intToString(posY),cv::Point(posX,posY+20),1,1,Scalar(0,0,255));
                            cv::putText(image,"center",cv::Point(posX,posY-20),1,4,Scalar(0,0,255));
//                            printf("%d %d %d %d\n",row,col,posX,posY);
                            if (posX<col/2-centerRange) {
                                response.text=@"飛機應向右";
                            }
                            else if (posX>col/2+centerRange){
                                response.text=@"飛機應向左";

                            }
                            else{
                                if (posY<row/2-centerRange) {
                                    response.text=@"飛機應向下";

                                }
                                else if (posY>row/2+centerRange){
                                    response.text=@"飛機應向上";

                                }
                                else{
                                    response.text=@"飛機到達中心";

                                }
                            }
                            NSLog(@"\n%@ size:%d (%d,%d) (%d,%d)",response.text,area1+area2,orangeObjects.at(i).getXPos(),orangeObjects.at(i).getYPos(),orangeObjects.at(j).getXPos(),orangeObjects.at(j).getYPos());
                        }
                    }
                }
            }
        }
    }

    
}
#endif
- (IBAction)actionStart:(id)sender;
{
    [self.videoCamera start];
}

- (IBAction)actionStop:(id)sender {
    [self.videoCamera stop];
}

- (IBAction)H:(UISlider *)sender {
    Hvalue.text=[NSString stringWithFormat:@"%d",(int)sender.value];
}

- (IBAction)S:(UISlider *)sender {
    Svalue.text=[NSString stringWithFormat:@"%d",(int)sender.value];
}

- (IBAction)V:(UISlider *)sender {
    Vvalue.text=[NSString stringWithFormat:@"%d",(int)sender.value];
}

@end
