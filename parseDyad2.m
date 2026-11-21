function [parsed, plist]=parseDyad2(pkm)
    spkm = size(pkm); len = spkm(2);
    parsed=zeros(1,len); plist=zeros(3,len); p = 0;
    idx=find(pkm>0); plen=length(idx);
    while plen > 0
        srtpks = sortrows([pkm(idx) idx],'descend');
        [np,nc]=size(srtpks);
        for i=1:np
            [scale,t]=ind2sub(spkm,srtpks(i,2));
            pk = pkm(scale,t); pkm(scale,t) = 0;
            scale=scale + 1;
            if sum(parsed(t:t+scale-1)>0) <= scale/2
                parsed(t:t+scale-1)=parsed(t:t+scale-1)+pk;
                p = p + 1; plist(:,p)=[t scale pk];
                break;
            end
        end
        if length(find(parsed==0))==0
            break;
        end
        idx=find(pkm>0); plen=length(idx);
    end
    tmp=plist(:,1:p); plist=sortrows(tmp');
end