function BER = runPlutoradio_OQPSKReceiver(prm_OQPSKReceiver, printData)

%   Copyright 2017 The MathWorks, Inc.

persistent  radio;

% Create and configure the Pluto System object.
radio = sdrrx('Pluto');
radio.RadioID               = prm_OQPSKReceiver.Address;
radio.CenterFrequency       = prm_OQPSKReceiver.PlutoCenterFrequency;
radio.BasebandSampleRate    = prm_OQPSKReceiver.PlutoFrontEndSampleRate;
radio.SamplesPerFrame       = prm_OQPSKReceiver.PlutoFrameLength;
radio.GainSource            = 'Manual';
radio.Gain                  = prm_OQPSKReceiver.PlutoGain;
radio.OutputDataType        = 'double';
radio.FrequencyCorrection   = 0;


% Initialize variables
currentTime = 0;
BER = 0;


while currentTime <  prm_OQPSKReceiver.StopTime
    % Receive signal from the radio
    rcvdSignal = radio();
    
    % Decode the received message
    OQPSK_Receiver(rcvdSignal, prm_OQPSKReceiver);
    
    % Update simulation time
    currentTime=currentTime+(radio.SamplesPerFrame / radio.BasebandSampleRate);
end

release(radio);
