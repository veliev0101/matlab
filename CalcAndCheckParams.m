function Params = CalcAndCheckParams(inParams, LogLanguage)
% Пересохраним входные данные
    Params = inParams;
    
% Если Encoder прозрачен, принудительно ставим жёсткие решения
    if Params.Encoder.isTransparent
        Params.Mapper.DecisionMethod = 'Hard decision';
    end

% Проверка кратности log2(M)
    if Params.Encoder.isTransparent
        if mod(Params.Source.NumBitsPerFrame, ...
                log2(Params.Mapper.ModulationOrder)) > 0
            if strcmp(LogLanguage, 'Russian')
                error(['В модулятор поступает число бит не кратное ', ...
                    'log2(M).']);
            else
                error(['The number of bits at the input of the ', ...
                    'mapper is not multiple of log2(M).']);
            end
        end
    end

% === ДОБАВЛЕНО: проверка соответствия параметров DVB-S2 варианту 2 ===
    % K_bch для R=3/4 должен быть 48600, log2(M)=2 для QPSK
        if isfield(Params.Source, 'NumBitsPerFrame') && ...
                Params.Source.NumBitsPerFrame ~= 48600
            if strcmp(LogLanguage, 'Russian')
                warning(['Source.NumBitsPerFrame = %d, ', ...
                    'но для варианта 2 (R=3/4, QPSK) ожидается ', ...
                    'K_bch = 48600. Значение будет проигнорировано ', ...
                    'классом ClassDVBS2Source.'], ...
                    Params.Source.NumBitsPerFrame);
            else
                warning(['Source.NumBitsPerFrame = %d, but ', ...
                    'for variant 2 (R=3/4, QPSK) K_bch = 48600 ', ...
                    'is expected. The value will be ignored by ', ...
                    'ClassDVBS2Source.'], ...
                    Params.Source.NumBitsPerFrame);
            end
        end
end