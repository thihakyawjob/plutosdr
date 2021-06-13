%% OQPSK Transmitter with DeepLeaning with ADALM-PLUTO Radio
clear;
clc;
% Transmitter parameter structure
prm_OQPSKTransmitter = plutosdr_oqpsk_transmitter_init;
% Specify Radio ID
prm_OQPSKTransmitter.Address = 'usb:1'

runPlutosdr_OQPSKTransmitter(prm_OQPSKTransmitter);