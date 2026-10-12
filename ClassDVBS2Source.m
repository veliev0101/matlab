classdef ClassDVBS2Source < handle
    properties (SetAccess = private)
        % Сколько бит выдаётся за один кадр (K_bch)
            NumBitsPerFrame;
        % Количество MPEG-TS пакетов в одном BBFRAME
            NumTSFrames;
        % Сохраняем последний Info для отладки/проверки
            LastInfo;
        % Переменная управления языком
            LogLanguage;
        % Параметры варианта
            Params;
    end
    methods
        function obj = ClassDVBS2Source(ParamsIn, LogLanguage)
            % ParamsIn не используется — все параметры варианта 2
            % зашиты внутри DVBS2_Variant2_Chain. Оставлен для
            % совместимости с интерфейсом конструктора.
            obj.LogLanguage = LogLanguage;

            % Параметры варианта 2 (должны совпадать с теми, что
            % используются в DVBS2_Variant2_Chain)
                obj.Params.Modulation      = 'QPSK';
                obj.Params.ModulationOrder = 4;
                obj.Params.LDPCRate        = 3/4;
                obj.Params.RollOff         = 0.20;
                obj.Params.Pilots          = true;
                obj.Params.n_ldpc          = 64800;
                obj.Params.K_bch           = 48600;
                obj.Params.BCH_t           = 12;
                obj.Params.UPL_bits        = 1504;
                obj.Params.BBHEADERBits    = 80;

            % Количество TS-пакетов в одном BBFRAME
                AvailableBits = obj.Params.K_bch - obj.Params.BBHEADERBits;
                obj.NumTSFrames = floor(AvailableBits / obj.Params.UPL_bits);

            % Длина кадра = K_bch
                obj.NumBitsPerFrame = obj.Params.K_bch;

            % Инициализация поля LastInfo
                obj.LastInfo = [];

            fprintf(['ClassDVBS2Source: вариант 2, K_bch = %d, ', ...
                'TS-пакетов в BBFRAME = %d\n'], ...
                obj.NumBitsPerFrame, obj.NumTSFrames);
        end
        
        function Bits = Step(obj)
            % isVerbose = false — модель работает без вывода в консоль
            [BBFRAME_scrambled, Info] = ...
                DVBS2_Variant2_Chain(obj.NumTSFrames, false);
            obj.LastInfo = Info;
            Bits = BBFRAME_scrambled(:);
        end
    end
end