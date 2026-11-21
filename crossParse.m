function [agent, agentAll]=crossParse( agent, smin, smax) 
    agentAll = {}; agentAll.list = []; agentAll.parse = [];
    len = length(agent);
    for i=1:len
       
        disp(agent(i).name + " " + num2str(i));
        sm=readmatrix(strcat(agent(i).name, '_r.csv'));
        sm=sm(1:200,1:200);
        
        [agent(i).pkm,agent(i).pvm]=convCross4(sm,smin,smax);
        [agent(i).parse,agent(i).list]=parseDyad2(agent(i).pkm);
        agentAll.list = [agentAll.list; agent(i).list];
        agentAll.parse = [agentAll.parse agent(i).parse];
        %agent(i).word = importdata(strcat(agent(i).name, '.txt'));
        %agent(i).wordlen = strlength(agent(i).word);
    end
end