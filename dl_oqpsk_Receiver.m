%% OQPSK Receiver with DeepLeaning with ADALM-PLUTO Radio

clear;
clc;

% Receiver parameter structure
prm_OQPSKReceiver = plutosdr_oqpsk_Receiver_init;

% Specify Radio ID
prm_OQPSKReceiver.Address = 'usb:0'

printReceivedData = true;    % true if the received data is to be printed

BER = runPlutoradio_OQPSKReceiver(prm_OQPSKReceiver, printReceivedData); 

