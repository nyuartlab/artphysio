 function [serial_handle,skey] = init_physio(terminator,ssn,runnum)

% Initialize COM1 Serial port for use with Processing
% for collection of camera data and physiological monitoring
% 
% terminator   1 to print terminator character (newline), 0 to not print
%
% written: 2012-07-29 by Ed Vessel
%
% Revision History:
%   2012-07-29  ev  created

%% set up keys
skey.init = 'I'; %initialize data collection
skey.start = 'S'; %start data collection
skey.trial = 'T'; %trial start
skey.next = 'N'; %subj presses 'next' image
skey.to = 'O'; %trial timed out
skey.end = 'E'; %end data collection

%% initialize port
if terminator
    serial_handle = serial('COM1','BaudRate',115200);
else
    serial_handle = serial('COM1','BaudRate',115200,'BytesAvailableFcnMode','byte','Terminator',[]); %doesn't print terminator
end

%% open port
 fopen(serial_handle);
 
 %% initialize Processing program with data file info (subj #, run #)
 ssn = 5;
 runnum = 1;
 
  init_string(1) = skey.init;
 if ssn < 10
    init_string(2) = '0';
    init_string(3) = int2str(ssn);
 else
     init_string(2:3) = int2str(ssn);
 end
 %init_string(4) = '_';
 init_string(4) = int2str(runnum);
 
 fprintf(serial_handle,init_string);
 
