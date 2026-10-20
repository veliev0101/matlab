function Params = CalcAndCheckParams(inParams, LogLanguage)
% Расчёт и проверка согласованности параметров
    Params = inParams;

% Если Encoder прозрачен, поддерживается только жёсткое решение маппера
    if Params.Encoder.isTransparent
        Params.Mapper.DecisionMethod = 'Hard decision';
    end

% На вход декодера приходят LLR, если маппер не принимает жёстких решений
    Params.Encoder.isSoftInput = ~Params.Encoder.isTransparent && ...
        ~strcmp(Params.Mapper.DecisionMethod, 'Hard decision');

% Скорость кода одна и та же для кодера, MODCOD и APSK-созвездия
    Params.PLFramer.CodeRate = Params.Encoder.CodeRate;

% Тип созвездия должен соответствовать порядку модуляции
    M = Params.Mapper.ModulationOrder;
    if any(M == [16 32]) && ~strcmp(Params.Mapper.Type, 'APSK')
        error('Mapper.Type must be ''APSK'' for M = 16 and 32.');
    end
    if any(M == [4 8]) && ~strcmp(Params.Mapper.Type, 'PSK')
        error('Mapper.Type must be ''PSK'' for M = 4 and 8.');
    end

% Длина FECFRAME
    switch Params.PLFramer.FECFrame
        case 'normal', nLdpc = 64800;
        case 'short',  nLdpc = 16200;
    end

% Длина кадра на входе кодера: K_bch для выбранной скорости кода
    if ~Params.Encoder.isTransparent
        Kbch = ClassEncoder.CodeParams(Params.Encoder.CodeRate);
        if Params.Source.NumBitsPerFrame ~= Kbch
            if strcmp(LogLanguage, 'Russian')
                error(['Source.NumBitsPerFrame = %d, а для скорости ', ...
                    '%s нужно K_bch = %d.'], ...
                    Params.Source.NumBitsPerFrame, ...
                    Params.Encoder.CodeRate, Kbch);
            else
                error(['Source.NumBitsPerFrame = %d, but K_bch = %d ', ...
                    'is required for rate %s.'], ...
                    Params.Source.NumBitsPerFrame, Kbch, ...
                    Params.Encoder.CodeRate);
            end
        end
    else
        % Без кодера число бит на входе маппера должно давать целое
        % число символов
        if mod(Params.Source.NumBitsPerFrame, log2(M)) > 0
            if strcmp(LogLanguage, 'Russian')
                error(['В потоке на входе маппера число бит не кратно ', ...
                    'log2(M).']);
            else
                error(['The number of bits at the input of the ', ...
                    'mapper is not multiple of log2(M).']);
            end
        end
        % PLFramer рассчитан на полный XFECFRAME
        if ~Params.PLFramer.isTransparent && ...
                Params.Source.NumBitsPerFrame ~= nLdpc
            if strcmp(LogLanguage, 'Russian')
                error(['При прозрачном Encoder PLFramer требует ', ...
                    'прозрачности или Source.NumBitsPerFrame = %d.'], nLdpc);
            else
                error(['With transparent Encoder PLFramer must be ', ...
                    'transparent or Source.NumBitsPerFrame = %d.'], nLdpc);
            end
        end
    end

% Коэффициент сглаживания должен совпадать с зашитым в MATYPE источника
% (RO = 10 -> beta = 0.20)
    if ~Params.Sig.isTransparent && abs(Params.Sig.RollOff - 0.20) > 1e-9
        if strcmp(LogLanguage, 'Russian')
            warning(['Sig.RollOff = %g, а в BBHEADER источника ', ...
                'записано beta = 0.20 (MATYPE-1 = 0xF2).'], ...
                Params.Sig.RollOff);
        else
            warning(['Sig.RollOff = %g, but BBHEADER of the source ', ...
                'contains beta = 0.20 (MATYPE-1 = 0xF2).'], ...
                Params.Sig.RollOff);
        end
    end
end
