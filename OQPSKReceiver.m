%% PLUTOSDR Receiver Init
function MPDU = OQPSKReceiver(capturedFrame1)


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
%load lrwpanPHYCaptures % load OQPSK signals captured in the 2.4 GHz band
spc = 12;  % 12 samples per chip; the frame was captured at 12 x chiprate = 12 MHz


%%
% A matched filter improves the SNR of the signal. The 2.4 GHz OQPSK PHY
% uses half-sine pulses, therefore the following matched filtering
% operation is needed.

% Matched filter for captured OQPSK signal:
halfSinePulse = sin(0:pi/spc:(spc)*pi/spc);
decimationFactor = 3; % reduce spc to 4, for faster processing
matchedFilter = dsp.FIRDecimator(decimationFactor, halfSinePulse);
filteredOQPSK = matchedFilter(capturedFrame1); % matched filter output

%% Frequency Offsets
% Decoding a signal under the presence of frequency offsets is a challenge
% for any wireless receiver. Frequency offsets up to 30 kHz were measured
% for signals transmitted from commercial ZigBee radios and captured using a
% USRP(R) B200-mini radio.
%
% Constellation diagrams can illustrate the quality of the received signal,
% but it is first important to note that the trajectory of an ideal OQPSK
% signal follows a circle.

%%
% However, the samples of the captured frame are dislocated from this
% 'X'-shaped region due to frequency offsets:

% Plot constellation of QPSK-equivalent (impaired) received signal
%filteredQPSK = complex(real(filteredOQPSK(1:end-spc/(2*decimationFactor))), imag(filteredOQPSK(spc/(2*decimationFactor)+1:end))); % align I and Q
% constellation = comm.ConstellationDiagram('XLimits', [-7.5 7.5], 'YLimits', [-7.5 7.5], ...
%                                           'ReferenceConstellation', 5*qammod(0:3, 4), 'Name', 'Received QPSK-Equivalent Signal');
% constellation.Position = [constellation.Position(1:2) 300 300]; 
% constellation(filteredQPSK);

%% Coarse Frequency Compensation
% Such frequency offsets are first coarsely corrected using an FFT-based
% method [ <#16 2> ] that squares the OQPSK signal and reveals two spectral
% peaks. The coarse frequency offset is obtained by averaging and halving
% the frequencies of the two spectral peaks.

% Coarse frequency compensation of OQPSK signal
coarseFrequencyCompensator = comm.CoarseFrequencyCompensator('Modulation', 'OQPSK', ...
      'SampleRate', spc*1e6/decimationFactor, 'FrequencyResolution', 1e3);
[coarseCompensatedOQPSK, coarseFrequencyOffset] = coarseFrequencyCompensator(filteredOQPSK);
fprintf('Estimated frequency offset = %.3f kHz\n', coarseFrequencyOffset/1000);

% Plot QPSK-equivalent coarsely compensated signal
%coarseCompensatedQPSK = complex(real(coarseCompensatedOQPSK(1:end-spc/(2*decimationFactor))), imag(coarseCompensatedOQPSK(spc/(2*decimationFactor)+1:end))); % align I and Q
% release(constellation);
% constellation.Name = 'Coarse frequency compensation (QPSK-Equivalent)';
% constellation(coarseCompensatedQPSK);

%%
% Some samples still lie outside the 'X'-shaped region connecting the
% origin with the QPSK symbols (red crosses), as fine frequency
% compensation is also needed.
%

%% Fine Frequency Compensation
% Fine frequency compensation follows the *OQPSK carrier-recovery
% algorithm* described in [ <#16 3> ]. This algorithm is behaviorally
% different than its QPSK counterpart, which does not apply to OQPSK
% signals even if their in-phase signal component is delayed by half a
% symbol.

% Fine frequency compensation of OQPSK signal
fineFrequencyCompensator = comm.CarrierSynchronizer('Modulation', 'OQPSK', 'SamplesPerSymbol', spc/decimationFactor);
fineCompensatedOQPSK = fineFrequencyCompensator(coarseCompensatedOQPSK);

% Plot QPSK-equivalent finely compensated signal
%fineCompensatedQPSK = complex(real(fineCompensatedOQPSK(1:end-spc/(2*decimationFactor))), imag(fineCompensatedOQPSK(spc/(2*decimationFactor)+1:end))); % align I and Q
% release(constellation);
% constellation.Name = 'Fine frequency compensation (QPSK-Equivalent)';
% constellation(fineCompensatedQPSK);

%%
% The constellation is now closer to its ideal form, but still timing
% recovery is needed.

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
%release(constellation);
% constellation.Name = 'Timing Recovery (QPSK-Equivalent)';
% constellation(syncedQPSK);

%%
% Note that the output of the Symbol Synchronizer contains one sample per
% symbol. At this stage, the constellation truly resembles a QPSK signal.
% The few symbols that gradually move away from the origin correspond to
% the frame start and end.

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
%length(syncedQPSK)
MPDU = PHYDecoderOQPSKAfterSync(syncedQPSK);