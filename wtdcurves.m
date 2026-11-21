function b = boards()
    
    %     1     2     3      4    5      6      7    8       9      10     11    12     13     14    15    16   17    18    19   20    21   22   23    24 
    b = ["ck", "co", "fit", "g", "his", "int", "k", "lgbt", "lit", "mlp", "mu", "pol", "sci", "sp", "tv", "v", "tg", "vr", "x", "vp", "m", "a", "jp", "toy", "vg", "hc", "hm", "hr", "i", "ic", "n", "news", "o", "out", "p", "po", "pw", "qst", "r9k", "s", "s4s", "soc", "t", "trv", "u", "vip", "vm", "vmg", "vrpg", "vst", "vt", "w", "wg", "wsg", "wsr", "xs", "y", "aco", "adv", "an", "asp", "biz", "c", "cgl", "cm", "d", "diy", "fa", "gd", "h"];
    
    
end


function threads = loadthreads(name)
    lines = readlines(name);
    nlines = length(lines);

   
    
    B = boards();
    threads = {};
    for i = 1: length(lines)
        line = lines(i);
        line = strtrim(line);
        
        if line == ""
            continue
        end
        parts = split(line);
    
        %{
        #					       1             2         3        4          5             6     7       8          9       10       11         
			output_lines.append(f"{thread_name} {general} {length} {length_z} {length_zlog} {vel} {vel_z} {vel_zlog} {ratio} {avg_cl} {avg_cl_z} 
            {avg_cl_zlog} {len_mean} {len_mean_log} {vel_mean} {vel_mean_log} {len_mean_c} {len_mean_log_c} {vel_mean_c} {vel_mean_log_c} {board_avg_cl}")
			#12            13         14             15         16             17           18               19           20               21   
        %}
        threads(i).name = parts(1);
        
        threads(i).general = str2double(parts(2));
        threads(i).len = str2double(parts(3));
        threads(i).avg_words = str2double(parts(10));
        threads(i).avg_depth = str2double(parts(11));
        
        threads(i).vel = str2double(parts(4));
       
        threads(i).ratio = str2double(parts(5));
        threads(i).avg_cl = str2double(parts(6));
        threads(i).tp = threads(i).vel * threads(i).avg_cl;
        threads(i).nlinks = str2double(parts(7));
        threads(i).rdeg=str2double(parts(8))/threads(i).nlinks;
        threads(i).nq=str2double(parts(9));
        threads(i).avg_word_len = str2double(parts(12));
        lags=split(parts(13), " ");
        
        for j=1:200
            threads(i).timestamp(j)=str2double(parts(12+j));
        end
        
        disp(threads(i).name);
        parts = split(threads(i).name, "_");
        boardName = parts(1);
        boardIndex = 1;
        threads(i).index = int32(str2double(parts(2)));
        for j = 1: length(B)
            if boardName == B(j)
                boardIndex = j;
            end
        end
        threads(i).board = boardIndex;
        
        threads(i).boardname =  boardName;
        threads(i).len_log = log(threads(i).len);
        threads(i).vel_log = log(threads(i).vel);
        threads(i).avg_cl_log = log(threads(i).avg_cl);
        threads(i).tp_log = log(threads(i).tp)
        
        
    end

    threads = threads([threads.ratio] < 0.05);
    
    
end


function threads = processThreads(threads)
    B = boards();
    smin = 2; smax = floor(200 / 4); lmax = floor(200 / 2);

    [cur, curAll] = crossParse(threads, smin, smax);  
    [cur, curAll] = crossStat(cur, curAll, smin, smax);
    [cur, curAll] = cosineLag(cur, curAll, lmax);

    for i = 1:length(cur)
        
        power=cur(i).power;
        threads(i).l_bar = cur(i).wtdMean;
        threads(i).b_linear = -cur(i).exp2;
        threads(i).c_bar = mean(cur(i).wtdPatch);
        threads(i).diff=power;
        threads(i).b_pow=power.b;
        
        threads(i).ms_range=cur(i).power(1)-cur(i).power(100);
        threads(i).peak=cur(i).peak;
        threads(i).wtdPatch=cur(i).wtdPatch;
        threads(i).lag=cur(i).lag;
        threads(i).power=power;
        
        tot=0;
        for j=1:100
            tot = tot + cur(i).power(j);
        end
        threads(i).avg_ms = tot/100;
        threads(i).ipi = 1/(threads(i).vel); %minutes between posts
        threads(i).ipi_log=log(threads(i).ipi);
        threads(i).tcorr=cur(i).tcorr;
        
    end
end

function m = to_table(agents)
    m = table('Size', [numel(agents) 14], ...
    'VariableTypes', {'string','int32','double','double','double','double','double','double','double','double','double','double','double','int32'}, ...
    'VariableNames', {'board_name', 'board_index', 'len', 'ipi', 'ipi_log', 'avg_cl', 'c_bar', 'l_bar', 'b', 'b_pow2', 'b_linear', 'avg_ms', 'board', 'general'});
    for i=1: numel(agents)
        m.board_name(i) = agents(i).boardname;
        m.board_index(i) = agents(i).index;
        m.ipi_log(i) = agents(i).ipi_log;
        m.avg_cl(i) = agents(i).avg_cl;
        m.c_bar(i) = agents(i).c_bar;
        m.l_bar(i) = agents(i).l_bar;
        m.b_pow(i) = -agents(i).b_pow;
        m.b_pow2(i) = 2^(-agents(i).b_pow);
        m.b_linear(i) = agents(i).b_linear;
        m.avg_ms(i) = agents(i).avg_ms;
        m.board(i) = agents(i).board;
        m.general(i)=agents(i).general;
        m.len(i)=agents(i).len;
        m.ipi(i)=agents(i).ipi;
    end
end


function [wtd, f] = avg_curves(agents, nq, iv)

    nRuns = 1;
    lower = 1;
    upper = 200;

    smin = 2;
    smax = floor(upper / 4);
    lmax = floor(upper / 2);

    v = [agents.vel];

    if nargin > 2
        if iv == "vel"
            v = [agents.vel];
        end
    end

    p = linspace(0,1,nq+1);
    q = quantile(v,p);

    bins = discretize(v,q);

    wtd = cell(1,nq);
    f = cell(1,nq);

    for i = 1:nq
        
        binThreads = agents(bins == i);
        wtdz=zeros(numel(binThreads), 49);
        lagz=zeros(numel(binThreads), 100);
        for j=1: numel(binThreads)
            wtdz(j, :)=binThreads(j).wtdPatch;
            lagz(j, :)=binThreads(j).lag;
           
        end
        
        wtd{i} = mean(wtdz, 1);
        f{i} = fit([1:100]', mean(lagz, 1)', 'power2');

    end

end

function [genWtd, genF, nongenWtd, nongenF] = plotMatchedGen(allThreads)
    valid = ~isnan([allThreads.vel_log]) & ~isnan([allThreads.general]);
    % Original row indices for the two classes
    rows0 = find(valid & [allThreads.general] == 0);
    rows1 = find(valid & [allThreads.general] == 1);
    x0 = [allThreads(rows0).vel_log];
    x1 = [allThreads(rows1).vel_log];
    % Pairwise distance in x
    % C(i,j) = difference between class-0 observation i
    %          and class-1 observation j
    caliper = 0.1;
    C = abs(x0' - x1);
    pairs = matchpairs(C, caliper);
    % Convert pair indices back to rows of the original table
    matchedRows0 = rows0(pairs(:,1));
    matchedRows1 = rows1(pairs(:,2));
    % Two matched tables
    nongen = allThreads(matchedRows0);
    gen = allThreads(matchedRows1);
    
    [genWtd, genF] = loadwtd(gen, 1, "vel_log");
    [nongenWtd, nongenF] = loadwtd(nongen, 1, "vel_log");
    
end

function [lowWtd, lowF, highWtd, highF] = plotMatchedVel(allThreads)
    valid = ~isnan([allThreads.vel]) & ~isnan([allThreads.general]);
    % Original row indices for the two classes
    med = median([allThreads.vel]);
    rows0 = find(valid & [allThreads.vel] < med);
    rows1 = find(valid & [allThreads.vel] >= med);
    x0 = [allThreads(rows0).avg_cl];
    x1 = [allThreads(rows1).avg_cl];
    % Pairwise distance in x
    % C(i,j) = difference between class-0 observation i
    %          and class-1 observation j
    caliper = 1;
    C = abs(x0' - x1);
    pairs = matchpairs(C, caliper);
    % Convert pair indices back to rows of the original table
    matchedRows0 = rows0(pairs(:,1));
    matchedRows1 = rows1(pairs(:,2));
    % Two matched tables
    low = allThreads(matchedRows0);
    high = allThreads(matchedRows1);

    lower = 1;
    upper = 200;

    smin = 2;
    smax = floor(upper / 4);
    lmax = floor(upper / 2);

    [cur, curAll] = crossParse(low, smin, smax, lower, upper);
    [cur, curAll] = crossStat(cur, curAll, smin, smax);
    [cur, curAll] = cosineLag(cur, curAll, lmax, lower, upper);

    lowWtd = curAll.wtd;
    lowF = curAll.fitobj;

    [cur1, curAll1] = crossParse(high, smin, smax, lower, upper);
    [cur1, curAll1] = crossStat(cur1, curAll1, smin, smax);
    [cur1, curAll1] = cosineLag(cur1, curAll1, lmax, lower, upper);
    highWtd = curAll1.wtd;
    highF = curAll1.fitobj;
    
    
end

function [lowWtd, lowF, highWtd, highF] = plotMatchedAvgCl(allThreads)
    valid = ~isnan([allThreads.vel_log]) & ~isnan([allThreads.general]);
    % Original row indices for the two classes
    med = median([allThreads.avg_cl_log]);
    rows0 = find(valid & [allThreads.avg_cl_log] < med);
    rows1 = find(valid & [allThreads.avg_cl_log] >= med);
    x0 = [allThreads(rows0).vel_log];
    x1 = [allThreads(rows1).vel_log];
    % Pairwise distance in x
    % C(i,j) = difference between class-0 observation i
    %          and class-1 observation j
    caliper = 0.1;
    C = abs(x0' - x1);
    pairs = matchpairs(C, caliper);
    % Convert pair indices back to rows of the original table
    matchedRows0 = rows0(pairs(:,1));
    matchedRows1 = rows1(pairs(:,2));
    % Two matched tables
    low = allThreads(matchedRows0);
    high = allThreads(matchedRows1);
    
    [lowWtd, lowF] = loadwtd(low, 1, "vel");
    [highWtd, highF] = loadwtd(high, 1, "vel");
    
end

function [genWtd, genF, nongenWtd, nongenF] = plotMatched2(S)
    % Extract fields as numeric vectors
    class = [S.general]';
    x = [S.vel_log]';
    y = [S.avg_cl_log]';
    
    % Valid observations
    valid = ~isnan(x) & ~isnan(y) & ~isnan(class);
    
    rows0 = find(valid & class == 0);
    rows1 = find(valid & class == 1);
    
    % Standardize x and y across all valid observations
    X = [x(valid), y(valid)];
    
    mu = mean(X, 1);
    sigma = std(X, [], 1);
    
    Z = (X - mu) ./ sigma;
    
    % Put standardized values back into full-sized array
    Zall = nan(numel(S), 2);
    Zall(valid,:) = Z;
    
    Z0 = Zall(rows0,:);
    Z1 = Zall(rows1,:);
    
    % Pairwise distance based on both variables
    C = pdist2(Z0, Z1);
    
    % Optional hard caliper
    caliper = 0.1;
    C(C > caliper) = Inf;
    
    % Optimal one-to-one matching
    pairs = matchpairs(C, caliper);
    
    % Indices into original struct array
    matchedRows0 = rows0(pairs(:,1));
    matchedRows1 = rows1(pairs(:,2));
    
    % Matched structs
    nongen = S(matchedRows0);
    gen = S(matchedRows1);
    
    [genWtd, genF] = loadwtd(gen, 1, "vel");
    [nongenWtd, nongenF] = loadwtd(nongen, 1, "vel");
end

function [lowWtd, lowF, highWtd, highF] = plotMatched3(S)
    % Extract fields as numeric vectors
    class = [S.vel_log]';
    med = median(class);
    x = [S.len_log]';
    y = [S.avg_cl_log]';
    
    % Valid observations
    valid = ~isnan(x) & ~isnan(y) & ~isnan(class);
    
    rows0 = find(valid & class < med);
    rows1 = find(valid & class >= med);
    
    % Standardize x and y across all valid observations
    X = [x(valid), y(valid)];
    
    mu = mean(X, 1);
    sigma = std(X, [], 1);
    
    Z = (X - mu) ./ sigma;
    
    % Put standardized values back into full-sized array
    Zall = nan(numel(S), 2);
    Zall(valid,:) = Z;
    
    Z0 = Zall(rows0,:);
    Z1 = Zall(rows1,:);
    
    % Pairwise distance based on both variables
    C = pdist2(Z0, Z1);
    
    % Optional hard caliper
    caliper = 0.1;
    C(C > caliper) = Inf;
    
    % Optimal one-to-one matching
    pairs = matchpairs(C, caliper);
    
    % Indices into original struct array
    matchedRows0 = rows0(pairs(:,1));
    matchedRows1 = rows1(pairs(:,2));
    
    % Matched structs
    low = S(matchedRows0);
    high = S(matchedRows1);
    
    [lowWtd, lowF] = loadwtd(low, 1, "vel");
    [highWtd, highF] = loadwtd(high, 1, "vel");
end

function plotBoardBVel(agents)

    hold on;
    u = unique([agents.board]);
    bo = [u];
    vels=zeros(1,length(u));
    
    for i =1 : length(bo)
        threads=agents([agents.board]==bo(i));
        vels(i)=mean([threads.vel_log]);
    end
    
    % Sort selected boards by velocity
    [vels, vidx] = sort(vels, 'ascend');

    bo    = bo(vidx)
    

    blue = [0 0.4470 0.7410 0.3]
    orange = [0.8500 0.3250 0.098 0.3]
    blue_bold = [0 0.4470 0.7410]
    orange_bold = [0.8500 0.3250 0.098]
    
    colors=summer(3);
    lags=zeros(length(bo), 100);
    for b=1:length(bo)
        threads=agents([agents.board]==bo(b));
        board_lags=zeros(1,100);
        for j=1:length(threads)
            board_lags=board_lags+threads(j).lag;
        end
        lags(b, :)=board_lags/length(threads);
    end

    low=lags(1:27,:); high=lags(28:54,:);
    lowb=zeros(3,100); highb=zeros(3, 100);
    for i=1:100
        pdlow=fitdist(low(:,i), "Normal"); cilow=paramci(pdlow);
        
        pdhigh=fitdist(high(:,i), "Normal"); cihigh=paramci(pdhigh);
        lowb(1, i)=cilow(1,1); lowb(2, i)=(cilow(1,1)+cilow(2,1))/2; lowb(3, i)=cilow(2, 1);
        
        highb(1, i)=cihigh(1,1); highb(2, i)=(cihigh(1,1)+cihigh(2,1))/2; highb(3, i)=cihigh(2, 1);
    end

    x = 1:100;

    % General CI
    fill([x fliplr(x)], ...
         [lowb(1,:) fliplr(lowb(3,:))], ...
         colors(1, :), ...
         'FaceAlpha', 0.19, ...
         'EdgeColor', 'none');
    hold on
    
    
    

    fill([x fliplr(x)], ...
         [highb(1,:) fliplr(highb(3,:))], ...
         colors(2, :), ...
         'FaceAlpha', 0.19, ...
         'EdgeColor', 'none');

    
    low=plot(lowb(2, :), 'Color', colors(1, :), 'LineWidth', 2);
   
    high=plot(highb(2, :), 'Color', colors(2, :), 'LineWidth', 2);

    legend([low high], "High IPI", "Low IPI")
    xlabel("Lag")
    ylabel("Similarity")
    hold off;
end

function plotBoardWtdVel(agents)

    hold on;
    u = unique([agents.board]);
    bo = [u];
    vels=zeros(1,length(u));
    
    for i =1 : length(bo)
        threads=agents([agents.board]==bo(i));
        vels(i)=mean([threads.vel_log]);
    end
    
    % Sort selected boards by velocity
    [vels, vidx] = sort(vels, 'ascend');

    bo    = bo(vidx)
    

    blue = [0 0.4470 0.7410 0.3]
    orange = [0.8500 0.3250 0.098 0.3]
    blue_bold = [0 0.4470 0.7410]
    orange_bold = [0.8500 0.3250 0.098]
    
    colors=summer(3);
    lags=zeros(length(bo), 49);
    for b=1:length(bo)
        threads=agents([agents.board]==bo(b));
        board_lags=zeros(1,49);
        for j=1:length(threads)
            board_lags=board_lags+threads(j).wtdPatch;
        end
        lags(b, :)=board_lags/length(threads);
    end

    low=lags(1:27,:); high=lags(28:54,:);
    lowb=zeros(3,49); highb=zeros(3, 49);
    for i=1:49
        pdlow=fitdist(low(:,i), "Normal"); cilow=paramci(pdlow);
       
        pdhigh=fitdist(high(:,i), "Normal"); cihigh=paramci(pdhigh);
        lowb(1, i)=cilow(1,1); lowb(2, i)=(cilow(1,1)+cilow(2,1))/2; lowb(3, i)=cilow(2, 1);
        
        highb(1, i)=cihigh(1,1); highb(2, i)=(cihigh(1,1)+cihigh(2,1))/2; highb(3, i)=cihigh(2, 1);
    end

    x = 1:49;

    % General CI
    fill([x fliplr(x)], ...
         [lowb(1,:) fliplr(lowb(3,:))], ...
         colors(1, :), ...
         'FaceAlpha', 0.2, ...
         'EdgeColor', 'none');
    hold on
    low=plot(lowb(2, :), 'Color', colors(1, :), 'LineWidth', 2);
    

    fill([x fliplr(x)], ...
         [highb(1,:) fliplr(highb(3,:))], ...
         colors(2, :), ...
         'FaceAlpha', 0.2, ...
         'EdgeColor', 'none');

    
    
    high=plot(highb(2, :), 'Color', colors(2, :), 'LineWidth', 2);
    
    legend([low high], "High IPI", "Low IPI")
    xlabel("Filter size (l)")
    ylabel("Cluster strength (C(l))")
    hold off;
end

function plotBoardBGen(agents)
    hold on;

    bo = unique([agents.board]);

    blue = [0 0.4470 0.7410 0.3];
    orange = [0.8500 0.3250 0.098 0.3];
    blue_bold = [0 0.4470 0.7410];
    orange_bold = [0.8500 0.3250 0.098];
    
    all_gen=zeros(length(bo), 100);
    all_top=zeros(length(bo), 100);
    
    has=zeros(length(bo), 2);
    for b = 1:length(bo)

        boardThreads = agents([agents.board] == bo(b));
        
        gen = boardThreads([boardThreads.general] == 1);
        nongen = boardThreads([boardThreads.general] == 0);
        
        if ~isempty(gen)
            has(b, 1) = 1;
            acc=zeros(1,100);
            for i=1:numel(gen)
                
                acc = acc + gen(i).lag;
                
            end
            all_gen(b, :) = acc/numel(gen);
        end

        if ~isempty(nongen)
            has(b, 2) = 1;
            acc=zeros(1,100);
            for i=1:numel(nongen)
                acc = acc + nongen(i).lag;
            end
            all_top(b, :) = acc/numel(nongen);
        end

        
    end
    
    all_gen=all_gen(has(:, 1)==1,:);
    all_top=all_top(has(:, 2)==1,:);
    
    gen_bounds=zeros(3, 100);
    top_bounds=zeros(3, 100);
    
    for i=1:100
        stdeg=std(all_gen(:, i))/sqrt(size(all_gen,1));
        stdet=std(all_top(:,i))/sqrt(size(all_top,1));
        meang=mean(all_gen(:,i));
        meant=mean(all_top(:,i));
        intg=tinv(0.975, size(all_gen, 1))*stdeg;
        intt=tinv(0.975, size(all_top, 1))*stdet;
        gen_bounds(1, i)=meang-intg;
        gen_bounds(2, i)=meang;
        gen_bounds(3, i)=meang+intg;
        top_bounds(1, i)=meant-intt;
        top_bounds(2, i)=meant;
        top_bounds(3, i)=meant+intt;
    end
    
    x = 1:100;

    % General CI
    fill([x fliplr(x)], ...
         [gen_bounds(1,:) fliplr(gen_bounds(3,:))], ...
         [0 0.4470 0.7410], ...
         'FaceAlpha', 0.2, ...
         'EdgeColor', 'none');
    hold on
    
    % Topical CI
    fill([x fliplr(x)], ...
         [top_bounds(1,:) fliplr(top_bounds(3,:))], ...
         [0.8500 0.3250 0.0980], ...
         'FaceAlpha', 0.2, ...
         'EdgeColor', 'none');
    gen=plot(gen_bounds(2, :), 'Color', blue_bold, 'LineWidth', 2);
    top=plot(top_bounds(2, :), 'Color', orange_bold, 'LineWidth', 2);

    legend([gen top], {'General', 'Topical'});
    xlabel("Lag");
    ylabel("Similarity");
  
    hold off;
end

function plotBoardWtdGen(agents)

    hold on;

    bo = unique([agents.board]);

    blue =        [0      0.4470 0.7410 0.3]
    orange =      [0.8500 0.3250 0.098  0.3]
    blue_bold =   [0      0.4470 0.7410    ]
    orange_bold = [0.8500 0.3250 0.098     ]

    all_gen=zeros(length(bo), 49);
    all_top=zeros(length(bo), 49);
    
    has=zeros(length(bo), 2);
    for b = 1:length(bo)

        boardThreads = agents([agents.board] == bo(b));
        
        gen = boardThreads([boardThreads.general] == 1);
        nongen = boardThreads([boardThreads.general] == 0);
        
        if ~isempty(gen)
            has(b, 1)=1;
            [wtdgen, ~] = avg_curves(gen,1,"vel");
            all_gen(b,:)=wtdgen{1};
        end

        if ~isempty(nongen)
            has(b,2)=1;
            [wtdnongen,~] = avg_curves(nongen,1,"vel");
            all_top(b,:)=wtdnongen{1};
        end
    end

    all_gen=all_gen(has(:, 1)==1,:);
    all_top=all_top(has(:, 2)==1,:);
    
    gen_bounds=zeros(3, 49);
    top_bounds=zeros(3, 49);
    
    for i=1:49
        stdeg=std(all_gen(:, i))/sqrt(size(all_gen,1));
        stdet=std(all_top(:,i))/sqrt(size(all_top,1));
        meang=mean(all_gen(:,i));
        meant=mean(all_top(:,i));
        intg=tinv(0.975, size(all_gen, 1))*stdeg;
        intt=tinv(0.975, size(all_top, 1))*stdet;
        gen_bounds(1, i)=meang-intg;
        gen_bounds(2, i)=meang;
        gen_bounds(3, i)=meang+intg;
        top_bounds(1, i)=meant-intt;
        top_bounds(2, i)=meant;
        top_bounds(3, i)=meant+intt;
    end
    
    x = 1:49;

    % General CI
    fill([x fliplr(x)], ...
         [gen_bounds(1,:) fliplr(gen_bounds(3,:))], ...
         [0 0.4470 0.7410], ...
         'FaceAlpha', 0.2, ...
         'EdgeColor', 'none');
    hold on
    
    % Topical CI
    fill([x fliplr(x)], ...
         [top_bounds(1,:) fliplr(top_bounds(3,:))], ...
         [0.8500 0.3250 0.0980], ...
         'FaceAlpha', 0.2, ...
         'EdgeColor', 'none');
    gen=plot(gen_bounds(2, :), 'Color', blue_bold, 'LineWidth', 2);
    top=plot(top_bounds(2, :), 'Color', orange_bold, 'LineWidth', 2);
    

    legend([gen top], {'General', 'Topical'});
    xlabel("Filter size (l)")
    ylabel("Cluster strength (C(l))")
    
    hold off;
end



%      1     2     3      4    5      6      7    8       9      10     11    12     13     14    15    16   17    18    19   20    21   22   23    24
%b = ["ck", "co", "fit", "g", "his", "int", "k", "lgbt", "lit", "mlp", "mu", "pol", "sci", "sp", "tv", "v", "tg", "vr", "x", "vp", "m", "a", "jp", "toy", "vg"];

allThreads200 = loadthreads('all.txt');
r=zeros(1, numel(allThreads200));

all_agents = processThreads(allThreads200);
all1=to_table(all_agents);

x = [all_agents.avg_ms];
mu = mean(x, 'omitnan');
sigma = std(x, 'omitnan');
idx = x < mu - 4*sigma | x > mu + 4*sigma;
sum(idx)              % number flagged
r = r | idx;

x = [all_agents.ipi_log];
mu = mean(x, 'omitnan');
sigma = std(x, 'omitnan');
idx = x < mu - 4*sigma | x > mu + 4*sigma;
sum(idx)              % number flagged
r = r | idx;

x = [all_agents.avg_cl];
mu = mean(x, 'omitnan');
sigma = std(x, 'omitnan');
idx = x < mu - 4*sigma | x > mu + 4*sigma;
sum(idx)              % number flagged
r = r | idx;

x = [all_agents.c_bar];
mu = mean(x, 'omitnan');
sigma = std(x, 'omitnan');
idx = x < mu - 4*sigma | x > mu + 4*sigma;
sum(idx)              % number flagged
r = r | idx;

x = [all_agents.l_bar];
mu = mean(x, 'omitnan');
sigma = std(x, 'omitnan');
idx = x < mu - 4*sigma | x > mu + 4*sigma;
sum(idx)              % number flagged
r = r | idx;

x = [all_agents.len];
mu = mean(x, 'omitnan');
sigma = std(x, 'omitnan');
idx = x < mu - 4*sigma | x > mu + 4*sigma;
sum(idx)              % number flagged
r = r | idx;

for i=1:numel(all_agents)
    all_agents(i).b_pow2=2^(-all_agents(i).b_pow);
end
x = [all_agents.b_pow2];
mu = mean(x, 'omitnan');
sigma = std(x, 'omitnan');
idx = x < mu - 4*sigma | x > mu + 4*sigma;
sum(idx)              % number flagged
r = r | idx;

all_clean=all_agents(~r);
all=to_table(all_clean);

%[nest, nest_lag, nest_agent] =  processThreads(allThreads200,200);

%}