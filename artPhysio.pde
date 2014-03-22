/*artPhys_WithSerialTriggers.pde 03/22/13 
 Written by Ed Vessel & Claire Mitchell 
 Data collection and video recording for MATLAB Art Physio  'art_physio.m' & init_physio.m'
 
 Experiment for collecting data on image preference and emotional reaction to artwork. 
 
 MATLAB is used to present a set of artwork images to subjects
 Processing captures image sequences of the facial expressions of subjects, and to write physiological 
 and Matlab correlation data to a csv file
 Arduino is used to collect heart rate data from a Pulse Oximeter sensor
 CERT (Computer Expression Recognition Toolbox) is used to process image sequence of subject facial expression
 
 CERT data is then analyzed using MATLAB
 */

boolean matlabIn = true; // set to true if Matlab is connected
int mport = 4;
boolean arduinoIn = true; // set to true if Arduino is connected
int aport = 0;

//Import libraries
import processing.video.*;
import processing.serial.*;
import java.io.*;
import javax.imageio.*;
import java.util.concurrent.LinkedBlockingQueue;

//DECLARE SERIAL PORT FOR ARDUINO COMMUNICATION
Serial ardPort;  
int pulseVal;

//DECLARE SERIAL PORT FOR MATLAB COMMUNICATION
Serial matlabPort;  
int matlabVal; 

//DATA INIT VARIABLES
//int ssn = 1;
//int rnum = 7;
String ssn;
String rnum;

//LinkedList<PGraphics> theQueue;

//List<PGraphics> theQueue = Collections.synchronizedList(new LinkedList());
LinkedBlockingQueue<PGraphics> theQueue;


//VIDEO RECORDING
String homeDir = "/Users/vessel/EXPERIMENTS/art_physio/aplab/Data/";
String FolderName = "";
boolean recording = false;
Capture cam;
String vidFmt = ".tif";


float ratioWidth = 1;
float ratioHeight = 1;
float ratio = 1;

//SAVE DATA TO CSV
PrintWriter output;
PrintWriter output2;
OutputStream videoOutput;
boolean startDataCollect = false;

//TIME VARIABLES
long programTime = 0;
long startTime = 0;
long timeStamp = 0;
int timescale = 10000; //factor to divide by when writing out values

//DATA VARIABLES
int trialNumber = 0;
int next = 0;

//FAKE PULSE DATA FOR TESTING WITHOUT ARDUINO
int  fakePulseVal = 0;

int frameReadNumber = 1;
int frameWriteNumber = 1;
int time = 0;

//VIDEO SETUP
String camName = "Logitech Camera";
//String camName = "Built-in iSight";
//String camName =  "FaceTime HD Camera (Built-in)";
//int camWidth = 640;
//int camHeight = 480;
//int camWidth = 320;
//int camHeight = 240;
int camWidth = 480;
int camHeight = 270;//300;//270;
//int camWidth = 960;
//int camHeight = 540;
int fps = 30; //FrameRate

//EXTERNAL CANVAS
PGraphics canvas;

int canvas_width = camWidth;
int canvas_height = camHeight;

    float resizedWidth = canvas_width * ratio;
    float resizedHeight = canvas_height * ratio; 




saveEveryFrame sf;
boolean cleanup = false;


void setup() {
  //size(80, 45);
  size(camWidth, camHeight);
  frameRate(fps);

  //INITIALIZE CAMERA
  println("Initializing camera ..");
  String[] cameras = Capture.list();
  cam = new Capture(this, camWidth, camHeight, camName, fps);
  cam.start();
  canvas = createGraphics(canvas_width, canvas_height);

  println("Creating Queue ...");
  theQueue = new LinkedBlockingQueue();

  // workspace = createGraphics(camWidth, camHeight);
  // thisFrame = new PImage(camWidth,camHeight);

  //INITIALIZE SAVEFRAME
  println("Initializing saveframe ...");
  sf = new saveEveryFrame();   

  //ARDUINO SERIAL INITIALIZATION
  println("Initializing Arduino ...");
  if (arduinoIn) {
    String portName1 = Serial.list()[aport]; // MAKE SURE THIS IS THE CORRECT PORT
    ardPort = new Serial(this, portName1, 115200);
    ardPort.clear();            // flush buffer
    ardPort.bufferUntil('\n');  // set buffer full flag on receipt of carriage return
  } 
  else {
    pulseVal = 0;
  }

  //MATLAB PORT SERIAL INITIALIZATION
  println("Initializing Matlab serial port ...");
  if (matlabIn) {
    String portName2 = Serial.list()[mport];
    matlabPort = new Serial(this, portName2, 115200);
    matlabPort.clear();
  }
  
  println("Ready!");
  //TIME
  programTime = System.nanoTime();
  startTime = 0;
  timeStamp = 0;
}

synchronized void draw() {
  //TIME EQUALS TOTAL TIME MINUS START TIME
  timeStamp = System.nanoTime()-(startTime+programTime);
  //  println(timeStamp);
  
//  START READING CAMERA DATA
//  if (cam.available() == true) {
//    cam.read();
//  } 

  //MATLAB INIT STRING BUFFER
  byte[] inBuffer = new byte[4];

  //START READING MATLAB PC COMMANDS
  // MOVE THIS TO SERIAL EVENT!
  if (matlabIn) {
    matlabVal = matlabPort.read();         // read it and store it in val
  }
  //  if (matlabVal > -1) {  //IF INFORMATION COMES IN FROM MATLAB 
  //    // println("Skey= " + ((char)matlabVal));
  //    // println(matlabVal);
  //  }

  //IF RECEIVE 'I' FROM MATLAB: INITIALIZE FILE STRUCTURE WITH SUBJECT VARIABLES
  switch((char)matlabVal) {
  case 'i':
  case 'I':
    println('I');
    //READ INCOMING STRING 
    if (matlabIn) {
      inBuffer = matlabPort.readBytes();
      matlabPort.readBytes(inBuffer);
      if (inBuffer != null) {
        String initString = new String(inBuffer);
        ssn = initString.substring(0, 2); //SUBJECT NUMBER
        rnum = initString.substring(2); //RUN NUMBER
      }
    } 
    else {
      // When matlab port not connected
      ssn = "00";
      rnum = "1";
    }
    println("ssn = " + ssn); 
    println("rnum = " + rnum);
    String DataName = ssn + "_r" + rnum + "_aplab_art"; 
    FolderName = homeDir + DataName + "_ph"; 
    // println(FolderName);
    videoOutput = createOutput(FolderName + "/.dummy");

    output = createWriter(FolderName + "/" + DataName + "_ph.csv"); 
    output.println("PROGRAM START TIME, TRIAL NUMBER, PHYSIO DATA, VIDEO FRAME NUMBER, MATLAB COMMAND VAL, TRIAL TIME");
    output.flush();
    break;
  case 's':
  case 'S':    //IF RECEIVE 'S' FROM MATLAB KEYPRESS: START TIME, RECORDING VIDEO, & RECORDING DATA
    println('S');
    recording = true;
    sf.start(); //START SAVING FRAMES
    startDataCollect = true;
    saveStartTime();
    break;
  case 't':  
  case 'T':   //IF RECEIVE 'T' FROM MATLAB, START TRIAL AND TIMESTAMP
    trialNumber++;
    //    saveTimeStamp();
    saveStartTime();
    println('T');
    break;
  case 'e':
  case 'E':   //IF RECEIVE 'E' FROM MATLAB: END VIDEO AND STOP DATA RECORDING 
    recording = false;
    startDataCollect = false; 
    //   launch function for cleanup
    cleanup = true;
    println('E');
    break;
  }  // END SWITCH

  //UNCOMMENT TO READ HEART RATE FROM ARDUINO
  //println("pulse= " + pulseVal);

  // image(thisFrame, 0, 0);  //DISPLAY CAMERA IMAGE
  // set(thisFrame,0,0);

  
    //WRITE OUT DATA 
  if (startDataCollect == true) {
    output.println((startTime/timescale) + "," + trialNumber + "," + pulseVal + "," + frameReadNumber + "," + matlabVal +  "," + (timeStamp/timescale));
//    output.flush();
  }

  if (!matlabIn) {  //flush matlabVal when using keyboard
    matlabVal = -1;
  }
  
  if (recording ) {
    //saveVidFiles(FolderName);
    PGraphics canvas2;
    canvas2 = createGraphics(canvas_width, canvas_height); 
    //read camera create canvas, put image into canvas, que canvas into list - 
    canvas2.beginDraw();
    canvas2.image(cam, 0, 0);
    //canvas2.set(0,0,cam);
    canvas2.endDraw();
    float resizedWidth = (float) canvas2.width * ratio;
    float resizedHeight = (float) canvas2.height * ratio; 
    // image(canvas2, (width / 2) - (resizedWidth / 2), (height / 2) - (resizedHeight / 2), resizedWidth, resizedHeight);
    theQueue.add(canvas2);
    frameReadNumber++;
//  }
//  if (recording) {
//      cam.read();
//  canvas.beginDraw();
//  canvas.set( 0, 0, cam );
//  canvas.endDraw();
//    theQueue.add(canvas);
//        frameReadNumber++;
    //image(canvas, (width / 2) - (resizedWidth / 2), (height / 2) - (resizedHeight / 2), resizedWidth, resizedHeight);
  }
  
  //image(cam,0,0);
  
  if (cleanup) {
    if ( theQueue.isEmpty() == true) {
      println("finished writing images to disc");
      //sf.quit();
      cleanup = false;
    }
  }
  
}


//KEYPRESS FOR DEBUGGING WITHOUT MATLAB COMMUNICATION
void keyPressed() { 
  matlabVal = int(key);
}


//synchronized void captureEvent(Capture c) {
//  c.read();
//  canvas.beginDraw();
//  canvas.set( 0, 0, c );
//  canvas.endDraw();
//
////thisFrame = workspace.get();
////   thisFrame.copy(c,0,0,camWidth,camHeight,0,0,camWidth,camHeight);
//}



void saveStartTime() {
  startTime = System.nanoTime()-programTime;
}


//void saveTimeStamp() {
//  timeStamp = millis()-startTime;
//}


void calculateResizeRatio()
{
  ratioWidth = (float) width / (float) canvas.width;
  ratioHeight = (float) height / (float) canvas.height;

  if (ratioWidth < ratioHeight)  ratio = ratioWidth;
  else                          ratio = ratioHeight;
}

