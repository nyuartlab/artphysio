class saveEveryFrame extends Thread {

  boolean running;

  public saveEveryFrame () {
    running = false;
  }

  public void start() {
    running = true;

    try {
      super.start();
    }
    catch(java.lang.IllegalThreadStateException itse) {
      //println("cannot execute! ->"+itse);
    }
  }

  public void run() {
    while (running) {
      PGraphics tmp = null;
      try {
        tmp = theQueue.take();
      }
      catch(java.lang.InterruptedException hello) {
        println("FRAMEWRITE ERROR: " + frameWriteNumber);
      }
      tmp.save(FolderName + "/video/" + camWidth + "_" + time + "_" + trialNumber + "_" + frameWriteNumber + vidFmt);
      frameWriteNumber++;
      tmp = null;
 
    }
  }

  public void quit() {
    running = false;  
    interrupt();
  }
}

