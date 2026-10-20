classdef ClassInterleaver < handle
    % ClassInterleaver - блочное перемежение бит FECFRAME (DVB-S2)
    %   Запись по столбцам, чтение по строкам.
    %   Для QPSK перемежитель не применяется (стандарт).
    %   Для 8PSK 3/5 столбцы читаются в обратном порядке (MSB заголовка
    %   читается третьим).
    %   StepRx работает и с битами, и с LLR.

    properties (SetAccess = private)
        isTransparent;
        isBypass;        % true - перемежение не выполняется
        LogLanguage;
        NumRows;
        NumCols;
        ReverseCols;     % 8PSK, R = 3/5
    end
    methods
        function obj = ClassInterleaver(Params, LogLanguage)
            obj.LogLanguage   = LogLanguage;
            obj.isTransparent = Params.Interleaver.isTransparent;

            M = Params.Mapper.ModulationOrder;
            switch Params.PLFramer.FECFrame
                case 'normal', nLdpc = 64800;
                case 'short',  nLdpc = 16200;
            end

            obj.isBypass = obj.isTransparent || (M == 4);
            if M == 4
                obj.NumCols = 2;                 % не используется
            else
                obj.NumCols = log2(M);           % 3, 4, 5 столбцов
            end
            obj.NumRows     = nLdpc / obj.NumCols;
            obj.ReverseCols = (M == 8) && strcmp(Params.Encoder.CodeRate, '3/5');
        end

        function Out = StepTx(obj, In)
            if obj.isBypass
                Out = In;
                return
            end
            Mx = reshape(In(:), obj.NumRows, obj.NumCols); % запись по столбцам
            if obj.ReverseCols
                Mx = Mx(:, end:-1:1);
            end
            Out = reshape(Mx.', [], 1);                    % чтение по строкам
        end

        function Out = StepRx(obj, In)
            if obj.isBypass
                Out = In;
                return
            end
            X = reshape(In(:), obj.NumCols, obj.NumRows).'; % строки перемежителя
            if obj.ReverseCols
                X = X(:, end:-1:1);
            end
            Out = X(:);
        end
    end
end

