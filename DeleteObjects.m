function DeleteObjects(Objs, Ruler)
%
% Óäàëåíèå âñåõ îáúåêòîâ, èñïîëüçóåìûõ â öèêëå îáðàáîòêè îäíîãî íàáîðà
% ïàðàìåòðîâ

    for k = 1:Ruler.NumWorkers
        delete(Objs{k}.Source);      % <-- çäåñü òåïåðü ClassDVBS2Source
        delete(Objs{k}.Encoder);
        delete(Objs{k}.Interleaver);
        delete(Objs{k}.Mapper);
        delete(Objs{k}.PLFramer);
        delete(Objs{k}.Sig);
        delete(Objs{k}.Channel);
        delete(Objs{k}.Stat);
    end
    
    delete(Ruler);
end
