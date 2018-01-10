#include <iostream>
#include <fstream>
#include <cstring>
using namespace std;

#include <wiringPi.h>
#include <math.h>


//Binary patterns for commands, read direct from device
#define RED_UP 0b0010100011010111
#define RED_DN 0b0000100011110111
#define GRN_UP 0b1010100001010111
#define GRN_DN 0b1000100001110111
#define BLU_UP 0b0110100010010111
#define BLU_DN 0b0100100010110111
#define POWER  0b0000001011111101
#define DIY1   0b0011000011001111
#define DIY2   0b1011000001001111

//Command timing parameters, read from device, microseconds
#define T_DOWN  9000
#define T_UP    4500
#define T_0     500
#define T_1     1500
#define T_BTWN  500
#define T_DELAY 100000


//Pin on pi to send commands from
#define CMD_PIN 7

//Length of sunrise, seconds
#define SUNRISE_LENGTH 3600

//How long to hold blue sky after sun has risen, seconds
#define HOLD_TIME 45

//How often does dawn check current time and update LEDs, seconds
#define UPDATE_PERIOD 5

//Return values for getSecsRemaining() that indicate alternative modes
#define DEMO 100001
#define OFF  100002




//Class to store rgb color and some useful operators
class Color
{
public:
    unsigned char r, g, b;

    Color() { r=0; g=0; b=0; }
    Color(unsigned int r, unsigned int g, unsigned int b) : r(r), g(g), b(b){}

    inline Color& operator*= (float factor)
    {
        r *= factor;
        g *= factor;
        b *= factor;
        return *this;
    }
    inline bool operator== (const Color& rhs)
    {
        if(r == rhs.r && g == rhs.g && b == rhs.b) return true;
        else return false;
    }
    inline bool operator!= (const Color& rhs)
    {
        return !(*this == rhs);
    }
};

//Global variable that stores current color of LEDs
Color currentColor;

//Ensures value is between maximum and minimum
unsigned char clamp(unsigned char value, unsigned char minimum, unsigned char maximum)
{
    if(value >= maximum) return maximum;
    if(value <= minimum) return minimum;
    return value;
}
float clamp(float value, float minimum, float maximum)
{
    if(value >= maximum) return maximum;
    if(value <= minimum) return minimum;
    return value;
}

//Gets color from blackbody temperature in kelvin
//Adapted from http://www.tannerhelland.com/4435/convert-temperature-rgb-algorithm-code/
Color getBB(float temp)
{
    temp /= 100;

    Color bbColor;
    float red, grn, blu;

    if(temp <= 66) bbColor.r = 255;
    else
    {
        red = temp - 60;
        red = 329.698727446 * pow(red, -0.1332047592);
        bbColor.r = clamp(red, 0, 255);


    }

    if(temp <= 66)
    {
        grn = temp;
        grn = 99.4708025861 * log(grn) - 161.1195681661;
        grn *= 0.75; //yellow range was looking a little too green
        bbColor.g = clamp(grn, 0, 255);
    }
    else
    {
        grn = temp - 60;
        grn = 288.1221695283 * pow(grn, -0.0755148492);
        bbColor.g = clamp(grn, 0, 255);
    }

    if(temp >= 66) bbColor.b = 255;
    else if(temp <= 19) bbColor.b = 0;
    else
    {
        blu = temp-10;
        blu = 138.5177312231 * log(blu) - 305.0447927307;
        bbColor.b = clamp(blu, 0, 255);
    }

    //These magic numbers come from my messing around until I liked the colors
    float brightness = pow((float)(temp-6.59)/35, 0.2);
    brightness = clamp(brightness, 0.0, 1.0);
    bbColor *= brightness;
    return bbColor;
}

//Low-level functions for interfacing with LED controller
void sendBit(bool bit)
{
    //Configure bit length
    int bitlen;
    if(bit == 0) bitlen = T_0;
    if(bit == 1) bitlen = T_1;

    digitalWrite(CMD_PIN, LOW);
    delayMicroseconds(T_BTWN);
    digitalWrite(CMD_PIN, HIGH);
    delayMicroseconds(bitlen);
}
void sendCommand(uint16_t command)
{
    //Timing is critical so set priority high
    piHiPri(99);

    //Send initial pull down
    digitalWrite(CMD_PIN, LOW);
    delayMicroseconds(T_DOWN);

    //Release for time up
    digitalWrite(CMD_PIN, HIGH);
    delayMicroseconds(T_UP);

    //Write 8 zeroes then 8 ones
    for(int i = 0; i < 8; i++) sendBit(0);
    for(int i = 0; i < 8; i++) sendBit(1);

    //Send 16-bit command
    for(int bit = 0; bit < 16; bit++)
        sendBit( command & (0x8000>>bit) );

    //Last interbit space
    digitalWrite(CMD_PIN, LOW);
    delayMicroseconds(T_BTWN);
    digitalWrite(CMD_PIN, HIGH);

    //Delay minimum time between commands
    delayMicroseconds(T_DELAY);

    //Return to low priority to free up processor
    piHiPri(0);
}

//High level functions for interfacing with LED controller
void setColor(Color color)
{
    //LEDs operate in 64-state rather than 256-state color space; adjust
    color *= 0.25;

    //For whatever reason sometimes the color glitches and setting it
    //to the setting fixes it
    sendCommand(DIY1);

    while(currentColor != color)
    {
        if(currentColor.r < color.r)
        {
            sendCommand(RED_UP);
            currentColor.r++;
        }
        if(currentColor.r > color.r)
        {
            sendCommand(RED_DN);
            currentColor.r--;
        }
        if(currentColor.g < color.g)
        {
            sendCommand(GRN_UP);
            currentColor.g++;
        }
        if(currentColor.g > color.g)
        {
            sendCommand(GRN_DN);
            currentColor.g--;
        }
        if(currentColor.b < color.b)
        {
            sendCommand(BLU_UP);
            currentColor.b++;
        }
        if(currentColor.b > color.b)
        {
            sendCommand(BLU_DN);
            currentColor.b--;
        }
    }

}
void resetColor() //Used for definitively going back to zero
{
    //Repeat 80 times because 64-state color space
    //and average 1/20 fail rate for commands sent
    for(int i = 0; i < 80; i++)
    {
        sendCommand(RED_DN);
        sendCommand(GRN_DN);
        sendCommand(BLU_DN);
    }
    currentColor = Color(0,0,0);
}

//Gets number of seconds until dawn end setting
int getSecsRemaining()
{

    //Get current time
    time_t rawTime;
    struct tm* currentTime;
    time(&rawTime);
    currentTime = localtime(&rawTime);

    //Get time for dawn to complete from /etc/dawn/dawn.conf
    ifstream readfile("/etc/dawn/dawn.conf");
    string line;
    string dawnHour;
    string dawnMinute;
    if(readfile.is_open())
    {
        //Read data in file
        getline(readfile, line);

        //Check for alternate modes
        if(line == "demo") return DEMO;
        if(line == "off" ) return OFF;

        //If there is a colon, ie 12:34 format, remove it
        size_t colonIndex = line.find(':');
        if(colonIndex != string::npos) line.erase(colonIndex, 1);

        //Determine hour and minute from data in 1234 format
        dawnHour   = line.substr(0, 2);
        dawnMinute = line.substr(2, 2);
    }
    else
    {
        cout << "Could not open /etc/dawn/dawn.conf";
        return -1;
    }
    readfile.close();

    //Determine time remaining until dawn to complete
    int secsRemaining = 0;
    secsRemaining += ( stoi(dawnHour  ) - currentTime->tm_hour ) * 3600;
    secsRemaining += ( stoi(dawnMinute) - currentTime->tm_min  ) * 60;
    secsRemaining -= currentTime->tm_sec;

    //If secsRemaining negative, dawn to happen tomorrow. Add 24 hours.
    if(secsRemaining < 0) secsRemaining += 24*3600;

    return secsRemaining;
}

//Does a 60-second demonstration of simulation for when people ask to show the thing
void demo()
{
    cout << "Starting demo." << endl;
    //Run sunrise in 60 seconds. For code reference see main().
    for(int i = 0; i < 60; i++)
    {
        float temp = pow( (float)i / 60.0, 2.0);
        temp *= (float)i * (4800.0 / 60.0);
        temp += 663.0;

        setColor(getBB(temp));
    }
    cout << "Demo complete, resetting color." <<endl;
    resetColor();
}

int main(int argc, char *argv[])
{
    //If dawn is called with an argument, process
    if(argc == 2)
    {


        //Otherwise it is to update time.
        ofstream writefile("/etc/dawn/dawn.conf", ios::out | ios::trunc);
        writefile << argv[1];

        cout << "dawn set to " << argv[1] << '.' << endl;

        return 0;
    }

    //If dawn is called with more than one argument, it is error
    if(argc > 2)
    {
        cout << "dawn takes at most one argument." << endl;
    }

    //If no arguments, it is to start the dawn program
    if(argc == 1)
    {
        //Initialize
        wiringPiSetup();
        pinMode(CMD_PIN, OUTPUT);
        digitalWrite(CMD_PIN, HIGH); //Default state of receiver is pulled up
        currentColor = Color(0, 0, 0);
        bool inProgress = false; //Stores whether sunrise in progress
        cout << "dawn started." << endl;

        //Main loop
        while(true)
        {
            //Run update every 5 seconds
            delay(UPDATE_PERIOD * 1000);

            //Determine time remaining
            int secsRemaining = getSecsRemaining();
            if(secsRemaining < 0) continue; //if case error

            //If we are not in a sunrise mode but in an alternative mode do as proper
            if(secsRemaining == DEMO) demo();
            if(secsRemaining == OFF ) continue;

            //If we are within a minute of sunrise start, or later,
            //and not yet started, reset LEDs
            if(secsRemaining <= SUNRISE_LENGTH + 60 && !inProgress )
            {
                resetColor();
                inProgress = true;
            }

            //If we are in sunrise, set appropriate color
            if(secsRemaining <= SUNRISE_LENGTH && inProgress)
            {
                //Determine temperature from time
                //These are magic numbers I played with until it looked nice
                float temp = pow( (float)(SUNRISE_LENGTH - secsRemaining) / SUNRISE_LENGTH, 2.0);
                temp *= (float)(SUNRISE_LENGTH - secsRemaining) * (4800.0 / SUNRISE_LENGTH);
                temp += 663.0;

                setColor(getBB(temp));
            }

            //If we are in the hold time, wait.
            if(secsRemaining > (24*3600 - HOLD_TIME)) continue;

            //Once we have finished hold time, turn off LEDs
            if(secsRemaining <= (24*3600 - HOLD_TIME) &&
               secsRemaining > SUNRISE_LENGTH + 60    &&
               inProgress)
            {
                resetColor();
                inProgress = false;
            }

            //Any other time do nothing
            else continue;
        }
    }
}





