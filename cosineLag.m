function [agent, agentAll]=cosineLag(agent, agentAll, nlag)
    agentAll.lag = zeros(1,nlag);
    agentAll.lagdiff = zeros(1,length(2:2:nlag));
    len = length(agent);
    for i=1:len
        sm = readmatrix(strcat(agent(i).name,'_r.csv'));
        sm=sm(1:200,1:200);
        
        agent(i).lag = zeros(1,nlag);
        agent(i).lagdiff = zeros(1,length(2:2:nlag));
        for j=1:nlag
            agent(i).lag(j)=mean(diag(sm,j));
        end
        for j=2:2:nlag
            agent(i).lagdiff(j/2) = agent(i).lag(j)-agent(i).lag(j-1);
        end


        limit = 100;
        f=fitlog(agent(i).lag, limit);
        agent(i).exp2 = f.p1;
        agent(i).fitobj = f;

        ft = fittype('power2');
        opts = fitoptions(ft);
        power = fit([1:100]', agent(i).lag(1:100)', ft, opts);
        
        agent(i).at100 = power(limit - 1);
        agent(i).at1 = power(1);
        agent(i).tcorr=timeCorr(agent(i));
        agent(i).power = power;
        
        agentAll.lag = agentAll.lag + agent(i).lag;
        agentAll.lagdiff = agentAll.lagdiff + agent(i).lagdiff;
    end
    agentAll.lag = agentAll.lag/len;
    agentAll.lagdiff = agentAll.lagdiff/len;
    
    f=fitlog(agentAll.lag, limit)
    agentAll.fitobj = f;
    agentAll.exp2 = f.p1;

    ft = fittype('power2');
    opts = fitoptions(ft);
    power = fit([1:100]', agent(i).lag(1:100)', ft, opts);
    agentAll.power = power;

end

function r = timeCorr(agent)
    sm = readmatrix(strcat(agent.name,'_r.csv'));
    sm=sm(1:200,1:200);
    agent.time_lag=log(diff(agent.timestamp(1:200)))';
    lag1=zeros(199,1);
    for i=2:200
        lag1(i-1,1)=sm(i-1,i);
    end
    valid=isfinite(agent.time_lag) & isfinite(lag1);
    r=corr(agent.time_lag(valid), lag1(valid));
end

function f = fitlog(data, n)
    f = fit(log([1:n])', log(data(1:n))', 'poly1');
end