function [BBFRAME_scrambled, Info] = DVBS2_Variant2_Chain(NumTSFrames, isVerbose)
%
% Формирование цепочки DVB-S2 для варианта 2:
%   QPSK, R = 3/4, beta = 0.20, pilots = on
%
% Вход:
%   NumTSFrames - количество MPEG-TS пакетов (целое число)
%   isVerbose   - флаг вывода отладочных сообщений (по умолчанию false)
%
% Выход:
%   BBFRAME_scrambled - скремблированный BBFRAME (K_bch бит)
%   Info - структура с промежуточными результатами для проверки
%
% Реализуемые пункты:
%   1) Формирование MPEG-TS пакетов
%   2) CRC-8
%   3) BBHEADER и BBFRAME
%   4) Скремблирование (BB scrambling)
%

%% ===== Обработка входных аргументов =====
    if nargin < 1 || isempty(NumTSFrames)
        NumTSFrames = 32;   % значение по умолчанию
    end
    if nargin < 2 || isempty(isVerbose)
        isVerbose = false;
    end

%% ===== Параметры варианта 2 =====
    Params.Modulation      = 'QPSK';
    Params.ModulationOrder = 4;
    Params.LDPCRate        = 3/4;
    Params.RollOff         = 0.20;
    Params.Pilots          = true;
    Params.FECFRAMEType    = 'normal';
    Params.n_ldpc          = 64800;
    Params.K_bch           = 48600;
    Params.N_bch           = 48600;
    Params.BCH_t           = 12;

    Params.UPL_bits  = 1504;
    Params.DataBits  = 1496;
    Params.CRCBits   = 8;
    Params.SyncByte  = hex2dec('47');

    Params.BBHEADERBits = 80;
    Params.AvailableBits = Params.K_bch - Params.BBHEADERBits;
    Params.NumTSPackets  = floor(Params.AvailableBits / Params.UPL_bits);
    Params.DFL           = Params.NumTSPackets * Params.UPL_bits;
    Params.PaddingBits   = Params.AvailableBits - Params.DFL;

    if isVerbose
        fprintf('=== Вариант 2: QPSK, R=3/4, beta=0.20, pilots=on ===\n');
        fprintf('K_bch = %d бит\n', Params.K_bch);
        fprintf('Количество TS-пакетов в BBFRAME: %d\n', Params.NumTSPackets);
        fprintf('DFL = %d бит, PADDING = %d бит\n', ...
            Params.DFL, Params.PaddingBits);
    end

%% ===== Пункт 1: Формирование MPEG-TS пакетов =====
    NumTSFrames = min(NumTSFrames, Params.NumTSPackets);

    TSFrames = cell(Params.NumTSPackets, 1);
    for k = 1:NumTSFrames
        sync = Params.SyncByte;
        payload = randi([0 255], 187, 1);
        TSFrames{k} = [sync; payload];
    end
    % Добиваем оставшиеся пакеты нулями, чтобы DATA FIELD был полным
    for k = (NumTSFrames+1):Params.NumTSPackets
        TSFrames{k} = [Params.SyncByte; zeros(187, 1)];
    end
    NumTSFrames = Params.NumTSPackets;

    % Преобразуем в битовый поток (MSB first)
    TSBits = zeros(NumTSFrames * 188 * 8, 1);
    for k = 1:NumTSFrames
        bytes = TSFrames{k};
        bits  = de2bi(bytes, 8, 'left-msb').';
        TSBits((k-1)*1504 + (1:1504)) = bits(:);
    end
    Info.TSBits   = TSBits;
    Info.TSFrames = TSFrames;

    if isVerbose
        fprintf('Пункт 1 выполнен: %d MPEG-TS пакетов (%d бит)\n', ...
            NumTSFrames, length(TSBits));
    end

%% ===== Пункт 2: CRC-8 =====
    AdaptedPackets = cell(NumTSFrames, 1);
    CRCBytes = zeros(NumTSFrames, 1);
    for k = 1:NumTSFrames
        frameBits = TSBits((k-1)*1504 + (1:1504));
        dataBits  = frameBits(9:end);        % 1496 бит
        crc       = crc8_dvbs2(dataBits);
        CRCBytes(k) = crc;
        crcBits = de2bi(crc, 8, 'left-msb').';
        AdaptedPackets{k} = [dataBits; crcBits];
    end
    Info.AdaptedPackets = AdaptedPackets;
    Info.CRCBytes       = CRCBytes;

    if isVerbose
        fprintf('Пункт 2 выполнен: CRC-8 для %d пакетов\n', NumTSFrames);
        fprintf('  Пример CRC пакета 1: 0x%02X\n', CRCBytes(1));
    end

%% ===== Пункт 3: BBHEADER и BBFRAME =====
    % --- MATYPE-1 (8 бит) ---
    matype1 = 0;
    matype1 = bitor(matype1, bitshift(1, 7));   % TS/GSSIS = 1
    matype1 = bitor(matype1, bitshift(1, 6));   % SIS/MIS  = 1
    matype1 = bitor(matype1, bitshift(1, 5));   % CCM/ACM  = 1
    matype1 = bitor(matype1, bitshift(1, 4));   % ISSI     = 1
    matype1 = bitor(matype1, bitshift(1, 3));   % NPD      = 1
    matype1 = bitor(matype1, bitshift(1, 1));   % RO = 10 -> beta = 0.20

    % --- MATYPE-2 (8 бит) ---
    matype2 = 0;   % SIS -> reserved

    % --- UPL, DFL, SYNC ---
    upl  = 1504;
    dfl  = Params.DFL;
    sync = Params.SyncByte;

    % --- BBHEADER: 72 бита + CRC-8 (8 бит) = 80 бит ---
    bbheader_first72 = [ ...
        de2bi(matype1, 8, 'left-msb').'; ...
        de2bi(matype2, 8, 'left-msb').'; ...
        de2bi(upl,    16, 'left-msb').'; ...
        de2bi(dfl,    16, 'left-msb').'; ...
        de2bi(sync,    8, 'left-msb').'; ...
        zeros(16, 1)];                      % 16 резервных бит

    bbheader_crc = crc8_dvbs2(bbheader_first72);
    BBHEADER = [bbheader_first72; de2bi(bbheader_crc, 8, 'left-msb').'];
    Info.BBHEADER = BBHEADER;
    Info.MATYPE1  = matype1;
    Info.MATYPE2  = matype2;

    % --- DATA FIELD ---
    DataField = zeros(Params.DFL, 1);
    for k = 1:NumTSFrames
        DataField((k-1)*Params.UPL_bits + (1:Params.UPL_bits)) = ...
            AdaptedPackets{k};
    end
    Info.DataField = DataField;

    % --- PADDING ---
    Padding = zeros(Params.PaddingBits, 1);

    % --- BBFRAME ---
    BBFRAME = [BBHEADER; DataField; Padding];
    Info.BBFRAME = BBFRAME;

    assert(length(BBFRAME) == Params.K_bch, ...
        'Длина BBFRAME должна быть равна K_bch!');

    if isVerbose
        fprintf('Пункт 3 выполнен: BBFRAME сформирован\n');
        fprintf('  BBHEADER = 80 бит, DATA FIELD = %d бит, PADDING = %d бит\n', ...
            Params.DFL, Params.PaddingBits);
        fprintf('  MATYPE-1 = 0x%02X, MATYPE-2 = 0x%02X\n', matype1, matype2);
        fprintf('  CRC BBHEADER = 0x%02X\n', bbheader_crc);
    end

%% ===== Пункт 4: BB scrambling =====
    initSeq = [1 0 0 1 0 1 0 1 0 0 0 0 0 0 0];
    BBFRAME_scrambled = bb_scramble(BBFRAME, initSeq);
    Info.BBFRAME_scrambled = BBFRAME_scrambled;

    if isVerbose
        fprintf('Пункт 4 выполнен: BBFRAME скремблирован (%d бит)\n', ...
            length(BBFRAME_scrambled));
    end

end

%% ===== Вспомогательная функция: CRC-8 DVB-S2 =====
function crc = crc8_dvbs2(dataBits)
% CRC-8 по схеме DVB-S2 (регистр r1..r8)
    r = zeros(1, 8);
    for k = 1:length(dataBits)
        f = bitxor(dataBits(k), r(8));
        r_new = zeros(1, 8);
        r_new(1) = f;
        r_new(2) = r(1);
        r_new(3) = bitxor(r(2), f);
        r_new(4) = r(3);
        r_new(5) = bitxor(r(4), f);
        r_new(6) = r(5);
        r_new(7) = bitxor(r(6), f);
        r_new(8) = bitxor(r(7), f);
        r = r_new;
    end
    crc = 0;
    for k = 1:8
        crc = bitor(crc, bitshift(r(k), 8-k));
    end
end

%% ===== Вспомогательная функция: BB scrambling =====
function out = bb_scramble(in, initSeq)
% Скремблирование BBFRAME по стандарту DVB-S2
% Полином: 1 + X^14 + X^15
    reg = initSeq(:).';
    out = zeros(size(in));
    for k = 1:length(in)
        p = bitxor(reg(14), reg(15));
        out(k) = bitxor(in(k), p);
        reg = [p, reg(1:14)];
    end
end