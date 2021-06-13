function SimParams = plutosdr_oqpsk_transmitter_init
%   Copyright 2017 The MathWorks, Inc.

%% General simulation parameters
SimParams.Rsym = 12e6;             % Symbol rate in Hertz
SimParams.spc =   12;              % OQPSK Sample per chip
SimParams.Interpolation = 2;        % Interpolation factor
SimParams.Decimation = 3;           % Decimation factor
SimParams.Tsym = 1/SimParams.Rsym;  % Symbol time in sec
SimParams.Fs   = SimParams.Rsym / SimParams.spc; % Sample per sec

%% Frame Specifications
% [BarkerCode*2 | 'Hello world 000\n' | 'Hello world 001\n' ...];

SimParams.Message         = 'Hello world';
SimParams.MessageLength   = length(SimParams.Message) + 5;                % 'Hello world 000\n'...
SimParams.FrameSize       = 48390;                                    % Frame size in symbols
SimParams.FrameTime       = SimParams.FrameSize/SimParams.Fs;         % 48390 * 1us


%% Message generation
msgSet = zeros(8 * SimParams.MessageLength, 1); 
for msgCnt = 0 : 8
    msgSet(msgCnt * SimParams.MessageLength + (1 : SimParams.MessageLength)) = ...
        sprintf('%s %03d\n', SimParams.Message, msgCnt);
end
bits = de2bi(msgSet, 7, 'left-msb')';
SimParams.MessageBits = (bits(1:960)'); % Just to Fit into 802.15.4 system

% Pluto transmitter parameters
SimParams.PlutoCenterFrequency      = 2450e6;
SimParams.PlutoGain                 = 0;
SimParams.PlutoFrontEndSampleRate   = SimParams.Fs;
SimParams.PlutoFrameLength          = SimParams.FrameSize;

% Simulation Parameters
SimParams.FrameTime = SimParams.PlutoFrameLength/SimParams.PlutoFrontEndSampleRate;
SimParams.StopTime  = 100;
