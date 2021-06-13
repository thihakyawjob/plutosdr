function waveform = PHYGeneratorOQPSK( MPDU, varargin )
%PHYGENERATOROQPSK Transmit-side O-QPSK physical layer of 802.15.4
%   WAVEFORM = PHYGENERATOROQPSK( MPDU ) uses 16-ary offset QPSK
%   (O-QPSK) to generate the physical-layer waveform WAVEFORM corresponding
%   to the MAC protocol data unit MPDU. A synchronization header is added,
%   comprising a preamble and a "start-of-frame" delimiter. The frame
%   length is also encoded. The MPDU bits are spreaded to chips, which are
%   subsequently O-QPSK modulated and filtered.
%
%   See also LRWPAN.PHYDECODEROQPSK, LRWPAN.PHYDECODEROQPSKNOSYNC, LRWPAN.PHYGENERATORBPSK,
%   LRWPAN.PHYGENERATORASK, LRWPAN.PHYGENERATORGFSK

%   Copyright 2017 The MathWorks, Inc.

persistent rcosfilt % Persistent raised cosine filter, as one-time setup is the computational bottleneck

reservedValue = 0;

%% Validation
OSR = lrwpan.internal.generatorValidation(MPDU, nargin, varargin);

% frequency band specification
if nargin == 3
  band = validatestring(varargin{2},{'780 MHz', '868 MHz','915 MHz', '2450 MHz'},'','frequency band');
else
  band = '2450 MHz';
end

if strcmp(band, '2450 MHz')
  chipLen = 32;    
  % See Table 73 in IEEE 802.15.4,  2011 revision
  chipMap = ...
     [1 1 0 1 1 0 0 1 1 1 0 0 0 0 1 1 0 1 0 1 0 0 1 0 0 0 1 0 1 1 1 0;
      1 1 1 0 1 1 0 1 1 0 0 1 1 1 0 0 0 0 1 1 0 1 0 1 0 0 1 0 0 0 1 0;
      0 0 1 0 1 1 1 0 1 1 0 1 1 0 0 1 1 1 0 0 0 0 1 1 0 1 0 1 0 0 1 0;
      0 0 1 0 0 0 1 0 1 1 1 0 1 1 0 1 1 0 0 1 1 1 0 0 0 0 1 1 0 1 0 1;
      0 1 0 1 0 0 1 0 0 0 1 0 1 1 1 0 1 1 0 1 1 0 0 1 1 1 0 0 0 0 1 1;
      0 0 1 1 0 1 0 1 0 0 1 0 0 0 1 0 1 1 1 0 1 1 0 1 1 0 0 1 1 1 0 0;
      1 1 0 0 0 0 1 1 0 1 0 1 0 0 1 0 0 0 1 0 1 1 1 0 1 1 0 1 1 0 0 1;
      1 0 0 1 1 1 0 0 0 0 1 1 0 1 0 1 0 0 1 0 0 0 1 0 1 1 1 0 1 1 0 1;
      1 0 0 0 1 1 0 0 1 0 0 1 0 1 1 0 0 0 0 0 0 1 1 1 0 1 1 1 1 0 1 1;
      1 0 1 1 1 0 0 0 1 1 0 0 1 0 0 1 0 1 1 0 0 0 0 0 0 1 1 1 0 1 1 1;
      0 1 1 1 1 0 1 1 1 0 0 0 1 1 0 0 1 0 0 1 0 1 1 0 0 0 0 0 0 1 1 1;
      0 1 1 1 0 1 1 1 1 0 1 1 1 0 0 0 1 1 0 0 1 0 0 1 0 1 1 0 0 0 0 0;
      0 0 0 0 0 1 1 1 0 1 1 1 1 0 1 1 1 0 0 0 1 1 0 0 1 0 0 1 0 1 1 0;
      0 1 1 0 0 0 0 0 0 1 1 1 0 1 1 1 1 0 1 1 1 0 0 0 1 1 0 0 1 0 0 1;
      1 0 0 1 0 1 1 0 0 0 0 0 0 1 1 1 0 1 1 1 1 0 1 1 1 0 0 0 1 1 0 0;
      1 1 0 0 1 0 0 1 0 1 1 0 0 0 0 0 0 1 1 1 0 1 1 1 1 0 1 1 1 0 0 0];
else
  chipLen = 16;
  % See Table 74 in IEEE 802.15.4,  2011 revision
  chipMap =  [0 0 1 1 1 1 1 0 0 0 1 0 0 1 0 1;
              0 1 0 0 1 1 1 1 1 0 0 0 1 0 0 1;
              0 1 0 1 0 0 1 1 1 1 1 0 0 0 1 0;
              1 0 0 1 0 1 0 0 1 1 1 1 1 0 0 0;
              0 0 1 0 0 1 0 1 0 0 1 1 1 1 1 0;
              1 0 0 0 1 0 0 1 0 1 0 0 1 1 1 1;
              1 1 1 0 0 0 1 0 0 1 0 1 0 0 1 1;
              1 1 1 1 1 0 0 0 1 0 0 1 0 1 0 0;
              0 1 1 0 1 0 1 1 0 1 1 1 0 0 0 0;
              0 0 0 1 1 0 1 0 1 1 0 1 1 1 0 0;
              0 0 0 0 0 1 1 0 1 0 1 1 0 1 1 1;
              1 1 0 0 0 0 0 1 1 0 1 0 1 1 0 1;
              0 1 1 1 0 0 0 0 0 1 1 0 1 0 1 1;
              1 1 0 1 1 1 0 0 0 0 0 1 1 0 1 0;
              1 0 1 1 0 1 1 1 0 0 0 0 0 1 1 0;
              1 0 1 0 1 1 0 1 1 1 0 0 0 0 0 1];
end


%% Synchronization header (SHR)

% Preamble is 4 octets, all set to 0.
preamble = zeros(4*8, 1);

% Start-of-frame delimiter (SFD)
SFD = [1 1 1 0 0 1 0 1]'; % value from standard (see Fig. 68, IEEE 802.15.4, 2011 Revision)

SHR = [preamble; SFD];

%% PHY Header (PHR)
frameLength = de2bi(length(MPDU)/8, 7);
PHR = [frameLength'; reservedValue];

%% PHY protocol data unit:
PPDU = [SHR; PHR; MPDU];

% pre-allocate matrix for performance
chips = zeros(chipLen, length(PPDU)/4);
for idx = 1:length(PPDU)/4
  %% Bit to symbol mapping
  currBits = PPDU(1+(idx-1)*4 : idx*4);
  symbol = bi2de(currBits');
  
  %% Symbol to chip mapping                            
	chips(:, idx) = chipMap(1+symbol, :)'; % +1 for 1-based indexing
end

%% O-QPSK modululation (part 1)
% split two 2 parallel streams, also map [0, 1] to [-1, 1]
oddChips  = chips(1:2:end)*2-1;
evenChips = chips(2:2:end)*2-1;


%% Filtering

% Filtering from standard (see Sec. 10.2.6, IEEE 802.15.4, 2011 Revision)
if strcmp(band, '780 MHz')
  
  % Raised cosine pulse filtering
  if isempty(rcosfilt)
    rcosfilt = comm.RaisedCosineTransmitFilter('RolloffFactor', 0.8, ...
                  'OutputSamplesPerSymbol', OSR, 'Shape', 'Normal');
                
  elseif rcosfilt.OutputSamplesPerSymbol ~= OSR
    release(rcosfilt);
    rcosfilt.OutputSamplesPerSymbol = OSR;
  end
  filtered = rcosfilt(oddChips' + 1i*evenChips');
  filteredReal = real(filtered);
  filteredImag = imag(filtered);
  reset(rcosfilt); % reset persistent variable
  
else % '2.4 GHz', '868 MHz','915 MHz'
  
  % Half-sine pulse filtering for 868 MHz, 915 MHz, 2450 MHz
  pulse = sin(0:pi/OSR:(OSR-1)*pi/OSR); % Half-period sine wave
  filteredReal = pulse' * oddChips;     % each column is now a filtered pulse
  filteredImag = pulse' * evenChips;    % each column is now a filtered pulse  
end

%% O-QPSK modululation (part 2)
re = [filteredReal(:);         zeros(round(OSR/2), 1)];
im = [zeros(round(OSR/2), 1);  filteredImag(:)];
waveform = complex(re, im);
