function MPDU = PHYDecoderOQPSKAfterSync( synchronized, varargin )
%PHYDECODERSYNCEDOQPSK Receive-side physical layer for synchronized OQPSK signals
%   MPDU = PHYDECODERSYNCEDOQPSK( SYNCHRONIZED ) accepts the QPSK
%   symbols SYNCHRONIZED that have been passed to a matched filter, a coarse
%   frequency compensator, a fine frequency compensator and a symbol
%   synchronizer. Then it performs preamble detection, despreading and
%   symbol to bit mapping.

%   Copyright 2017 The MathWorks, Inc. 

%% Validation

% frequency band specification
if nargin >= 2
  band = validatestring(varargin{1},{'780MHz', '868MHz','915MHz', '2450MHz'},'','frequency band');
else
  band = '2450MHz';
end
chipLen = 16;
if strcmp(band, '2450MHz')
  chipLen = 32;
	chipMap = flipud(...
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
       1 1 0 0 1 0 0 1 0 1 1 0 0 0 0 0 0 1 1 1 0 1 1 1 1 0 1 1 1 0 0 0]);
     % flipud as min returns first found element, so avoid false preamble
     % detection for purely random data
else
  chipMap   = flipud([0 0 1 1 1 1 1 0 0 0 1 0 0 1 0 1;
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
                      1 0 1 0 1 1 0 1 1 1 0 0 0 0 0 1]);
end

%% Resolve phase ambiguity caused by fine frequency compensation
for phase = 0:pi/2:3*pi/2
  rotated = synchronized*exp(1i*phase);
  
  %% O-QPSK demodululation
  temp = [transpose(real(rotated (1:end))); transpose(imag(rotated (1:end)))];
  demodulated = temp(:) > 0; % Slicing, convert [-1 1] to [0 1]

  %% Preamble detection
  % Exhaustive sliding window for detection of first preamble
  for preambleStart = 1:(length(demodulated)-8*chipLen+1)
    % The preamble is 32 (despreaded) zeros. This is 8 symbols (4 octets),
    % which corresponds to 8*chipLen spreaded bits.
    preambleFound = true;  

    for chipNo = 1:8 % each chip should give symbol 0, which is 4 zero bits

      thisChip = demodulated(preambleStart + (chipNo-1)*chipLen : preambleStart-1+chipNo*chipLen);
      symbol = despread(thisChip, chipMap);
      if symbol ~= 0
        % preamble detection failed
        preambleFound = false;
        break; % break from detecting pramble at this start index
      end
    end
    if preambleFound % All 8 chips map to symbol 0, preamble found

      break; % break from considering other preamble start indices
    end
  end
  
  % if preamble was found do not try remaining rotations
  if preambleFound
    break;  % break from resolution of phase ambiguity
  end
end

% Preamble detection results:
if ~preambleFound
  MPDU = [];
  return;
end
fprintf('Found preamble of OQPSK PHY.\n');
preambleStart
%% Start-of-frame delimiter (SFD) detection
SFD = [1 1 1 0 0 1 0 1];
% SFD is 2 symbols, i.e., 2 chip sequences
sfdStart = preambleStart + 4*8*8;
% 1st chip sequence
thisChip1 = demodulated(sfdStart : sfdStart -1+chipLen);
symbol1 = despread(thisChip1, chipMap);
% 2nd chip sequence
thisChip2 = demodulated(sfdStart  + chipLen : sfdStart-1 + 2*chipLen);
symbol2 = despread(thisChip2, chipMap);
if ~isequal(SFD, [de2bi(symbol1, 4) de2bi(symbol2, 4)])
  MPDU = [];
  return;
end
fprintf('Found start-of-frame delimiter (SFD) of OQPSK PHY.\n');

%% PHY Header (PHR)
preambleLen = 4*8;  % 4 octets
SFDLen = 8;         % 1 octet
PHRLen = 8;         % 1 octet
offset = preambleLen + SFDLen + PHRLen;

phrStart = preambleStart + 2*chipLen*(preambleLen+SFDLen)/8;
phrChips = demodulated(phrStart : phrStart+2*chipLen-1);
symbolA = despread(phrChips(1:chipLen),     chipMap);
symbolB = despread(phrChips(chipLen+1:end), chipMap);

% PHR contains the MPDU length
PHR = [de2bi(symbolA, 4) de2bi(symbolB, 4)];
frameLen = bi2de(PHR(1:7)); % number of octets

%frameLen = 42;
if ((frameLen*8)*chipLen/4) > (length(demodulated) - preambleStart) 
  fprintf('EMPTY MPDU.\n');
    MPDU = [];
  return;
end

%% Despreading
bits = zeros(4, frameLen*8/4);

%receivedMsg = zeros(((frameLen*8/4)+12)*32,1);
%receivedMsg(1:end, 1) = demodulated(preambleStart:(preambleStart+length(receivedMsg)-1),1);

for chipNo = 1:frameLen*8/4
  
  %% Chip to symbol mapping
  thisChip = demodulated(preambleStart+offset*chipLen/4+(chipNo-1)*chipLen:preambleStart-1+offset*chipLen/4+chipNo * chipLen);

  % find the chip sequence that looks the most like the received (minimum number of bit errors)
  symbol = despread(thisChip, chipMap);

  %% Symbol to bit mapping
  bits(:, chipNo) = de2bi(symbol, 4);
end
  
% Output despreaded bits
MPDU = bits(:);
fprintf('Found MPDU.\n');

end 

function symbol = despread(chip, chipMap)
  % Find the closest chip sequence
  [~, symbol] = min(sum(xor(chip', chipMap), 2));
  % substract from size to cancel flupud:
  symbol = size(chipMap, 1) - symbol; % result follows 0-based indexing
  %symbol = symbol - 1;
end