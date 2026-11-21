function [agent, agentAll]=crossStat( agent, agentAll, smin, smax )
    nscale=length(smin:smax); len = length(agent);
    agentAll.patch = zeros(1,nscale); agentAll.wtd = zeros(1,nscale); 
    sump = zeros(1,nscale); nump = zeros(1,nscale);
    for i=1:len
        denom = length(agent(i).pkm)./(smin:smax);
        agent(i).sumPeak = sum(agent(i).pkm');
        agent(i).wtdPatch = agent(i).sumPeak./denom;
        agent(i).peak = max(agent(i).wtdPatch);
        
        agent(i).wtdMean = sum(agent(i).wtdPatch.*[smin:smax])/sum(agent(i).wtdPatch); 
        agent(i).numPeak = sum(agent(i).pkm'>0);
        agent(i).propPatch = agent(i).numPeak./denom;
        agentAll.patch = agentAll.patch + agent(i).propPatch;
        agentAll.wtd = agentAll.wtd + agent(i).wtdPatch;
        sump = sump + agent(i).sumPeak;
        nump = nump + agent(i).numPeak;
    end
    agentAll.peak = max(agentAll.wtd);
    agentAll.peak2 = sump./nump;
    agentAll.peak2(find(isnan(agentAll.peak)))=0;
    agentAll.patch = agentAll.patch/len;
    agentAll.wtd = agentAll.wtd/len;
    agentAll.wtdMean = sum(agentAll.wtd.*[smin:smax])/sum(agentAll.wtd); 
end

