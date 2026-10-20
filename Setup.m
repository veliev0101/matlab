% Вариант 2: QPSK, R = 3/4, beta = 0.20, pilots = on 
Source.NumBitsPerFrame = 48408;     % K_bch для R = 3/4 (normal FECFRAME)
Encoder.isTransparent  = false;     % BCH + LDPC
Encoder.CodeRate       = '3/4';
Encoder.MaxNumIter     = 20;        % итераций LDPC-декодера
Interleaver.isTransparent = false;  % для QPSK перемежитель не применяется
Mapper.isTransparent   = false;
Mapper.Type            = 'PSK';
Mapper.ModulationOrder = 4;         % QPSK
Mapper.PhaseOffset     = pi/4;      % DVB-S2 QPSK: phi = pi/4
Mapper.SymbolMapping   = 'Gray';
PLFramer.isTransparent  = false;
PLFramer.FECFrame       = 'normal';
PLFramer.Pilots         = true;
PLFramer.ScramblingCode = 0;        % номер кода Голда n
Sig.isTransparent      = false;     % RRC-фильтр
Sig.RollOff            = 0.20;      % beta (как в MATYPE источника)
Sig.SamplesPerSymbol   = 4;
Sig.Span               = 10;        % Ta = 10T
Channel.isTransparent  = false;


% End of Params
