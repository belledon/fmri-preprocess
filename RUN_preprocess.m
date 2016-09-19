% RUN_preprocess.m
% These scripts were created from several developers, originating with Sami.



%% Prepare
function RUN_preprocess()

% Get summary location
ask = 'Please enter the path of the summary file';
summaryPath = inputdlg(ask, 'RUN_preprocess');

try
    summaryPath = summaryPath{1};
    [subjectVariables, sessionVariables, batches] = parseSummary(summaryPath);
    fprintf('Succesfully loaded %s', summaryPath)
catch
    fprintf('Could not load from the provided directory!\n -> %s\n', summaryPath);
    summaryPath = fullfile(cd, 'summary.tsv');
    fprintf('Attempting to load "summary.tsv" from default directory: %s\n', summaryPath)
    
    try
        [subjectVariables, sessionVariables, batches] = parseSummary(summaryPath);
        fprintf('Succesfully loaded %s\n', summaryPath)
    catch ME
        fprintf('Failed to also load %s \nAborting...\n', summaryPath)
        fprintf('Error was:\n%s\n', ME.message)
        error('Could not load any summary file')
    end
end


choice = questdlg('Save log?', 'RUN_preprocess', 'Yes', 'No', 'No');
switch choice
    case 'Yes'
        timestamp = int2str(clock);
        timeparts = strsplit(timestamp, ' ');
        log_filename = fullfile(cd, ['preprocess_', strjoin(timeparts, '_'), '.txt']);
        fprintf('The log file can be found in %s\n', log_filename)
        diary(log_filename)
    case 'No'
        fprintf('Console Output will not be saved\n')
end

t = cputime;
% Prepare subject variables
fprintf('Structuring subject variables...\n')
subjects = prepareRuns(subjectVariables, sessionVariables);
fprintf('Subject variables prepared!\n')

% Execute
fprintf('###################################################################\n')
numSubjects = length(subjects);
if numSubjects > 0
    fprintf('Will attempt to preprocess data of %d subjects\n', ...
        numSubjects)
    
    for subject = subjects
        
        
        for session = subject.session
            fprintf('Beginning subject %s session %d\n', ...
                subject.name, subject.session.name)
            for b = batches
                try
                    preprocess(session, b{1});
                catch ME
                    fprintf('The following error occured during subject %s session %d batch %s:\n',...
                        subject.name, subject.session.name, b{1})
                    fprintf('%s\n%s\n', ME.identifier, ME.message)
                    continue
                end
            end
            fprintf('Completed subject %s session %d\n',...
                subject.name, subject.session.name)
        end
    end
    fprintf('Complete!\n');
else
    fprintf('No subjects had viable data!\n');
end


if strcmp(choice, 'Yes')
    diary('off');
end


d = cputime - t;
m = sprintf('fMRI process is complete!\nTime Elapsed: %0.2g s', d);
msgbox(m, 'RUN_preprocess')
end



