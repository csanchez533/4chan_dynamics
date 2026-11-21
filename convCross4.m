function [pkm, pvm] = convCross4(m, smin, smax)
    nRuns = 10;
    len = length(m); nscale = length(smin:smax); 
    pkm_runs = zeros(nRuns, nscale, len);

    for i = 1: nRuns
        [pkm_cur, pvm] = convCross4_(m, smin, smax);
        pkm_runs(i, :, :) = pkm_cur;
    end
    pkm = squeeze(mean(pkm_runs, 1));

    
end

function [pkm,pvm]=convCross4_( m, smin, smax ) 
    
    len = length(m); nscale = length(smin:smax); 
    
    cvm = zeros(nscale,len); cvr = zeros(nscale,len);
    pkm = zeros(nscale,len); pvm = zeros(nscale,len);
    rdx = randperm(len); r = m(rdx,rdx);
    
    for j=1:nscale
        s = smin+(j-1);
        cross = zeros(3*s); 
        cross(s+1:2*s,1:s) = -1; 
        cross(1:s,s+1:2*s) = -1; 
        cross(s+1:2*s,2*s+1:3*s) = -1; 
        cross(2*s+1:3*s,s+1:2*s) = -1; 
        cross(s+1:2*s,s+1:2*s) = 4*(1-diag(ones(s,1)))*s^2/(s^2-s);
        for i=1:len-3*s
            cvm(j,s+i)=sum(sum(m(i:i+3*s-1,i:i+3*s-1).*cross))/((5*s^2)-s);
            cvr(j,s+i)=sum(sum(r(i:i+3*s-1,i:i+3*s-1).*cross))/((5*s^2)-s);
        end
        pkm(j,:)=cvm(j,:);
        for i=s+1:len-2*s
            [y,idx] = max(pkm(j,i:i+s-1));
            pkm(j,i:i+s-1)=0;
            pkm(j,i+idx-1)=y;
        end
        maxp = max(cvr(j,:));
        pkm(j,:)=((pkm(j,:)>maxp).*(pkm(j,:)-maxp));
        for i=find(pkm(j,:)>0)
            pvm(j,i:i+s-1) = pkm(j,i);
        end
    end
    
    
end
