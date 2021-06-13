function SimParams = plutosdr_oqpsk_Receiver_init
%   Copyright 2017 The MathWorks, Inc.

%% General simulation parameters
%% General simulation parameters
SimParams.Rsym = 12e6;             % Symbol rate in Hertz
SimParams.spc =   12;              % OQPSK Sample per chip
SimParams.Interpolation = 2;        % Interpolation factor
SimParams.Decimation = 3;           % Decimation factor
SimParams.Tsym = 1/SimParams.Rsym;  % Symbol time in sec
SimParams.Fs   = SimParams.Rsym /SimParams.spc; % Sample per sec

%% Frame Specifications
% [BarkerCode*2 | 'Hello world 000\n' | 'Hello world 001\n' ...];

SimParams.Message         = 'Hello world';
SimParams.MessageLength   = length(SimParams.Message) + 5;                % 'Hello world 000\n'...
SimParams.FrameSize       = 48390*3;                                    % Frame size in symbols
SimParams.FrameTime       = SimParams.FrameSize/SimParams.Fs;



%% Rx parameters
SimParams.RolloffFactor     = 0.5;                      % Rolloff Factor of Raised Cosine Filter
SimParams.ScramblerBase     = 2;
SimParams.ScramblerPolynomial           = [1 1 1 0 1];
SimParams.ScramblerInitialConditions    = [0 0 0 0];
SimParams.RaisedCosineFilterSpan = 10;                  % Filter span of Raised Cosine Tx Rx filters (in symbols)
SimParams.DesiredPower                  = 2;            % AGC desired output power (in watts)
SimParams.AveragingLength               = 50;           % AGC averaging length
SimParams.MaxPowerGain                  = 60;           % AGC maximum output power gain
SimParams.MaximumFrequencyOffset        = 6e3;
% Look into model for details for details of PLL parameter choice. 
% Refer equation 7.30 of "Digital Communications - A Discrete-Time Approach" by Michael Rice.
K = 1;
A = 1/sqrt(2);
SimParams.PhaseRecoveryLoopBandwidth    = 0.01;         % Normalized loop bandwidth for fine frequency compensation
SimParams.PhaseRecoveryDampingFactor    = 1;            % Damping Factor for fine frequency compensation
SimParams.TimingRecoveryLoopBandwidth   = 0.01;         % Normalized loop bandwidth for timing recovery
SimParams.TimingRecoveryDampingFactor   = 1;            % Damping Factor for timing recovery
% K_p for Timing Recovery PLL, determined by 2KA^2*2.7 (for binary PAM),
% QPSK could be treated as two individual binary PAM,
% 2.7 is for raised cosine filter with roll-off factor 0.5
SimParams.TimingErrorDetectorGain       = 2.7*2*K*A^2+2.7*2*K*A^2;
SimParams.PreambleDetectorThreshold     = 0.8;

%% Message generation and BER calculation parameters
msgSet = zeros(8 * SimParams.MessageLength, 1); 
for msgCnt = 0 : 8
    msgSet(msgCnt * SimParams.MessageLength + (1 : SimParams.MessageLength)) = ...
        sprintf('%s %03d\n', SimParams.Message, msgCnt);
end
bits = de2bi(msgSet, 7, 'left-msb')';
SimParams.MessageBits = (bits(1:960)'); % Just to Fit into 802.15.4 system

% For BER calculation masks
% SimParams.BerMask = zeros(SimParams.NumberOfMessage * length(SimParams.Message) * 7, 1);
% for i = 1 : SimParams.NumberOfMessage
%     SimParams.BerMask( (i-1) * length(SimParams.Message) * 7 + ( 1: length(SimParams.Message) * 7) ) = ...
%         (i-1) * SimParams.MessageLength * 7 + (1: length(SimParams.Message) * 7);
% end
% Pluto receiver parameters
SimParams.PlutoCenterFrequency      = 2450e6;
SimParams.PlutoGain                 = 30;
SimParams.PlutoFrontEndSampleRate   = SimParams.Fs;
SimParams.PlutoFrameLength          = SimParams.FrameSize;

% Experiment parameters
SimParams.PlutoFrameTime = SimParams.PlutoFrameLength / SimParams.PlutoFrontEndSampleRate;
SimParams.StopTime = 10;
