% parseSummary.m
% Reads and parses the xls file for RUN_preproccess.m

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% The file is expected to have to the following structure:
% 	column 1: subject codes
%	column 2: run codes
% 	column 3: anatomy file for each run
% 	column 4: the tr for each run
%	column 5: the number of slices for each run
%   column 6: session number
%
% The file may include several parameters prior to the subject variables
% including:
%   - dicom directory <tab> <full path>
%   - slice order <tab> <list of slice order "1, 3, 2,..."
%   - spatial smoothing <tab> <scalar>
%   - batches <tab> <b1> <tab> <b2> ...
%
% Note:
%   Each paramater must begin a new line be separated by its value via
%   a tab <\t> (ie "<parameter name>\t<value>\n"
%
% The file may also have a line with the following headers from column
% 1-6:
%
% subject_code | run_name | anatomy | tr | nslices | sess#
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function [subjectVariables, sessionVariables, batches] = parseSummary(tsvFile)

fid = fopen(tsvFile);
tLine = readLine(fid);

validBatches = {'import','anatomy','slice_time','realign', 'coregister','BV'};

foundDicomDir = false;
foundSliceOrder = false;
foundSpatialSmoothing = false;
foundBatches = false;

while(~isempty(tLine))
    switch tLine{1}
        
        case 'dicom directory'
            % The first line may include the directory of the DICOM files
            
            sessionVariables.dicomDir = tLine{1,2};
            fprintf('Using dicom directory: %s\n', sessionVariables.dicomDir)
            foundDicomDir = true;
            % If the directory is not included, ask the user
            
        case 'slice order'
            % Check for slice order
            sessionVariables.sliceOrder = str2num(tLine{2});
            fprintf('Using slice order: %s\n', tLine{2})
            foundSliceOrder = true;
            
        case 'spatial smoothing'
            % Check for spacial smoothing
            sessionVariables.spatialSmoothing = str2num(tLine{2});
            fprintf('Using spatial smoothing: %d\n', ...
                sessionVariables.spatialSmoothing)
            foundSpatialSmoothing = true;
            
        case 'subject_code'
            % See if the heading is included
            headers = {'subject_code', 'run_name', 'anatomy', ...
                'tr', 'nslices', 'sess#'};
            try
                headerCheck = strcmp(tLine(1:6), headers);
            catch
                error('The headers in %s are not compatible with this script,'+ ...
                    'please see the instructions\n' , tsvFile)
            end
            
            if headerCheck
                fprintf('Headers are included\n')
            end
            
        case 'batches'
            % Check for specific batches
            
            for b = tLine(2:end)
                if sum(strcmp(b{1}, validBatches))~= 1
                    s = repmat('%s ', 1, length(validBatches));
                    error(['Given batch %s is not a member of the valid batches' + ...
                        s], b{1}, validBatches{:})
                end
            end
            batches = tLine(2:end);
            foundBatches = true;
            s = repmat('%s ', 1, length(tLine(2:end)));
            fprintf(strcat('Will run batches: ', s,'\n'), tLine{2:end})
            
        otherwise
            % The remaining data should be subject variables
            subjectVariables = vertcat(tLine, readRest(fid));
    end
    tLine = readLine(fid);
end
fclose(fid);

if ~foundDicomDir
    sessionVariables.dicomDir = askDicomDir();
end

if ~foundSliceOrder
    sessionVariables.sliceOrder = askSliceOrder();
end

if ~foundSpatialSmoothing
    sessionVariables.spatialSmoothing = askSpatialSmoothing();
end

if ~foundBatches
    fprintf('Did not find batches, using defaults\n')
    batches = validBatches;
end
end


function [line] = readLine(fid)
tLine = fgetl(fid);
if ischar(tLine)
    line = strsplit(tLine, '\t');
    %Check to make sure there is no random empty tab
    if strcmp(line{end}, '')
        line = line(1:end-1);
    end
else
    line = {};
end
end

function [lines] = readRest(fid)
bin = {};
tLine = readLine(fid);
while ~isempty(tLine)
    bin = vertcat(bin, tLine);
    tLine = readLine(fid);
end
lines = bin;
end

function [d] = askDicomDir()

fprintf('Found no line containing "dicom directory"\n')
ask = 'No dicom directory was found, please enter path';
answer = inputdlg(ask);
if isempty(answer)
    error('User did not enter valid directory')
elseif strcmp(answer{1}, '')
    error('User did not enter valid directory')
else
    dirCheck = dir(answer{1});
    dirStatus = sum(cell2mat(~cellfun('isempty', {dirCheck.date})));
    
    if dirStatus == 0
        error('User entered an empty directory')
    else
        d = answer{1};
    end
end
end

function [so] = askSliceOrder()
fprintf('Found no line containing "slice order"\n')
ask = 'No slice order was found, please enter list in the from: 1,2,3...';
answer = inputdlg(ask);
if isempty(answer)
    error('User did not enter valid slice order')
elseif strcmp(answer{1}, '')
    error('User did not enter valid slice order')
else
    try
        so = str2num(answer{1});
    catch
        error('Was not able to read slice order');
    end
    
end
end

function [sm] = askSpatialSmoothing()
fprintf('Found no line containing "spatial smoothing"\n')
ask = 'No spatial smoothing was found, please enter scalar';
answer = inputdlg(ask);
if isempty(answer)
    error('User did not enter valid spatial smoothing')
elseif strcmp(answer{1}, '')
    error('User did not enter valid spatial smoothing')
else
    try
        sm = str2num(answer{1});
    catch
        error('Was not able to read spatial smoothing');
    end
    if length(sm) > 1
        error('Only one scalar is used (smoothing = [s,s,s])')
    end
    
end

end










