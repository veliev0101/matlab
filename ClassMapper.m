classdef ClassMapper < handle
    % ClassMapper — Отображение бит на модуляционные символы созвездия
    
    properties
        ModType % Тип модуляции (для Команды 2: 'QPSK')
    end
    
    methods
        function obj = ClassMapper(modType)
            if nargin < 1
                obj.ModType = 'QPSK';
            else
                obj.ModType = modType;
            end
        end
        
        function symbols = Process(obj, bits)
            switch obj.ModType
                case 'QPSK'
                    M = 4;
                    % Группировка бит по 2 на символ
                    bitGroups = reshape(bits, log2(M), []);
                    symbolIndices = bit2int(bitGroups, log2(M));
                    
                    % Modulator QPSK DVB-S2 (фазовый сдвиг pi/4, Gray mapping)
                    symbols = pskmod(symbolIndices, M, pi/4, 'gray');
                    
                otherwise
                    error('Указанный тип модуляции не поддерживается в данной конфигурации.');
            end
        end
    end
end
