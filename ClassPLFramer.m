classdef ClassPLFramer < handle
    % ClassPLFramer - формирование PLFRAME (пункты 6-9 лабораторной):
    %   6) PLHEADER
    %   7) разбиение XFECFRAME на слоты
    %   8) вставка пилотов
    %   9) PL-скремблирование (код Голда)

    properties (Constant)
        SlotLen   = 90;                  % символов в слоте
        PilotLen  = 36;                  % символов в пилот-блоке
        SOFHex    = '18D2E82';           % SOF (26 бит)
        PLSScrHex = '719D83C953422DFA';  % скремблер PLSCODE (64 бита)
    end
    properties (SetAccess = private)
        isTransparent;
        LogLanguage;
        ModOrder;          % M
        CodeRate;          % строка, например '3/4'
        FECFrame;          % 'normal' | 'short'
        HasPilots;
        ScramblingCode;    % номер кода Голда n
        MODCOD;
        NumXFECSymbols;
        NumSlots;          % S
        NumPilotBlocks;
        PLFrameLength;
        Header;            % PLHEADER, 90x1 комплексных символов
        PilotMask;         % маска пилотов в теле кадра (без PLHEADER)
        ScrSeq;            % комплексная скремблирующая последовательность
        LastInfo;          % промежуточные результаты для проверки
    end
    methods
        function obj = ClassPLFramer(Params, LogLanguage)
            PL = Params.PLFramer;
            obj.isTransparent  = PL.isTransparent;
            obj.LogLanguage    = LogLanguage;
            obj.ModOrder       = Params.Mapper.ModulationOrder;
            obj.CodeRate       = PL.CodeRate;
            obj.FECFrame       = PL.FECFrame;
            obj.HasPilots      = logical(PL.Pilots);
            obj.ScramblingCode = PL.ScramblingCode;
            obj.LastInfo       = struct();

            switch obj.FECFrame
                case 'normal', nLdpc = 64800;
                case 'short',  nLdpc = 16200;
                otherwise
                    error('PLFramer.FECFrame must be ''normal'' or ''short''.');
            end
            obj.NumXFECSymbols = nLdpc / log2(obj.ModOrder);
            obj.NumSlots       = obj.NumXFECSymbols / obj.SlotLen;
            if obj.HasPilots
                obj.NumPilotBlocks = floor((obj.NumSlots - 1) / 16);
            else
                obj.NumPilotBlocks = 0;
            end
            obj.PLFrameLength = obj.SlotLen * (obj.NumSlots + 1) + ...
                obj.PilotLen * obj.NumPilotBlocks;

            obj.MODCOD = ClassPLFramer.GetMODCOD(obj.ModOrder, obj.CodeRate);

            % Пункт 6: заголовок (одинаков для всех кадров)
            obj.Header = obj.BuildPLHeader();

            % Пункт 8: маска пилотов; пункт 9: скремблирующая последовательность
            [~, mask] = obj.InsertPilots(zeros(obj.SlotLen, obj.NumSlots));
            obj.PilotMask = mask;
            obj.ScrSeq = ClassPLFramer.ScramblingSequence( ...
                obj.ScramblingCode, numel(mask));
        end

        %% ===== Пункт 6: PLHEADER =====
        function Hdr = BuildPLHeader(obj)
            % SOF: 26 младших бит от 0x18D2E82 (старший бит слева)
            sofBits = ClassPLFramer.HexToBits(obj.SOFHex);
            sofBits = sofBits(3:end);

            % PLS: b1..b5 = MODCOD (MSB first), b6 = размер кадра, b7 = пилоты
            b = [bitget(obj.MODCOD, 5:-1:1), ...
                 double(strcmp(obj.FECFrame, 'short')), ...
                 double(obj.HasPilots)];

            % Код (32,6): y = [b1..b6]*G
            G = [repmat([0 1], 1, 16); ...
                 repmat([0 0 1 1], 1, 8); ...
                 repmat([0 0 0 0 1 1 1 1], 1, 4); ...
                 repmat([zeros(1,8) ones(1,8)], 1, 2); ...
                 [zeros(1,16) ones(1,16)]; ...
                 ones(1, 32)];
            y = mod(b(1:6) * G, 2);

            % Биортогональный код (64,7): (y1, y1^b7, y2, y2^b7, ...)
            c = zeros(1, 64);
            c(1:2:end) = y;
            c(2:2:end) = mod(y + b(7), 2);

            % Скремблирование PLSCODE фиксированной 64-битной последовательностью
            plsBits = mod(c + ClassPLFramer.HexToBits(obj.PLSScrHex), 2);

            hdrBits = [sofBits, plsBits];           % 26 + 64 = 90 бит
            Hdr = ClassPLFramer.PiBy2BPSK(hdrBits); % 90 символов

            obj.LastInfo.SOFBits    = sofBits;
            obj.LastInfo.PLSBits7   = b;
            obj.LastInfo.PLSCode    = plsBits;
            obj.LastInfo.HeaderBits = hdrBits;
            obj.LastInfo.PLHEADER   = Hdr;
        end

        %% ===== Пункт 7: разбиение на слоты =====
        function Slots = SplitIntoSlots(obj, X)
            % Каждый столбец - один слот из 90 символов
            Slots = reshape(X(:), obj.SlotLen, obj.NumSlots);
        end

        %% ===== Пункт 8: вставка пилотов =====
        function [Body, isPilot] = InsertPilots(obj, Slots)
            L = obj.SlotLen * obj.NumSlots + obj.PilotLen * obj.NumPilotBlocks;
            Body    = zeros(L, 1);
            isPilot = false(L, 1);
            pilot   = (1 + 1j) / sqrt(2);   % I = Q = 1/sqrt(2), без модуляции
            pos = 0;
            for s = 1:obj.NumSlots
                Body(pos + (1:obj.SlotLen)) = Slots(:, s);
                pos = pos + obj.SlotLen;
                % пилот-блок после каждых 16 слотов, но не перед следующим SOF
                if obj.HasPilots && mod(s, 16) == 0 && s < obj.NumSlots
                    Body(pos + (1:obj.PilotLen))    = pilot;
                    isPilot(pos + (1:obj.PilotLen)) = true;
                    pos = pos + obj.PilotLen;
                end
            end
        end

        %% ===== Пункт 9: PL-скремблирование (PLHEADER не скремблируется) =====
        function Out = PLScramble(obj, Body)
            Out = Body(:) .* obj.ScrSeq;   % (I+jQ)*(CI+jCQ)
        end

        %% ===== Передатчик =====
        function PLFrame = StepTx(obj, XFEC)
            if obj.isTransparent
                PLFrame = XFEC;
                return
            end
            XFEC = XFEC(:);
            if length(XFEC) ~= obj.NumXFECSymbols
                error(['ClassPLFramer: ожидалось %d символов XFECFRAME, ', ...
                    'получено %d. Проверьте длину кадра (BCH/LDPC/маппер).'], ...
                    obj.NumXFECSymbols, length(XFEC));
            end
            Slots = obj.SplitIntoSlots(XFEC);
            Body  = obj.InsertPilots(Slots);
            Scr   = obj.PLScramble(Body);
            PLFrame = [obj.Header; Scr];

            obj.LastInfo.Slots   = Slots;
            obj.LastInfo.Body    = Body;      % с пилотами, до скремблирования
            obj.LastInfo.PLFRAME = PLFrame;
        end

        %% ===== Приёмник (идеальная синхронизация) =====
        function XFEC = StepRx(obj, PLFrame)
            if obj.isTransparent
                XFEC = PLFrame;
                return
            end
            PLFrame = PLFrame(:);
            Body = PLFrame(obj.SlotLen + 1:end) .* conj(obj.ScrSeq);
            XFEC = Body(~obj.PilotMask);
        end
    end

    methods (Static)
        function bits = HexToBits(h)
            bits = zeros(1, 4 * numel(h));
            for k = 1:numel(h)
                bits(4*(k-1) + (1:4)) = bitget(hex2dec(h(k)), 4:-1:1);
            end
        end

        function modcod = GetMODCOD(M, rate)
            switch M
                case 4
                    rates = {'1/4','1/3','2/5','1/2','3/5','2/3','3/4', ...
                             '4/5','5/6','8/9','9/10'};  base = 1;
                case 8
                    rates = {'3/5','2/3','3/4','5/6','8/9','9/10'};  base = 12;
                case 16
                    rates = {'2/3','3/4','4/5','5/6','8/9','9/10'};  base = 18;
                case 32
                    rates = {'3/4','4/5','5/6','8/9','9/10'};        base = 24;
                otherwise
                    error('Unsupported modulation order M = %d.', M);
            end
            idx = find(strcmp(rates, rate), 1);
            if isempty(idx)
                error('Code rate %s is not valid for M = %d.', rate, M);
            end
            modcod = base + idx - 1;
        end

        function Sym = PiBy2BPSK(bits)
            % pi/2-BPSK: нечётный бит (1-based) -> (1-2b)(1+j)/sqrt2,
            %            чётный бит             -> (1-2b)(-1+j)/sqrt2
            bits = bits(:);
            a  = 1 - 2*bits;
            ev = mod((0:numel(bits)-1).', 2) == 0;
            Sym = zeros(size(a));
            Sym(ev)  = a(ev)  * (1 + 1j) / sqrt(2);
            Sym(~ev) = a(~ev) * (-1 + 1j) / sqrt(2);
        end

        function C = ScramblingSequence(n, L)
            % Комплексная последовательность Голда: C = exp(j*pi/2*Rn(i)), i=0..L-1
            persistent xs ys
            N = 2^18 - 1;
            if isempty(xs)
                xs = zeros(1, N, 'uint8');  ys = zeros(1, N, 'uint8');
                xs(1)    = 1;               % x(0)=1, x(1..17)=0
                ys(1:18) = 1;               % y(0..17)=1
                for m = 1:N-18              % 1-based: m = i+1
                    xs(m+18) = bitxor(xs(m+7), xs(m));
                    ys(m+18) = bitxor(bitxor(ys(m+10), ys(m+7)), ...
                                      bitxor(ys(m+5),  ys(m)));
                end
            end
            if L > 66420
                error('PLFRAME слишком длинный для одной последовательности Rn.');
            end
            % z_n(i) = x((i+n) mod N) xor y(i), i = 0..N-1
            z = bitxor(xs(mod((0:N-1) + n, N) + 1), ys);
            i = 0:L-1;
            R = 2*double(z(mod(i + 131072, N) + 1)) + double(z(i + 1));
            Cs = [1; 1j; -1; -1j];          % exp(j*pi/2*R) для R = 0..3
            C = Cs(R(:) + 1);
        end
    end
end
