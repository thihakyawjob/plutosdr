%% PLUTOSDR Receiver Init
function MPDU = OQPSK_Receiver(capturedFrame1, prm_OQPSKReceiver)


%% Receiver Architecture
% Overall, the receiver performs the following operations:
%
% * Matched filtering
% * Coarse frequency compensation
% * Fine frequency compensation
% * Timing Recovery
% * Preamble detection
% * Phase ambiguity resolution
% * Despreading 
%
% Between these steps, the signal is visualized to illustrate the signal
% impairments and the corrections.

%% Matched Filtering

spc = 12;  % 12 samples per chip; the frame was captured at 12 x chiprate = 12 MHz
%% Automatic GameControl
pAGC = comm.AGC( ...
                'DesiredOutputPower',       1, ...
                'AveragingLength',          50, ...
                'MaxPowerGain',             30);
            
AGCSignal = pAGC(capturedFrame1);

%%
% A matched filter improves the SNR of the signal. The 2.4 GHz OQPSK PHY
% uses half-sine pulses, therefore the following matched filtering
% operation is needed.

% Matched filter for captured OQPSK signal:
halfSinePulse = sin(0:pi/spc:(spc)*pi/spc);
decimationFactor = 3; % reduce spc to 4, for faster processing
matchedFilter = dsp.FIRDecimator(decimationFactor, halfSinePulse);
filteredOQPSK = matchedFilter(AGCSignal); % matched filter output

%% Frequency Offsets
% However, the samples of the captured frame are dislocated from this
% 'X'-shaped region due to frequency offsets:

% Plot constellation of QPSK-equivalent (impaired) received signal
% filteredQPSK = complex(real(filteredOQPSK(1:end-spc/(2*decimationFactor))), imag(filteredOQPSK(spc/(2*decimationFactor)+1:end))); % align I and Q
constellation = comm.ConstellationDiagram('XLimits', [-7.5 7.5], 'YLimits', [-7.5 7.5], ...
                                          'ReferenceConstellation', 5*qammod(0:3, 4), 'Name', 'Received QPSK-Equivalent Signal');
constellation.Position = [constellation.Position(1:2) 300 300]; 
% constellation(filteredQPSK);

%# Coarse frequency compensation of OQPSK signal
coarseFrequencyCompensator = comm.CoarseFrequencyCompensator('Modulation', 'OQPSK', ...
      'SampleRate', spc*1e6/decimationFactor, 'FrequencyResolution', 1e3);
[coarseCompensatedOQPSK, coarseFrequencyOffset] = coarseFrequencyCompensator(filteredOQPSK);
fprintf('Estimated frequency offset = %.3f kHz\n', coarseFrequencyOffset/1000);

% coarseCompensatedQPSK = complex(real(coarseCompensatedOQPSK(1:end-spc/(2*decimationFactor))), imag(coarseCompensatedOQPSK(spc/(2*decimationFactor)+1:end))); % align I and Q
% release(constellation);
% constellation.Name = 'Coarse frequency compensation (QPSK-Equivalent)';
% constellation(coarseCompensatedQPSK);

%% Fine frequency compensation of OQPSK signal
fineFrequencyCompensator = comm.CarrierSynchronizer('Modulation', 'OQPSK', 'SamplesPerSymbol', spc/decimationFactor);
fineCompensatedOQPSK = fineFrequencyCompensator(coarseCompensatedOQPSK);

% Plot QPSK-equivalent finely compensated signal
% fineCompensatedQPSK = complex(real(fineCompensatedOQPSK(1:end-spc/(2*decimationFactor))), imag(fineCompensatedOQPSK(spc/(2*decimationFactor)+1:end))); % align I and Q
% release(constellation);
% constellation.Name = 'Fine frequency compensation (QPSK-Equivalent)';
% constellation(fineCompensatedQPSK);

%% Timing Recovery
% Symbol synchronization occurs according to the OQPSK timing-recovery
% algorithm described in [ <#16 3> ]. In contrast to carrier recovery, the
% OQPSK timing recovery algorithm is equivalent to its QPSK counterpart for
% QPSK-equivalent signals that are obtained by delaying the in-phase
% component of the OQPSK signal by half a symbol.

% Timing recovery of OQPSK signal, via its QPSK-equivalent version
symbolSynchronizer = comm.SymbolSynchronizer('Modulation', 'OQPSK', 'SamplesPerSymbol', spc/decimationFactor);
syncedQPSK = symbolSynchronizer(fineCompensatedOQPSK);

% Plot QPSK symbols (1 sample per chip)
% release(constellation);
% constellation.Name = 'Timing Recovery (QPSK-Equivalent)';
% constellation(syncedQPSK);

%% Preamble Detection, Despreading and Phase Ambiguity Resolution:
% Once the signal has been synchronized, the next step is preamble
% detection, which is more successful if the signal has been despreaded. It
% is worth noting that fine frequency compensation results in a
% $\pi$/2-phase ambiguity, indicating the true constellation may have been
% rotated by 0, $\pi$/2, $\pi$, or $3\pi$/2 radians. Preamble detection
% resolves the phase ambiguity by considering all four possible
% constellation rotations. The next function operates on the synchronized
% OQPSK signal, performs joint despreading, resolution of phase ambiguity
% and preamble detection, and then outputs the MAC protocol data unit
% (MPDU).
MPDU = PHYDecoderOQPSKAfterSync(syncedQPSK);

if(length(MPDU) > 959)
    charSet = int8(bi2de(reshape(MPDU(1:959), 7, [])', 'left-msb'));
    fprintf('%s\n', char(charSet));
    
    [~, BER] = biterr(prm_OQPSKReceiver.MessageBits, MPDU);
    BER
end

%% Generate Transmit message




