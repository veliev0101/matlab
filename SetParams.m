% Параметры для Команды 2
params.ModType = 'QPSK';         % Модуляция QPSK
params.CodeRate = '3/4';         % Скорость LDPC 3/4
params.FrameLen = 'normal';      % Normal FECFRAME (64800 бит)
params.RollOff = 0.20;           % Beta = 0.20
params.Pilots = 'on';            % Пилоты включены

% Длины по стандарту DVB-S2 (Normal Frame, Rate 3/4)
params.K_bch = 48408;            % Информационные биты BBFRAME
params.k_ldpc = 48600;           % Вход LDPC / Выход BCH
params.n_ldpc = 64800;           % Выход LDPC (FECFRAME)
