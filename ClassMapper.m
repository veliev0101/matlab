classdef ClassMapper < handle
    properties (SetAccess = private)
        isTransparent;
        LogLanguage;
        Constellation;   % 4x1, для ClassChannel (Ps)
        log2M = 2;       % для ClassChannel (Pb)
        DecisionMethod;
    end
    methods
        function obj = ClassMapper(Params, LogLanguage)
            Mapper = Params.Mapper;
            obj.isTransparent  = Mapper.isTransparent;
            obj.LogLanguage    = LogLanguage;
            obj.DecisionMethod = Mapper.DecisionMethod;

            % Созвездие QPSK DVB-S2 (Gray, phi = pi/4)
            obj.Constellation = pskmod((0:3).', 4, pi/4, 'gray');
        end

        function Symbols = StepTx(obj, Bits)
            if obj.isTransparent
                Symbols = Bits;
                return
            end
            Bits = double(Bits(:));
            if mod(length(Bits), obj.log2M) ~= 0
                error('ClassMapper: число бит не кратно log2(M).');
            end
            % Группируем биты по 2 и превращаем в индексы 0..3
            B = reshape(Bits, 2, []).';
            Idx = B * [2; 1];   % [b1 b2] -> 2*b1 + b2
            Symbols = pskmod(Idx, 4, pi/4, 'gray');
        end

        function Out = StepRx(obj, Symbols, InstChannelParams) %#ok<INUSD>
            if obj.isTransparent
                Out = Symbols;
                return
            end
            % Демодуляция QPSK (жёсткие решения)
            Idx = pskdemod(Symbols(:), 4, pi/4, 'gray');
            % Индексы -> биты (MSB first)
            B = zeros(numel(Idx), 2);
            B(:,1) = floor(Idx / 2);
            B(:,2) = mod(Idx, 2);
            Out = reshape(B.', [], 1);
        end
    end
end
