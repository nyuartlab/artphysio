void serialEvent(Serial ardPort){
   String inData = ardPort.readStringUntil('\n');
   inData = trim(inData);                 // cut off white space (carriage return)
   
   if (inData.charAt(0) == 'S'){          // leading 'S' for sensor data
     inData = inData.substring(1);        // cut off the leading 'S'
     pulseVal = int(inData);                // convert the string to usable int
   }
   
}
