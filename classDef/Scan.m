classdef Scan < handle
% Naming conventions

% % Methods
% Method names should be all lower case
% Words in an method name should be separated by an underscore
% Non-public method should begin with a single underscore
% If a method name needs to be mangled, two underscores may begin its name

% % Constants
% Constant names must be fully capitalized
% Words in a constant name should be separated by an underscore
 
% % Instance Variables
% Instance variable names should be all lower case
% Words in an instance variable name should be separated by an underscore
% Non-public instance variables should begin with a single underscore
% If an instance name needs to be mangled, two underscores may begin its name
    
% Structure of data field: [vertical_axis | horizontal_axis | angle/energy_axis | scan_axis]

    properties
        data;
        data_raw;
        
        mask;    
        crop_flag = 0;
        white_field;
        dark_field;
        
        data_max;
        data_min;
        data_average;
        data_binned;
        data_crop;
        data_3d;
        data_integral;
        
        data_meta;
        log = '';
        STXMmap;
    end
    
    % - Constructor of the object -
    methods
        function obj = Scan(input_param)          
            obj.data_meta = input_param;                              
        end
    end    
    
    % - Processing methods -
    methods
        function create_path(obj,path)
            switch obj.data_meta.beamline_id
                
                case '34IDC'
                    % For 34 idc output is a list of tiff files
                    % =========================================================================
                    % --- Assemble 'master' file names
                    % =========================================================================
                    if ~exist('path')                
                        try % 34IDC option        
                           main_dir =  fullfile(obj.data_meta.pre_path_data,obj.data_meta.beamtime_id,...
                                                ['AD' obj.data_meta.beamtime_prefix '_' obj.data_meta.sample_name]);
                        catch
                           main_dir = fullfile('/asap3','petra3','gpfs','p10','2018','data', obj.data_meta.beamtime_id, 'raw'); % E.g. on Office Linux PCs            ; % E.g. on  Windows PCs        
                        end
                    else
                        main_dir = path;
                    end
                    
                    if strcmpi(obj.data_meta.sample_name(end),'_') ~= 1
                        obj.data_meta.sample_name = [obj.data_meta.sample_name '_'];
                    end

                    for jj = 1:numel(obj.data_meta.scan_number)
                        master_folder = fullfile(main_dir, [obj.data_meta.beamtime_prefix '_'...
                                                 obj.data_meta.sample_name 'S' sprintf('%04i',obj.data_meta.scan_number(jj))]);

                        t = dir(fullfile(master_folder,'*.tif'));

                        for ii = 1:length(t)
                            obj.data_meta.scan(jj).file(ii).name        = fullfile(master_folder,t(ii).name);
                        end
                    end
                    
                case 'nanomax'
                    if ~exist('path')                	         
                        try % NanoMAx option                            
                            main_dir =  fullfile(obj.data_meta.pre_path_data,'MAXIV',obj.data_meta.beamline_id,obj.data_meta.beamtime_id,'raw',...
                                                 obj.data_meta.sample_name);
                        catch
                            warning('no path!');
                        end
                    else
                        main_dir = path;
                    end
                    
                    for jj = 1:numel(obj.data_meta.scan_number)                        
                        obj.data_meta.scan(jj).file.name        = fullfile(main_dir,['scan_' sprintf('%04i_',obj.data_meta.scan_number(jj)) obj.data_meta.detector_id '_0000.hdf5']);                        
                    end
            end
        end
        
        function create_mask(obj,dim)
            function f_capturekeystroke(H,E)
                disp(E.Key);
                switch E.Key
                    case 'escape'
                        fprintf('Mask creation is broken at:\n %s\n',[obj.data_meta.sample_name ' | Scan '...
                                       num2str(obj.data_meta.scan_number(jj)) ' | Frame ' ...
                                       num2str(ii)]);                                                         
                        flag_exit       = 1;  
                    case 'space'
                        flag_next_frame = 1;
                        disp('Frame skipped!');
                    case 'control'
                        flag_control = 1;
                        disp('Frame masking!');
                end
            end
            
            if nargin==1
                dim = '3D';
            end
            switch dim
                case '2D'
                    for jj = 1:size(obj.data,4)
                        jj
                    end
                case '3D'   
                    flag_exit       = 0;
                    hF = figure('keypressfcn',@f_capturekeystroke);
                    hAx = axes('Parent',hF);
                    disp('Masking:\n esc - abort;\n space - next frame;\n Ctrl - mask frame;\n')
                    for jj = 1:size(obj.data,4)
                        if flag_exit
                            return;
                        else
                            for ii = 1:size(obj.data,3)   
                                if flag_exit
                                    return;
                                else
                                    cla(hAx);
                                    flag_next_frame = 0;  
                                    flag_control    = 0;
                                    obj.mask(:,:,ii,jj) = zeros(size(obj.data(:,:,ii,jj)));
                                    while ~flag_next_frame & ~flag_exit                                                                                
                                        imagesc(log10(obj.data(:,:,ii,jj)));
                                        axis image;
                                        colormap hot;
                                        colormap jet;
                                        title({[obj.data_meta.sample_name ' | Scan '...
                                               num2str(obj.data_meta.scan_number(jj)) ' | Frame ' ...
                                               num2str(ii)], 'Space - next frame | Ctrl - mask | Esc - exit'});
                                        if flag_exit
                                            close(hF);
                                            return;                                            
                                        else
                                            waitforbuttonpress;
                                            if flag_exit
                                                close(hF);
                                                return;
                                            else
                                                if flag_control
                                                    hROI = drawfreehand(hAx);
                                                    obj.mask(:,:,ii,jj) = obj.mask(:,:,ii,jj)+createMask(hROI);
                                                    waitforbuttonpress; 
                                                else
                                                    disp('skipped')
                                                    break;
                                                end
                                            end
                                        end

                                                                       
                                    end 
                                    obj.mask(:,:,ii,jj) = obj.mask(:,:,ii,jj)>0;
                                    disp('Mask frame recorded!');
                                end
                            end
                        end
                    end
                obj.mask = abs(obj.mask-1);
                disp('Full 3D mask recorded!'); 
                close(hF);
            end
        end
        
        function reset(obj,property)
            if isempty(obj.data_raw)
                warning('The raw data is empty.')
            else
                if nargin == 1
                    obj.data_max = [];
                    obj.data_min = [];
                    obj.data_average = [];
                    obj.data_binned = [];
                    obj.data_crop = [];
                    obj.data_3d = [];
                    obj.data_integral = [];
                else
                    switch property
                        case 'hard' % everything will be as imported
                            obj.data = obj.data_raw;
                            obj.log = '';
                            
                            obj.data_max = [];
                            obj.data_min = [];
                            obj.data_average = [];
                            obj.data_binned = [];
                            obj.data_crop = [];
                            obj.data_3d = [];
                            obj.data_integral = [];
                        case {'integral','data_integral', 'integrate'}
                            obj.data_integral = [];
                        otherwise
                            warning('The input is not valid.')
                    end   
                end
            end
        end
        
        function read_tif(obj)
            try
                for jj = 1:numel(obj.data_meta.scan_number)
                    % Read data from 
                    for ii = 1:length(obj.data_meta.scan(jj).file)
                        obj.data(:,:,ii,jj) = single(imread(obj.data_meta.scan(jj).file(ii).name));
                    end
                    fprintf('Loaded: %s \n',[obj.data_meta.sample_name 'S' sprintf('%04i',obj.data_meta.scan_number(jj))])
                end
            catch
                error('Can not load the data!')
            end
        end   
        
        function read_nanomax_merlin(obj)            
%             try
%                 % Extract scan information first                
%                 try                
                    for kk = 1:numel(obj.data_meta.scan_number)  
                        if obj.data_meta.crop_flag
                            obj.data = openmultimerlin_roi(obj.data_meta.scan(kk).file.name,obj.data_meta.scan, obj.data_meta.start_row,obj.data_meta.end_row,...
                                [obj.data_meta.roi(1),obj.data_meta.roi(2),obj.data_meta.roi(3),obj.data_meta.roi(4),obj.data_meta.start_column,obj.data_meta.end_column],...
                                obj.data_meta.scan);
                        else
                            obj.data = openmultimerlin_roi(obj.data_meta.scan(kk).file.name, obj.data_meta.scan);
                        end
                        obj.data_raw = obj.data;
                        fprintf('Loaded: %d \n',kk)
                    end
%                 catch
%                     error('No master file!')
%                 end
%             catch
%                 error('Can not load the data!')
%             end
        end
        
        function read_nanomax_xspress3(obj)            
            try
                % Extract scan information first                
                try                
                    for kk = 1:numel(obj.data_meta.scan_number)  
                        if obj.data_meta.crop_flag
                            obj.data = openmultixspress3_roi(obj.data_meta.scan(kk).file.name,...
                                                             obj.data_meta.scan,...
                                                             obj.data_meta.start_row,...
                                                             obj.data_meta.end_row,...
                                                             [obj.data_meta.roi(1),...
                                                                obj.data_meta.roi(2),...
                                                                obj.data_meta.roi(3),...
                                                                obj.data_meta.roi(4),...
                                                                obj.data_meta.start_column,...
                                                                obj.data_meta.end_column]);
                        else
                            obj.data = openmultixspress3_roi(obj.data_meta.scan(kk).file.name, obj.data_meta.scan);
                        end
                        obj.data_raw = obj.data;
                        fprintf('Loaded: %d \n',kk)
                    end
                catch
                    error('No master file!')
                end
            catch
                error('Can not load the data!')
            end
        end
        
        function read_nanomax_pil100k(obj)            
%             try
%                 % Extract scan information first                
%                 try                
                    for kk = 1:numel(obj.data_meta.scan_number)  
                        if obj.data_meta.crop_flag
                            obj.data = openmultipil100k_roi(obj.data_meta.scan(kk).file.name,...
                                                             obj.data_meta.scan,...
                                                             obj.data_meta.start_row,...
                                                             obj.data_meta.end_row,...
                                                             [obj.data_meta.roi(1),...
                                                                obj.data_meta.roi(2),...
                                                                obj.data_meta.roi(3),...
                                                                obj.data_meta.roi(4),...
                                                                obj.data_meta.start_column,...
                                                                obj.data_meta.end_column]);
                        else
                            obj.data = openmultipil100k_roi(obj.data_meta.scan(kk).file.name, obj.data_meta.scan);
                        end
                        obj.data_raw = obj.data;
                        fprintf('Loaded: %d \n',kk)
                    end
%                 catch
%                     error('No master file!')
%                 end
%             catch
%                 error('Can not load the data!')
%             end
        end
        
        function read_mask(obj)
%             file_temp = fullfile(obj.data_meta.save_folder,[obj.data_meta.sample_name,'_',num2str(obj.data_meta.scan_number)],obj.data_meta.mask_name);
            try
                switch obj.data_meta.mask_path(end-2:end)
                    case 'mat'
                        load(obj.data_meta.mask_path);
                        obj.mask = transpose(mask);
                    case 'tif'
                        obj.mask = single(imread(obj.data_meta.mask_path));
                end
                fprintf('Mask loaded:\n %s\n',obj.data_meta.mask_path);
            catch
                warning('No mask specified!');
            end
        end
               
        function read_white_field(obj)
            try
                switch obj.data_meta.white_field_path(end-2:end)
                    case 'mat'
                        load(obj.data_meta.white_field_path);
                        obj.white_field = white_field;
                    case 'tif'
                        obj.white_field = single(imread(obj.data_meta.white_field_path));
                end
%                 obj.white_field(obj.white_field < 6000) = 1e25;
                disp('### White field loaded ###');
            catch
                warning('No white field specified!');
            end
        end
        
        function read_dark_field(obj)
            try
                switch obj.data_meta.white_field_path(end-2:end)
                    case 'mat'
                        load(obj.data_meta.dark_field_path);
                        obj.dark_field = dark_field;
                    case 'tif'
                        obj.dark_field = single(imread(obj.data_meta.dark_field_path));
                end
                disp('### Dark field loaded ###');
            catch
                warning('No dark field specified!');
            end
        end        
        
        function read_beam_current(obj)
             switch obj.data_meta.beamline_id                
                case 'nanomax'
                    obj.data_meta.nanomax.beam_current = h5read(obj.data_meta.master_file_nanomax,sprintf('/entry%d/measurement/beam_current/',obj.data_meta.scan_number));
             end
        end
        
        function correct_low_cutoff(obj)
            obj.data(obj.data<=obj.data_meta.low_cutoff) = 0;
            disp('Data was low-tresholded');
        end
        
        function correct_dark_field(obj)
            disp('### Correcting by dark-field ###');
            try
                if ~isempty(obj.dark_field) & size(obj.data(:,:,1))==size(obj.dark_field)
                    for jj = 1:size(obj.data,4) 
                        for ii = 1:size(obj.data,3) 
                            t = obj.data(:,:,ii,jj);
                            t(obj.dark_field>1) = 0;
                            obj.data(:,:,ii,jj) = t;                                
                        end
                        fprintf('Processign Scan #%d\n',jj);
                    end
                    obj.log = [obj.log 'Dark field correction. ']; 
                    disp('Data corrected by dark field!')
                elseif ~isempty(obj.dark_field) & size(obj.data(:,:,1))~=size(obj.dark_field)
                    error('Dark field size does not match data size!')
                elseif isempty(obj.dark_field)
                    error('No dark field!')
                end
            catch
                if ndims(obj.data) ~= 3
                    warning('The data is not 3D! Skipped. Add functionality to method!')
                else
                    error('Can not correct by dark field');
                end
            end
        end
               
        function correct_white_field(obj)
            disp('### Correcting by white-field ###');
            try
                if ~isempty(obj.white_field) & size(obj.data(:,:,1))==size(obj.white_field)                    
                    for jj = 1:size(obj.data,4) 
                        for ii = 1:size(obj.data,3) 
                            obj.data(:,:,ii,jj) = max(obj.white_field(:)).*obj.data(:,:,ii,jj)./obj.white_field; 
                            obj.data(isinf(obj.data)) = 0;
                            obj.data(isnan(obj.data)) = 0;
                        end
                        fprintf('Processing Scan #%d\n',jj);
                    end
                    obj.log = [obj.log 'White field correction. ']; 
                    disp('Data corrected by white field!')
                elseif ~isempty(obj.white_field) & size(obj.data(:,:,1))~=size(obj.white_field)
                    error('White field size does not match data size!')
                elseif isempty(obj.white_field)
                    error('No White field!')
                end
            catch
                if ndims(obj.data) ~= 3
                    warning('The data is not 3D! Skipped. Add functionality to method!')
                else
                    error('Can not correct by white field');
                end
            end
        end
        
        function correct_mask(obj)
            disp('### Masking the data ###');
            try
                obj.data = obj.data.*obj.mask;
                obj.log = [obj.log 'Applied mask. ']; 
                disp('Mask applied!');
            catch
                warning('No mask specified or exists!');
            end
        end
        
        function correct_mask_nanomax(obj)
            disp('### Masking the data ###');
            try
                for ii =1:size(obj.data,3)
                    for jj =1:size(obj.data,4)
                        obj.data(:,:,ii,jj) = obj.data(:,:,ii,jj).*single(obj.mask);
                    end
                end
                obj.log = [obj.log 'Applied mask. ']; 
                disp('Mask applied!');
            catch
                warning('No mask specified or exists!');
            end
        end
        
        function correct_flux(obj)
%             try
                flux = openh5attribute(obj.data_meta.master_file_nanomax, sprintf('/entry%d/measurement/Ni6602_buff',obj.data_meta.scan_number));
                
                max_flux = max(max(flux));
                relative_flux = transpose(flux./max_flux);
                
                for i=1:size(obj.data,3)
                    for j=1:size(obj.data,4)
                        obj.data(:,:,i,j) = obj.data(:,:,i,j).*relative_flux(i,j);
                    end
                end
                obj.log = [obj.log 'Flux correction. ']; 
                disp('Flux was corrected.')
%             catch
%                 warning('The data was not corrected successfully.');
%             end
        end
        
        function shift = calculate_drift_shift(obj,Ix,Iy,direction)
            try
                if isempty(obj.data_integral)
                    obj.integrate([1 2]);
                end
                
                if nargin == 2
                    Ix_end = size(obj.data_integral,1);
                    Ix = 1:Ix_end;
                    
                    Iy_end = size(obj.data_integral,2);
                    Iy = 1:Iy_end;
                end
                
                if direction == 'y'
                    temp = Ix;
                    Ix = Iy;
                    Iy = temp;
                    
                    obj.data_integral = transpose(obj.data_integral);
                end
                
                for i=1:length(Iy) 
                    data_row(i,:) = smooth(obj.data_integral(Ix,Iy(1)+i-1));

                    if i ~= 1 % due to we need something to compare to, i.e. i=1
                        [corr(i,:) lag(i,:)] = xcorr(data_row(1,:),data_row(i,:));
                        corr(i,:) = corr(i,:)/max(corr(i,:)); %normalize cross correlation for each row
                        [max_value(i), max_index(i)] = max(corr(i,:));
                        shift(i) = lag(i,max_index(i));
                    end
                end
                
                if direction == 'y'
                    obj.data_integral = transpose(obj.data_integral);
                end

                disp('The shift was calculated.')
            catch
                warning('The shift was not calculated successfully.');
            end
        end
        
        % Truncates obj.data corresponding to input pixels in scanmap
        function cut(obj, cut_pixels, direction)
            if direction == 'x'
                cut_counter = 0;
                for i=1:size(cut_pixels,2)
                    if cut_pixels(1,i) == -1 % every value of cut_pixels column = -1 if to be cut
                        fprintf('Cutting column %d of scan %d \n',i,obj.data_meta.scan_number);
                        obj.data(:,:,i-cut_counter,:) = [];
                        disp('The new size is: ')
                        disp(size(obj.data));
                        cut_counter = cut_counter + 1;
                    end
                end
            end
            
            if direction == 'y'
                cut_counter = 0;
                for i=1:size(cut_pixels,1)
                    if cut_pixels(i,1) == -1 % every value of cut_pixels column = -1 if to be cut
                        fprintf('Cutting column %d of scan %d \n',i,obj.data_meta.scan_number);
                        obj.data(:,:,:,i-cut_counter) = [];
                        disp('The new size is: ')
                        disp(size(obj.data));
                        cut_counter = cut_counter + 1;
                    end
                end
            end
            
            %cutting the diffraction pattern and then scans
            if direction == 'd0'
                cut_counter = 0;
                for i=1:size(cut_pixels,2)
                    if cut_pixels(1,i) == -1 % every value of cut_pixels column = -1 if to be cut
                        fprintf('Cutting column %d of scan %d \n',i,obj.data_meta.scan_number);
                        obj.data(i-cut_counter,:,:,:) = [];
                        disp('The new size is: ')
                        disp(size(obj.data));
                        cut_counter = cut_counter + 1;
                    end
                end
            end
            
            if direction == 'd1' % better name would be nice
                cut_counter = 0;
                for i=1:size(cut_pixels,1)
                    if cut_pixels(i,1) == -1 % every value of cut_pixels column = -1 if to be cut
                        fprintf('Cutting column %d of scan %d \n',i,obj.data_meta.scan_number);
                        obj.data(:,i-cut_counter,:,:) = [];
                        disp('The new size is: ')
                        disp(size(obj.data));
                        cut_counter = cut_counter + 1;
                    end
                end
            end
        end
        
        function shift = drift_align(obj,direction,shift,Ix,Iy)
%             try
                if nargin == 2
                    Ix_end = size(obj.data,3);
                    Ix = 1:Ix_end;
                    
                    Iy_end = size(obj.data,4);
                    Iy = 1:Iy_end;
                    
                    shift = obj.calculate_drift_shift(Ix,Iy,direction);
                elseif nargin == 3
                    Ix_end = size(obj.data,3);
                    Ix = 1:Ix_end;
                    
                    Iy_end = size(obj.data,4);
                    Iy = 1:Iy_end;
                end
                
                if direction == 'y'
                    temp = Ix;
                    Ix = Iy;
                    Iy = temp;
                    
                    obj.data_integral = transpose(obj.data_integral);
                end
                
                new_data = obj.data;
                
                for i=1:length(shift)
                    if shift(i) > 0 % move to the right
                       for k=1:size(obj.data,3) 
                            if k <= shift(i)
                                new_data(:,:,k,Iy(1)+i-1) = Inf;
                            else
                                new_data(:,:,k,Iy(1)+i-1) = obj.data(:,:,k-shift(i),Iy(1)+i-1);
                            end
                       end
                    elseif shift(i) < 0 %move to the left
                        for k=size(obj.data_integral,1):-1:1 
                            if k > size(obj.data,3)+shift(i)
                                new_data(:,:,k,Iy(1)+i-1) = Inf; 
                            else
                                if k > abs(shift(i))
                                    new_data(:,:,k,Iy(1)+i-1) = obj.data(:,:,k-shift(i),Iy(1)+i-1);
                                end
                            end
                        end
                    end
                end
                
                if direction == 'y'
                    new_data = transpose(new_data);
                end
                
                obj.data = new_data;
                obj.reset; % because those properties depend on obj.data
                obj.log = [obj.log 'Aligned for drift in ' direction '-direction. ']; 
                
                % Truncate data (checked for only x-dir)
                cut_pixels = zeros(size(obj.data,4),size(obj.data,3));
                
                % from left
                for i=1:max(shift)
                    cut_pixels(:,i) = -1;
                end
                
                % from right
                for i=1:abs(min(shift))
                    cut_pixels(:,size(obj.data,3)-i+1) = -1;
                end
                
                obj.cut(cut_pixels,direction);
                
                disp('Data was aligned.')
%             catch
%                 warning('The data was not aligned successfully.');
%             end
        end
        
        function crop(obj)
            show_data_average(obj,'log');
            hRect = drawrectangle;            
            disp('### Cropping the dataset ###')
            for jj = 1:size(obj.data,4)
                for ii = 1:size(obj.data,3)
                    obj.data_crop(:,:,ii,jj) = imcrop(squeeze(obj.data(:,:,ii,jj)),hRect.Position);
                end
            end
            figure; imagesc(log10(squeeze(mean(mean(obj.data_crop,4),3)))); colormap jet; axis image;
            obj.crop_flag = 1;
        end
        
        function correct_hot_pixel(obj,x,y,interpolate)
            disp('### Hot-pixels correction ###');
            if ~interpolate
                obj.data(x,y,:,:) = 0;
                obj.log = [obj.log 'Hot pixel [x:' x ' y:' y '] zeroed. ']; 
                fprintf('Hot pixel [x:%d y:%d] zeroed!\n',x,y);
            else               
                for jj = 1:size(obj.data,4)
                    for ii = 1:size(obj.data,3)
                        try
                            obj.data(y,x,ii,jj) = mean(mean(obj.data(y-1:2:y+1,x-1:2:x+1,ii,jj)));
                        catch
                            try
                                obj.data(y,x,ii,jj) = mean(mean(obj.data(y-1:2:y+1,x+1,ii,jj)));                        
                            catch
                                obj.data(y,x,ii,jj) = mean(mean(obj.data(y+1,x-1:2:x+1,ii,jj)));                        
                            end                            
                        end
                    end
                end    
                obj.log = [obj.log 'Hot pixel [x:' x ' y:' y '] interpolated. ']; 
                fprintf('Hot pixel [x:%d y:%d] interpolated!\n',x,y);
            end                
        end        
        
        function average(obj,dimsAverage)
            disp('### Averaging the data ###');            
            try  
%                 clear data_average;
                obj.data_average = squeeze(mean(obj.data,dimsAverage));     
                disp('### Data was averaged ###')
            catch
                disp('Data not-averaged!');
            end                
        end
        
        function flip(obj,dim)            
            if ~exist('dim')
                warning('No dimension specified: lr / ud. Skip.')
            else
                fprintf('### Flipping the data %s ###', dim);
                switch dim
                    case 'lr'
                        obj.data = fliplr(obj.data);
                    case 'ud'
                        obj.data = flipud(obj.data);
                end
            end
        end
        
        function bin2D(obj, binning_size)
            for ii = 1:size(obj.data,3)
                for jj = 1:size(obj.data,4)
                    convoluted = conv2(obj.data(:,:,ii,jj), ones(binning_size));
                    convoluted_size = size(convoluted);
                    obj.data_binned(:,:,ii,jj) = convoluted(binning_size:binning_size:convoluted_size(1), binning_size:binning_size:convoluted_size(2));
                end
            end            
        end
        
        function [COM] = ndimCOM(IN,type)    
            disp('### Calculating the center of mass ###');
            if strcmp(type,'manual')        
                imagesc(log10(IN));axis image
                h = impoly;
                hMask = createMask(h);
                IN = IN.*hMask;
            end
            C = cellfun(@(n) 1:n, num2cell(size(IN)),'uniformoutput',0);
            [C{:}] = ndgrid(C{:});
            C = cellfun(@(x) x(:), C,'uniformoutput',0);
            C = [C{:}];
            COM(:,:) = IN(:).'*C/sum(IN(:),'double');
        end        
        
        function combine(obj)
            disp('### Aligning multiple-scan data with respect to 1st in array ###');
            % Center
            reference_object = 1;
            
            for jj = 1:size(obj.data,4)-1
%                 try
%                     c = convn(gpuArray(obj.data(:,:,:,reference_object)),gpuArray(obj.data(end:-1:1,end:-1:1,end:-1:1,reference_object+jj)));
%                     c = gather(c);
%                 catch
                    disp('GPU acceleration was not found or too big array, therefore wait =)');                    
                    c = convn((obj.data(:,:,:,reference_object)),(obj.data(end:-1:1,end:-1:1,end:-1:1,reference_object+jj)));
%                 end
                
                [x,y,z] = ind2sub(size(c),find(c == max(max(max(c)))));

                shift = [x-size(obj.data(:,:,:,reference_object),1),y-size(obj.data(:,:,:,reference_object),2),z-size(obj.data(:,:,:,reference_object),3)];

                obj.data(:,:,:,reference_object+jj) = circshift(obj.data(:,:,:,reference_object+jj),shift); 
                
                fprintf('Shifted Scan #%d\n', jj);
            end           
        end
        
        function normalize_exposure(obj)
            disp('### Normalizing the data by exposure time ###');
            if ~isempty(obj.data_meta.exposure)
                obj.data = obj.data./obj.data_meta.exposure;
                fprintf('Data is normalized by exposure: %.3f s\n', obj.data_meta.exposure);
                if isempty(obj.data_meta.dead_time)
                    obj.data_meta.dead_time = 0 ;
                end
                obj.data = obj.data./(1-obj.data_meta.dead_time.*obj.data);
                fprintf('Data is normalized by dead time: %.3e s\n', obj.data_meta.dead_time);                
            else
                error('Exposure time is missing. Skipping...')
            end
        end
        
        function prepare_3d(obj)
            try
                obj.data_3d = log10(obj.data)./max(max(max(log10(obj.data))));
            catch
                warning('Can not prepare 3D array, checl the method!')
            end
        end
                        
        function integrate(obj,dimsIntegrate) % [dimensions to integrate] 
            disp('### Integrating the data ###');            
            try
                obj.data_integral = squeeze(sum(obj.data,dimsIntegrate));
                fprintf('Dimensions integrated: \n %d \n',dimsIntegrate);
            catch
                disp('Data not-integrated!');
            end
        end 
        
        function maximize(obj)
            disp('### Getting max values from each frame ###');
            try
                if ndims(obj.data) == 4                
                    obj.data_max = squeeze(sum(sum(squeeze(sum(obj.data,3)),1),2));
                    disp('Data integrated sown to 3D!');
                else
                    for ii = 1:size(obj.data,3)
                        obj.data_max(ii) = squeeze(max(max(obj.data(:,:,ii))));                        
                    end
                end                
            catch
                disp('Data not-maximised!');
            end
        end
        
        function minimize(obj)
            disp('### Getting min values from each frame ###');
            try
                if ndims(obj.data) == 4                
                    obj.data_max = squeeze(sum(sum(squeeze(sum(obj.data,3)),1),2));
                    disp('Data integrated sown to 3D!');
                else
                    for ii = 1:size(obj.data,3)                        
                        m = double(obj.data(:,:,ii)>0);
                        m(m==0) = NaN;
                        obj.data_min(ii) = squeeze(nanmin(nanmin(m.*obj.data(:,:,ii))));                        
                    end
                end                
            catch
                disp('Data not-minimized!');
            end
        end
    end
    
    % Show methods
    methods  
        function show_data_max(obj)
            maximize(obj);
            figure; plot(log10(obj.data_max),'LineWidth',2,'Marker','o');
        end
        
        function show_data_min(obj)
            minimize(obj);
            figure; plot((obj.data_min),'LineWidth',2,'Marker','o');
        end
        
        function show_dark_field(obj)
            try
                figure;            
                imagesc(obj.dark_field);
                axis image;
                colormap jet;
                colorbar;
                title('Dark field');
            catch
                error('No dark field!')
            end
        end
        
        function show_white_field(obj)
            try
                figure;            
                imagesc(obj.white_field);axis image;colormap jet;colorbar
                title('White field');
            catch
                error('No white field!')
            end
        end
        
        function show_3d(obj,isoVal)                    
            if nargin == 1
                isoVal = 0.5;
            end                            
            try
                isosurface(smooth3(obj.data_3d),isoVal); axis image
            catch
                prepare_3d(obj);
                isosurface(smooth3(obj.data_3d),isoVal); axis image
            end
        end
        
        function show_data_scroll(obj,scale,max_val)
            if ~exist('scale')
                scale = 'log';
            end
            
            if nargin == 2
                average(obj);
                max_val = mean(obj.data_average(:))*.5;
            end
            
            if ndims(obj.data) == 4    
                switch scale
                    case 'log'
                        handle = implay(log10(sum(obj.data,3)));
                    case 'lin'
                        handles.imHandle = imagesc(obj.data_average);            
                end            
            else
                switch scale
                    case 'log'
                        handle = implay(log10(obj.data));
                    case 'lin'
                        handle = implay(obj.data);
                end
            end
            handle.Visual.ColorMap.MapExpression = 'hot'; 
            handle.Visual.ColorMap.UserRangeMin = 0.1;
            handle.Visual.ColorMap.UserRangeMax = max_val;
            handle.Visual.ColorMap.UserRange = max_val;
        end                       
        
        function handles = show_data_single(obj, scale, index)
            if nargin == 1
                index = 1;
                scale = 'lin';
            elseif nargin == 2
                index = 1;
            end
            handles.figHandle = figure;
            switch scale
                case 'lin'
                    handles.imHandle = imagesc(abs(obj.data(:,:,index)));
                    handles.colorBar = colorbar;
                case 'log'
                    handles.imHandle = imagesc(log10(abs(obj.data(:,:,index))));
                    handles.colorBar = colorbar;
                    ylabel(handles.colorBar,'log');
            end
            axis image;            
            
            colormap jet;
            title([obj.data_meta.sample_name ' | Scan ' num2str(obj.data_meta.scan_number) ' | Frame ' num2str(index)]);
        end                
        
        function handles = show_data_average(obj,scale)
            if ~exist('scale')
                scale = 'lin';
            end
            
            handles.figHandle = figure;            
            
            try 
                switch scale
                    case 'log'
                        handles.imHandle = imagesc(log10(obj.data_average)); 
                        handles.colorBar = colorbar;
                        ylabel(handles.colorBar,'log');
                    case 'lin'
                        handles.imHandle = imagesc(obj.data_average);            
                end
                axis image;            

                colormap jet;
                title(['Average: ' obj.data_meta.sample_name ' | Scan ' num2str(obj.data_meta.scan_number)]);
            catch
                warning('Average data first!');
            end
        end
        
        function handles = show_data_integral(obj,scale)             %should output an appropriate type of a plot
            handles.figHandle = figure;            
            if ndims(obj.data_integral) == 1
                try
                    handles.imHandle = plot(obj.data_meta.Vector, obj.data_integral,'-o');
                catch
                    handles.imHandle = plot(obj.data_integral,'-o');
                end
                ylabel('Integral intensity');
                xlabel('Scan motor position');
                title([obj.data_meta.sample_name ' | Scan ' num2str(obj.data_meta.scan_number)]);
            elseif ismatrix(obj.data_integral)
                
                % Plotting
                try
                    hVector = (-round(size(obj.data_integral,2)/2):round(size(obj.data_integral,2)/2)-1).*obj.data_meta.nanomax.step_h*1e6;
                    vVector = (round(size(obj.data_integral,1)/2):-1:-(round(size(obj.data_integral,1)/2)-1)).*obj.data_meta.nanomax.step_v*1e6;
                catch
                    hVector = 1:size(obj.data_integral,2);
                    vVector = 1:size(obj.data_integral,1);
                end
                
                try
                    switch scale
                        case 'lin'
                            handles.imHandle = imagesc(hVector,vVector,obj.data_integral);axis image;colormap jet;colorbar;axis xy
                            xlabel('Scan position, [um]');ylabel('Scan position, [um]');
                        case 'log'
                            handles.imHandle = imagesc(hVector,vVector,log10(obj.data_integral));axis image;colormap jet;colorbar;axis xy
                            xlabel('Scan position, [um]');ylabel('Scan position, [um]');
                    end                    
                catch
                    warning('Can not plot an integral map');
                end
                title(['Average: ' obj.data_meta.sample_name ' | Scan ' num2str(obj.data_meta.scan_number)]);
            end
        end
        
        function show_fluorescence(obj)
            if obj.data_meta.detector_id == "xspress3"
                try
                    obj.average([3 4])
                    plot(log10(squeeze(obj.data_average(4,:))));
                catch
                    warning('Can not plot fluorescence');
                end
            else
                warning('The data of the scan is not fluorescence data.');
            end
        end
        
        function show_scanmap(obj,coord)
            if isempty(obj.data_integral)
                obj.integrate([1,2])
            end

            try
                figure();
                imagesc(transpose(obj.data_integral)); % transpose to rotate map
                colormap jet; colorbar;
                
                if nargin > 2
                    xmin = coord(1);
                    xmax = coord(2);
                    ymin = coord(3);
                    ymax = coord(4);
                 
                    % Axis
                    tick_spacing = 10;
                    xticks(1:tick_spacing:size(obj.data_integral,1)); % tick every 'tick_spacing' steps 
                    dx = tick_spacing*(xmax-xmin)/size(obj.data_integral,1);
                    xticklabels(round(xmin:dx:xmax,1)); %... which translates to tick every dx microns

                    yticks(1:tick_spacing:size(obj.data_integral,2));
                    dy = tick_spacing*(ymax-ymin)/size(obj.data_integral,2);
                    yticklabels(round(ymin:dy:ymax,1));

                    xlabel('Scan position [um]'); ylabel('Scan position [um]');
                else
                    xlabel('Scan position [px]'); ylabel('Scan position [px]');
                end
                    
            catch
                warning('Can not plot a scan map');
            end
            title(['Scan map: ' obj.data_meta.sample_name ' | Scan ' num2str(obj.data_meta.scan_number)]);
        end
    end
    
    % Save methods
    methods
        function save_gif(obj,user_name)
            disp('Saving GIF animation...');
            file_temp = [obj.data_meta.sample_name,'_',num2str(obj.data_meta.scan_number)];
            mkdir(fullfile(obj.data_meta.save_folder,file_temp));            
            if nargin>1
                gif_name = fullfile(obj.data_meta.save_folder,file_temp,[user_name '.gif']);
            else                
                gif_name = fullfile(obj.data_meta.save_folder,file_temp,[obj.data_meta.sample_name,'_',num2str(obj.data_meta.scan_number),'.gif']);
            end
            f1 = figure;
            for ii = 1:size(obj.data,3)                
                imagesc(log10(squeeze(obj.data(:,:,ii))));
                colormap hot; axis image; %caxis([0.1 0.8]);
                title([obj.data_meta.sample_name ' | Scan ' num2str(obj.data_meta.scan_number) ' | Frame ' num2str(ii)]);           
                GIFanimation(gif_name, f1, 0.1, size(obj.data,3), ii);
            end
            disp('Done!');
        end
        
        function save_mask(obj)
            disp('Saving data to .mat ...');
            file_temp = [obj.data_meta.sample_name,'_',num2str(obj.data_meta.scan_number)];
            mkdir(fullfile(obj.data_meta.save_folder,file_temp));
            
            mask = obj.mask;
            
            if ndims(obj.mask) == 2
                suffix = '2D';
            else
                suffix = '3D';
            end
            
            if nargin>1
                save(fullfile(obj.data_meta.save_folder,file_temp,[user_name,'_mask_',suffix,'.mat']),'mask','-v7.3');
            else                
                save(fullfile(obj.data_meta.save_folder,file_temp,[file_temp,'_mask_',suffix,'.mat']),'mask','-v7.3');            
            end
            disp('Done!');
        end
        
        function save_data(obj,user_name)
            disp('Saving data to .mat ...');
            file_temp = [obj.data_meta.sample_name,'_',num2str(obj.data_meta.scan_number)];
            mkdir(fullfile(obj.data_meta.save_folder,file_temp));
            
            if nargin>1
                file_name = user_name;
            else
                file_name = strcat(file_temp,'_',obj.data_meta.detector_id);
            end
            save(fullfile(obj.data_meta.save_folder,file_temp,[file_name,'.mat']),'obj','-v7.3');
            
            if obj.crop_flag
                data = obj.data_crop; %#ok<*PROPLC>
            else
                data = obj.data;
            end
            
            if obj.data_meta.save_diff
                if nargin>1
                    save(fullfile(obj.data_meta.save_folder,file_temp,[user_name,'_diff.mat']),'data','-v7.3');
                else                
                    save(fullfile(obj.data_meta.save_folder,file_temp,[file_temp,'_diff.mat']),'data','-v7.3');            
                end
            end
            
            disp('Done!');                        
            
            if strcmp(obj.data_meta.save_formats,'bin')
                disp('Saving data to .bin ...');            
                if nargin>1
                    fid = fopen(fullfile(obj.data_meta.save_folder,file_temp,[user_name,sprintf('_%d_%d_%d_',size(data,1),size(data,2),size(data,3)),'.bin']),'wb');            
                else
                    fid = fopen(fullfile(obj.data_meta.save_folder,file_temp,[file_temp,sprintf('_%d_%d_%d_',size(data,1),size(data,2),size(data,3)),'.bin']),'wb');            
                end

                fwrite(fid,data,'double');
                fclose(fid);      
            end
            
            disp('Done!');
        end
    end
    
    % Mapping methods
    methods 
        function handles = showScanSTXMLive(obj,mode)     
            global KEY_IS_PRESSED
            KEY_IS_PRESSED = 0;
            
            if nargin == 1
                mode = 'rect';
            end

            handles.figHandle = figure;
            subplot(1,2,1); imagesc(log10(obj.data_average)); axis image; title('Integrated intensity');

            map = zeros([size(obj.data,4),size(obj.data,3)]);

            if strcmp(mode,'rect')
                h = imrect;
            else
                h = impoly;
            end
            
            while 1   
                if strcmp(mode,'rect')
                    pos = round(getPosition(h)); %[xmin ymin width height]
                else
                    mask = createMask(h);
                end

                kk = 1;
                for ii = 1:size(obj.data,4)
                    for jj = 1:size(obj.data,3)
                        if strcmp(mode,'rect')
                            map(ii,jj) = sum(sum(obj.data(pos(2):pos(2)+pos(4),pos(1):pos(1)+pos(3),kk)));
                        else
                            map(ii,jj) = sum(sum(obj.data(:,:,kk).*mask));
                        end
                        kk = kk+1;                        
                    end
                end
                subplot(1,2,2); imagesc(map); axis image
%                 xlabel(obj.metaData.fastMotorName);
%                 ylabel(obj.metaData.slowMotorName);
                title('PRESS CTRL+C TO STOP!');
                drawnow;
            end           
        end   
        
        function handles = showScanCOM(obj,mode)
            if nargin == 1
                mode = 'rect';
            end

            handles.figHandle = figure;
            subplot(2,2,[1,3]); imagesc(log10(obj.data_average)); axis image; title('Integrated intensity');
            colormap jet;
            
            mapX = zeros([size(obj.data,4),size(obj.data,3)]);
            mapY = zeros([size(obj.data,4),size(obj.data,3)]);
            
            if strcmp(mode,'rect')
                h = imrect;
            elseif strcmp(mode,'poly')
                h = impoly;
            end
            
            alphaFlag = 0;
            
            if alphaFlag              
                alpha_map = obj.data_integral'./max(obj.data_integral(:));
                alpha_map(alpha_map<0.2) = 0;                              
            end
            
%             while 1 
                if strcmp(mode,'rect')
                    pos = round(getPosition(h)); %[xmin ymin width height]
                    mask = zeros(size(obj.data_average));
                    mask(pos(2):pos(2)+pos(4),pos(1):pos(1)+pos(3)) = 1;
                else
                    mask = createMask(h);                    
                end
                                                
                com0 = ndimCOM(obj.data_average.*mask,'auto');     % [v,h]           
%                 com0 = [obj.data_meta.nanomax.direct_beam(2),obj.data_meta.nanomax.direct_beam(1)];     % [v,h]           

                kk = 1;
                for ii = 1:size(obj.data,4)
                    for jj = 1:size(obj.data,3)
                        
                        com = ndimCOM(obj.data(:,:,kk).*mask,'auto');
                        
                        mapX(ii,jj) = com0(2)/com(2)-1; % strain calculation
                        mapY(ii,jj) = atand((com0(1)-com(1))*obj.data_meta.nanomax.detector_pitch/obj.data_meta.nanomax.radius); % tilt calculation

                        kk = kk+1; 
                    end
                end
                
                % Plotting
                try
                    hVector = (-round(size(mapX,2)/2):round(size(mapX,2)/2)-1).*obj.data_meta.nanomax.step_h*1e6;
                    vVector = (round(size(mapX,1)/2):-1:-(round(size(mapX,1)/2)-1)).*obj.data_meta.nanomax.step_v*1e6;
                catch
                    hVector = 1:size(mapX,2);
                    vVector = 1:size(mapX,1);
                end

                subplot(2,2,2); 
                hh = imagesc(hVector,vVector,mapX); axis xy
                try
                     set(hh,'AlphaData',alpha_map);
                catch
                    warning('Ńo alpha mask')
                end
                axis image; colorbar('northoutside'); 
                title('Strain');xlabel('Scan position, [um]');ylabel('Scan position, [um]');
                
                subplot(2,2,4);                
                hh = imagesc(hVector,vVector,mapY-mean(mapY(:)));axis xy
                try
                     set(hh,'AlphaData',alpha_map);
                catch
                    warning('Ńo alpha mask')
                end
                axis image; colorbar('northoutside');                
                title('Tilt, [deg]');xlabel('Scan position, [um]');ylabel('Scan position, [um]');
                drawnow;
            end
        end
    end        


