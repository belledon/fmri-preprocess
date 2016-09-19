% prepareRuns.m

function [subject] = prepareRuns(subjectVariables, sessionVariables)


subjectNames = subjectVariables(:, 1);
subjectRuns = subjectVariables(:, 2);
subjectAnatomy = subjectVariables(:, 3);
subjectTr = subjectVariables(:, 4);
subjectSlices = subjectVariables(:, 5);
subjectSessions = cell2int(subjectVariables(:, 6));

[uniqueSubjects, ~, subjectInds] = unique(subjectNames);

subject = struct();

for ind = 1:length(uniqueSubjects)
    
    subject(ind).name = uniqueSubjects{ind};
    subject(ind).passed = false;
    
    subInds = ind == subjectInds;
    [listedSessions, ~, sessionInds] = unique(subjectSessions(subInds));
    numListedSessions = length(listedSessions);
    
    subject(ind).path = fullfile(sessionVariables.dicomDir, subject(ind).name);
    
    if isempty(dir(subject(ind).path))
        fprintf('Subject %s is does not have data in %s, skipping\n',...
            subject(ind).name,subject(ind).path)
        
        continue
        
    else
        sessionCheck = checkPaths({subject(ind).path});
        numFoundSessions = sum(sessionCheck);
        fprintf('Subject %s has %d sessions in %s\n', ...
            subject(ind).name, numFoundSessions, subject(ind).path)
    end
    
    
    % Begin iterating through each session
    
    for sess = 1:numListedSessions
               
        subject(ind).session(sess).name = listedSessions(sess);
        subject(ind).session(sess).path = fullfile(subject(ind).path,...
            strcat('Session', num2str(subject(ind).session(sess).name)));
        
        if ~sessionCheck(sess)
            fprintf('Subject %s has no data for session: %s, skipping\n',...
            subject(ind).name, subject(ind).session(sess).path)
            
        else
            
            sessInds = subInds & (sess == subjectSessions);
            listedSessRuns = subjectRuns(sessInds);
            numListedRuns = length(listedSessRuns);
            listedAnatomy = subjectAnatomy(sessInds);
            listedTRs = subjectTr(sessInds);
            listedSlices = subjectSlices(sessInds);
            
            % Check to see if system contains this session and runs
            fullListedSRuns = buildPaths(subject(ind).session(sess).path,...
           		listedSessRuns);
            sessRunCheck = checkPaths(fullListedSRuns) & ...
                exlcudeRuns(listedSessRuns, 'rest');
            
            for r = 1:numListedRuns
                
                runName = listedSessRuns{r};
                runPath = fullfile(subject(ind).session(sess).path, runName);
                
                if ~sessRunCheck(r)
                    
                    fprintf('Could not find run %s for subject %s in path %s\n', ...
                        runName, subject(ind).name, runPath)
                end
            end
            
            if sum(sessRunCheck > 0)
                
            	fullListedAnatomy = buildPaths(subject(ind).session(sess).path,...
            		listedAnatomy);

                subject(ind).session(sess).runs = fullListedSRuns(sessRunCheck);
                subject(ind).session(sess).anatomy = fullListedAnatomy(sessRunCheck);
                subject(ind).session(sess).trs = cell2double(listedTRs(sessRunCheck));
                subject(ind).session(sess).slices = cell2int(listedSlices(sessRunCheck));
                
                % Check to see if the number of slices matches the slice
                % order given
               
                if (subject(ind).session(sess).slices(1) == length(sessionVariables.sliceOrder))
                    subject(ind).passed = true;
                    subject(ind).session(sess).vars = sessionVariables;
                    
                else
                    fprintf('Subject %s had %d slices but slice order account for %d\n',...
                        subject(ind).name, subject(ind).session(sess).slices(1), ...
                        length(sessionVariables.sliceOrder))
                end
            end
        end
        
        
    end
end
subject = pruneSubjects(subject);
end

function [l] = checkPaths(paths)
nPs = length(paths);
l = false(nPs, 1);
for i = 1:nPs
    l(i) = ~isempty(dir(paths{i}));
end
end

function [l] = exlcudeRuns(runs, sub)
nRs = length(runs);
l = false(nRs, 1);
for i = 1:nRs
    l(i) = isempty(strfind(runs{i}, sub));
    if ~l(i)
        fprintf('Excluded run %s for containg %s\n', ...
            runs{i}, sub)
    end
end
end

function [i] = cell2int(cs)
    i = int8(cell2double(cs));
end

function [d] = cell2double(cs)
    d = zeros(size(cs));
    for i = 1:length(cs)
        d(i, 1) = str2double(cs{i});
    end
end

function [ps] = buildPaths(a,b)
    ps = cell(size(b));
    for i = 1:length(b)
        ps{i} = fullfile(a,b{i});
    end
end

function [s] = pruneSubjects(a)

c = false(length(a),1);
for i = 1:length(a)
    c(i) = a(i).passed;
end
s = a(c);
end

