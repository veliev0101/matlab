% === Вариант 2: QPSK, R = 3/4, beta = 0.20, pilots = on ===
Source.NumBitsPerFrame = 48600;     % K_bch
Mapper.isTransparent   = false;
Mapper.Type            = 'PSK';
Mapper.ModulationOrder = 4;         % QPSK
Mapper.PhaseOffset     = pi/4;      % DVB-S2 QPSK: phi = pi/4
Mapper.SymbolMapping   = 'Gray';
Channel.isTransparent  = false;
Encoder.isTransparent  = true;
Interleaver.isTransparent = true;
Sig.isTransparent      = true;
BER.BERNumRateDigits   = 8;
BER.FERNumRateDigits   = 5;
BER.BERPrecision       = 5;

% End of Params