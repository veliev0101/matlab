classdef ClassEncoder < handle
    % ClassEncoder — Помехоустойчивое каскадное кодирование (BCH + LDPC)
    
    properties
        BchEncoder   % Объект BCH-кодера
        LdpcEncoder  % Объект LDPC-кодера
        CodeRate     % Скорость кодирования (для Команды 2: '3/4')
    end
    
    methods
        function obj = ClassEncoder(codeRate)
            if nargin < 1
                codeRate = '3/4';
            end
            obj.CodeRate = codeRate;
            
            % Настройка BCH кодера для скорости 3/4 (Normal Frame: K_bch=48408, N_bch=48600)
            obj.BchEncoder = comm.BCHEncoder('CodewordLength', 48600, 'MessageLength', 48408);
            
            % Настройка стандартного DVB-S2 LDPC кодера MATLAB
            obj.LdpcEncoder = comm.DVBS2LDPCEncoder('CodeRate', obj.CodeRate);
        end
        
        function fecframe = Process(obj, bbframe)
            % 1. Внешнее BCH-кодирование
            bch_encoded = obj.BchEncoder(bbframe);
            
            % 2. Внутреннее LDPC-кодирование
            fecframe = obj.LdpcEncoder(bch_encoded);
        end
    end
end
