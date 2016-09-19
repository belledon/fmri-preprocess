function [] = preprocess(session, subject_batch)
% 1) Load the dicoms to .img,.hdr.
% 2) Re-align and reslice all the functional runs together.
% 3) Re-align and reslice all the PA runs together.
% 4) Topup all runs.
% 5) Smooth
% 6) Translate to a .vtc
% Anatomical




subject_4D_dirname = fullfile(session.path,'..\4D');
subject_T1_dirname = fullfile(session.path,'..\T1');

no_subject_session_anatomy = isempty(dir(session.anatomy{1}));

spm_file_format = 'nii'; % img

if isempty(dir(subject_4D_dirname))
    mkdir(subject_4D_dirname)
end

if isempty(dir(subject_T1_dirname))
    mkdir(subject_T1_dirname)
end


switch subject_batch
    
    case 'import'
        % Import all the runs including the session anatomy
        all_runs_dir = [session.runs; session.anatomy(1)];
        
        
        matlabbatch = cell(length(all_runs_dir),1);
        
        for r=1:length(all_runs_dir)
            
            run_DICOM_path = all_runs_dir{r};
            run_DICOM_files = rdir(fullfile(run_DICOM_path,'*.dcm'));
            
            
            if isempty(run_DICOM_files)
                
                fprintf('Run:%s\nhad no .dcm files\n', run_DICOM_path);
                fprintf('Looking for compressed files...\n');
                run_comp_files_rar = rdir(fullfile(run_DICOM_path, '*.rar'));
                run_comp_files_zip = rdir(fullfile(run_DICOM_path, '*.zip'));
                
                if  isempty(run_comp_files_rar) && isempty(run_comp_files_zip)
                    fprintf('No .rar or .zip files found... skipping\n')
                    
                    
                else
                    
                    % The detected compressed file must be either a .rar or .zip
                    % Gives preference to .rar
                    
                    if ~isempty(run_comp_files_rar)
                        chosen = run_comp_files_rar{1};
                    else
                        chosen = run_comp_files_zip{1};
                    end
                    
                    fprintf('Found at least 1 file, extracting the first: \n %s\n',...
                        chosen);
                    extractFile(chosen, run_DICOM_path);
                    ex_check = rdir(fullfile(run_DICOM_path, '*.dcm'));
                    
                    % Check to see if uncompression was successfull
                    
                    if isempty(ex_check)
                        
                        error('Could not extract %s', chosen);
                    else
                        [~, chosenName, ext] = fileparts(chosen);
                        movefile(chosen, fullfile(run_DICOM_path, ...
                            ['extracted_', chosenName, ext]));
                        run_DICOM_files = ex_check;
                    end
                end
            end
            
            run_output_dir_formatted = {run_DICOM_path};
            
            matlabbatch{r}.spm.util.import.dicom.data = run_DICOM_files;
            matlabbatch{r}.spm.util.import.dicom.root = 'flat';
            matlabbatch{r}.spm.util.import.dicom.outdir = run_output_dir_formatted;
            matlabbatch{r}.spm.util.import.dicom.protfilter = '.*';
            matlabbatch{r}.spm.util.import.dicom.convopts.format = spm_file_format;
            matlabbatch{r}.spm.util.import.dicom.convopts.icedims = 0;
        end
        
        spm('defaults', 'FMRI');
        spm_jobman('initcfg');
        spm_jobman('run', matlabbatch);
 
    case 'anatomy'
        
        
        if no_subject_session_anatomy
            fprintf('No anatomy in %s\n',session.anatomy{1});
        else
            
            % Anatomy
            % anat_dir = dir(strcat(session_dirname,'S*t1mpr*'));
            anat_dir = session.anatomy{1};
            
            % IMPORTANT: THE ANATOMY .NII WILL HAVE THE PREFIX "s"
            anat_file = cellstr(rdir(fullfile(anat_dir,['s*.',spm_file_format])));
            
            % Question: Does the number of runs matter?
            nrun = 1; % enter the number of runs here
            jobfile = {fullfile(cd,'JOB_normalise_anatomy.m')}; %MARIO-change within this m file
            jobs = repmat(jobfile, 1, nrun);
            inputs = cell(1, nrun);
            for crun = 1:nrun
                inputs{1, crun} = cellstr(anat_file); % Normalise: Estimate: Data - cfg_repeat
                inputs{2, crun} = cellstr(anat_file); % Normalise: Estimate & Write: Images to Write - cfg_files
            end
            spm_jobman('initcfg');
            spm('defaults', 'FMRI');
            spm_jobman('run', jobs, inputs{:});
            
        end
       
    case 'slice_time'
        
        % TODO: Include in gui
        %nslices = 69; %MARIO-change to 64: 69 for dysplasia data
        
        % Get a list of all runs
        func_path = session.runs;
        full_list_of_func = cell(length(func_path), 1);
        
        for r=1:length(func_path)
            run_func_path = func_path{r};
            run_func_files = rdir(fullfile(run_func_path,['f*.',spm_file_format]));
            if isempty(run_func_files)
                error(['No file \n ', ['f*', spm_file_format], '\n could be found in directory: %s'], ...
                    run_func_path);
            end
            full_list_of_func{r} = run_func_files;
        end
        
        matlabbatch = {};
        
        b = 1 ;
        matlabbatch{b}.spm.temporal.st.scans = full_list_of_func';
        matlabbatch{b}.spm.temporal.st.nslices = session.vars.slices(1);
        matlabbatch{b}.spm.temporal.st.tr = session_tr;
        matlabbatch{b}.spm.temporal.st.ta = 0;
        matlabbatch{b}.spm.temporal.st.so = session.vars.sliceOrder;%[0 990 82.5 1072.5 165 1155 247.5 1237.5 330 1320 412.5 1402.5 495 1485 577.5 1567.5 660 1650 742.5 1732.5 825 1815 907.5 0 990 82.5 1072.5 165 1155 247.5 1237.5 330 1320 412.5 1402.5 495 1485 577.5 1567.5 660 1650 742.5 1732.5 825 1815 907.5 0 990 82.5 1072.5 165 1155 247.5 1237.5 330 1320 412.5 1402.5 495 1485 577.5 1567.5 660 1650 742.5 1732.5 825 1815 907.5];% [1485	0	990	60	1050	123	1113	185	1175	248	1238	308	1298	370	1360	433	1423	555	1545	618	1608	680	1670	743	1733	803	1793	865	1855	928	1918	495	1485	0	990	60	1050	123	1113	185	1175	248	1238	308	1298	370	1360	433	1423	555	1545	618	1608	680	1670	743	1733	803	1793	865	1855	928	1918	495]; %MARIO-change to [1485	0	990	60	1050	123	1113	185	1175	248	1238	308	1298	370	1360	433	1423	555	1545	618	1608	680	1670	743	1733	803	1793	865	1855	928	1918	495	1485	0	990	60	1050	123	1113	185	1175	248	1238	308	1298	370	1360	433	1423	555	1545	618	1608	680	1670	743	1733	803	1793	865	1855	928	1918	495] for dysplasia data it is [0 990 82.5 1072.5 165 1155 247.5 1237.5 330 1320 412.5 1402.5 495 1485 577.5 1567.5 660 1650 742.5 1732.5 825 1815 907.5 0 990 82.5 1072.5 165 1155 247.5 1237.5 330 1320 412.5 1402.5 495 1485 577.5 1567.5 660 1650 742.5 1732.5 825 1815 907.5 0 990 82.5 1072.5 165 1155 247.5 1237.5 330 1320 412.5 1402.5 495 1485 577.5 1567.5 660 1650 742.5 1732.5 825 1815 907.5]
        matlabbatch{b}.spm.temporal.st.refslice = 0;
        matlabbatch{b}.spm.temporal.st.prefix = 'a';
        
        spm('defaults', 'FMRI');
        spm_jobman('initcfg');
        spm_jobman('run', matlabbatch);
        
    case 'realign'
        
        
        % Get a list of all runs
        func_dir = session.runs;
        
        full_list_of_func = cell(length(func_dir), 1);
        
        for r=1:length(func_dir)
            run_func_path = func_dir{r};
            run_func_files = rdir(fullfile(run_func_path,['af*.',spm_file_format]));
            
            full_list_of_func{r} = run_func_files;
        end
        
        
        matlabbatch = {};
        b = 1;
        
        matlabbatch{b}.spm.spatial.realign.estwrite.data = full_list_of_func';
        matlabbatch{b}.spm.spatial.realign.estwrite.eoptions.quality = 1;
        matlabbatch{b}.spm.spatial.realign.estwrite.eoptions.sep = 4;
        matlabbatch{b}.spm.spatial.realign.estwrite.eoptions.fwhm = 5;
        matlabbatch{b}.spm.spatial.realign.estwrite.eoptions.rtm = 1;
        matlabbatch{b}.spm.spatial.realign.estwrite.eoptions.interp = 2;
        matlabbatch{b}.spm.spatial.realign.estwrite.eoptions.wrap = [0 0 0];
        matlabbatch{b}.spm.spatial.realign.estwrite.eoptions.weight = '';
        matlabbatch{b}.spm.spatial.realign.estwrite.roptions.which = [0 1];
        matlabbatch{b}.spm.spatial.realign.estwrite.roptions.interp = 4;
        matlabbatch{b}.spm.spatial.realign.estwrite.roptions.wrap = [0 0 0];
        matlabbatch{b}.spm.spatial.realign.estwrite.roptions.mask = 1;
        matlabbatch{b}.spm.spatial.realign.estwrite.roptions.prefix = 'r';
        
        
        spm('defaults', 'FMRI');
        spm_jobman('initcfg');
        spm_jobman('run', matlabbatch);
        
    case 'coregister'
        
        % Get a list of all runs
        func_dir = session.runs;
        
        full_list_of_func = [];
        
        for r=1:length(func_dir)
            
            run_func_path = func_dir{r};
            run_func_files = rdir(fullfile(run_func_path,['af*.',spm_file_format]));
            full_list_of_func = [full_list_of_func; run_func_files];
            
            if (r==1)
                run_func_mean = rdir(fullfile(run_func_path,['meanaf*.',spm_file_format]));
            end
        end
        % TODO: Will need to ensure that this works for more than Session1
        % 		coreg_session1_dirname = session_dirname;
        coreg_session1_anatomy = session.anatomy{1};
        
        if (session.name == 1)
            anatomy_wildcard = 's*';
        else
            anatomy_wildcard = 'rs*';
        end
        
        anat_dir = session.anatomy{1};
        anat_file_full = rdir(fullfile(anat_dir, [anatomy_wildcard, '.', spm_file_format]));
       
        % Deformation file is always from Session1.
        anat_file_deformation_full= rdir(fullfile(coreg_session1_anatomy, 'y_s*.nii' ));
        
        batch_iter = 1;
        matlabbatch = {};
        
        matlabbatch{batch_iter}.spm.spatial.coreg.estimate.ref = cellstr(anat_file_full);
        matlabbatch{batch_iter}.spm.spatial.coreg.estimate.source = cellstr(run_func_mean);
        matlabbatch{batch_iter}.spm.spatial.coreg.estimate.other = full_list_of_func;
        matlabbatch{batch_iter}.spm.spatial.coreg.estimate.eoptions.cost_fun = 'nmi';
        matlabbatch{batch_iter}.spm.spatial.coreg.estimate.eoptions.sep = [4 2];
        matlabbatch{batch_iter}.spm.spatial.coreg.estimate.eoptions.tol = [0.02 0.02 0.02 0.001 0.001 0.001 0.01 0.01 0.01 0.001 0.001 0.001];
        matlabbatch{batch_iter}.spm.spatial.coreg.estimate.eoptions.fwhm = [7 7];
        batch_iter = batch_iter + 1;
        
        matlabbatch{batch_iter}.spm.spatial.normalise.write.subj.def = cellstr(anat_file_deformation_full);
        matlabbatch{batch_iter}.spm.spatial.normalise.write.subj.resample(1) = cfg_dep('Coregister: Estimate: Coregistered Images',...
            substruct('.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('.','cfiles'));
        matlabbatch{batch_iter}.spm.spatial.normalise.write.woptions.bb = [-78 -112 -70
            78 76 85];
        %matlabbatch{batch_iter}.spm.spatial.normalise.write.woptions.vox = [3 3 3];
        matlabbatch{batch_iter}.spm.spatial.normalise.write.woptions.vox = [2 2 2];
        matlabbatch{batch_iter}.spm.spatial.normalise.write.woptions.interp = 4;
        
        
        spm('defaults', 'FMRI');
        spm_jobman('initcfg');
        spm_jobman('run', matlabbatch);
       
    case 'smooth'
        
        % Get a list of all runs
        func_dir = session.runs;
        
        matlabbatch = cell(length(func_dir),1);
        
        for r=1:length(func_dir)
            run_func_path = func_dir{r};
            run_func_files = rdir(fullfile(run_func_path,['waf*.',spm_file_format]));
            
            
            matlabbatch{r}.spm.spatial.smooth.data = run_func_files;
            matlabbatch{r}.spm.spatial.smooth.fwhm = repelem(session.vars.spacialSmoothing, 3);
            matlabbatch{r}.spm.spatial.smooth.dtype = 0;
            matlabbatch{r}.spm.spatial.smooth.im = 0;
            matlabbatch{r}.spm.spatial.smooth.prefix = strcat('s', ...
                num2str(session.vars.spacialSmoothing));
            
        end
        
        spm('defaults', 'FMRI');
        spm_jobman('initcfg');
        spm_jobman('run', matlabbatch);
        
    case  'BV'

        % Get a list of all runs
        func_dir = session.runs;
        
        
        for r=1:length(func_dir)
            run_func_path = func_dir{r};
            run_func_files = rdir(fullfile(run_func_path,['s3waf*.',spm_file_format]));
            
            vtc_obj = importvtcfromanalyze(run_func_files);
            
            vtc_obj.TR = session_tr*1000;
            run_func_parts = strsplit(run_func_path, filesep);
            run_func_name = run_func_parts{end};
            vtc_filename = fullfile( run_func_path, [subject_name, '_', run_func_name, '.vtc']);
            vtc_obj.SaveAs(vtc_filename);
            vtc_obj.ClearObject;
        end
        
        
        if sess == 1
            % Anatomy
            % anat_dir = dir(strcat(session_dirname,'S*t1mpr*'));
            anat_dir =session.anatomy;
            anat_file = rdir(fullfile(anat_dir,['ws*.',spm_file_format]));
            
            vmr_obj = importvmrfromanalyze(anat_file{1});
            
            anatomy_parts = strsplit(session.anatomy, filesep);
            subject_anatomy = anatomy_parts{end};
            % vmr_obj.SaveAs(strcat(session_dirname,anat_dir.name,'/',anat_file.name,'.vmr'));
            vmr_obj.SaveAs(fullfile(subject_T1_dirname,[subject_anatomy,'.vmr']));
            vmr_obj.ClearObject;
        end
        
        
end
end