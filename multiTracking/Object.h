#pragma once
#include <string>
#include <opencv2/opencv.hpp>
//#include <cv.h>
#include <opencv2/highgui/highgui.hpp>
using namespace std;
using namespace cv;

class Object
{
public:
	Object();
	~Object(void);

	Object(string name);

	int getXPos();
	void setXPos(int x);

	int getYPos();
	void setYPos(int y);

    int getArea();
    void setArea(int a);
    
	Scalar getHSVmin();
	Scalar getHSVmax();

	void setHSVmin(Scalar min);
	void setHSVmax(Scalar max);

	string getType(){return type;}
	void setType(string t){type = t;}

	Scalar getColor(){
		return Color;
	}
	void setColor(Scalar c){

		Color = c;
	}

private:

	int xPos, yPos,area;
	string type;
	Scalar HSVmin, HSVmax;
	Scalar Color;
};
