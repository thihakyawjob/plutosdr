function runPlutosdr_OQPSKTransmitter(prmOQPSKTransmitter)
%#codegen

%   Copyright 2017 The MathWorks, Inc.

persistent radio
    
    data = PHYGeneratorOQPSK(prmOQPSKTransmitter.MessageBits, prmOQPSKTransmitter.spc, '2450 MHz');
  
    % Create and configure the Pluto System object.
    radio = sdrtx('Pluto');
    radio.RadioID               = prmOQPSKTransmitter.Address;
    radio.CenterFrequency       = prmOQPSKTransmitter.PlutoCenterFrequency;
    radio.BasebandSampleRate    = prmOQPSKTransmitter.PlutoFrontEndSampleRate;
    radio.SamplesPerFrame       = prmOQPSKTransmitter.PlutoFrameLength;
    radio.Gain                  = prmOQPSKTransmitter.PlutoGain;

currentTime = 0;
disp('Transmission has started')
    
    % Transmission Process
while currentTime < prmOQPSKTransmitter.StopTime

    % Data transmission
    step(radio, data);
    pause(0.01);

    % Update simulation time
    currentTime = currentTime+prmOQPSKTransmitter.FrameTime;
end

if currentTime ~= 0
    disp('Transmission has ended')
end    

release(radio);

end
