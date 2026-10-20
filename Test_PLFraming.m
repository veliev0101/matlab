% Test_PLFraming.m - проверка пунктов 6-9 для команды 2 (QPSK, 3/4, pilots on)
clear; clc;
Params.Mapper   = struct('ModulationOrder', 4);
Params.PLFramer = struct('isTransparent', false, 'CodeRate', '3/4', ...
    'FECFrame', 'normal', 'Pilots', true, 'ScramblingCode', 0);
PL = ClassPLFramer(Params, 'Russian');

rng(1);
bits = randi([0 1], 64800, 1);                                  % FECFRAME
X = ((1-2*bits(1:2:end)) + 1j*(1-2*bits(2:2:end))) / sqrt(2);   % QPSK DVB-S2
Tx = PL.StepTx(X);
I  = PL.LastInfo;

% 6) PLHEADER
assert(length(Tx) == 33282, 'Длина PLFRAME должна быть 33282');
assert(isequal(I.SOFBits(:).', bitget(hex2dec('18D2E82'), 26:-1:1)), 'SOF');
assert(isequal(Tx(1:90), I.PLHEADER), 'PLHEADER не должен скремблироваться');
assert(all(abs(abs(I.PLHEADER) - 1) < 1e-12), 'PLHEADER: единичная окружность');
assert(isequal(I.PLSBits7, [0 0 1 1 1 0 1]), 'PLS = MODCOD 7, normal, pilots');

% 7) слоты
assert(isequal(size(I.Slots), [90 360]), '360 слотов по 90 символов');

% 8) пилоты
assert(nnz(PL.PilotMask) == 22*36, '22 пилот-блока по 36 символов');
assert(all(abs(I.Body(16*90 + (1:36)) - (1+1j)/sqrt(2)) < 1e-12), 'Первый пилот-блок');
assert(~PL.PilotMask(end), 'После последнего слота пилотов нет');

% 9) скремблирование: модуль не меняется, множители из {1,j,-1,-j}
assert(all(abs(abs(Tx(91:end)) - abs(I.Body)) < 1e-12), 'Модуль после скремблирования');
assert(all(ismember(round(PL.ScrSeq), [1 -1 1j -1j])), 'C in {1,j,-1,-j}');

% Приёмник возвращает исходный XFECFRAME
assert(max(abs(PL.StepRx(Tx) - X)) < 1e-12, 'Rx не восстановил XFECFRAME');
fprintf('Пункты 6-9: все проверки пройдены, длина PLFRAME = %d\n', length(Tx));
