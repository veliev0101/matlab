classdef ClassInterleaver < handle
    % ClassInterleaver — Класс для реализации блочного перемежения в DVB-S2
    
    properties
        InterleaverOn % Флаг включения перемежителя (1/0)
    end
    
    methods
        function obj = ClassInterleaver(InterleaverOn)
            if nargin > 0
                obj.InterleaverOn = InterleaverOn;
            else
                obj.InterleaverOn = 1;
            end
        end
        
        function outBits = Process(obj, inBits, modType, n_ldpc)
            % Process — Перемежение бит кадра FECFRAME
            
            % Для Команды 2 (QPSK) перемежение не применяется по стандарту DVB-S2
            if strcmp(modType, 'QPSK') || ~obj.InterleaverOn
                outBits = inBits; % Пропуск без изменений
            else
                % Логика для 8PSK / 16APSK / 32APSK (для универсальности)
                switch modType
                    case '8PSK'
                        numCols = 3;
                    case '16APSK'
                        numCols = 4;
                    case '32APSK'
                        numCols = 5;
                    otherwise
                        numCols = 1;
                end
                
                numRows = n_ldpc / numCols;
                % Запись по столбцам, чтение по строкам
                interleavingMatrix = reshape(inBits, numRows, numCols);
                outBits = reshape(interleavingMatrix', [], 1);
            end
        end
    end
end
