function [basePlanC, movPlanC] = register_scans(basePlanC, movPlanC, baseScanNum, movScanNum, algorithm)
% function basePlanC = register_scans(basePlanC, movPlanC, baseScanNum, movScannum, algorithm)
%
% APA, 07/12/2012

indexBaseS = basePlanC{end};
indexMovS  = movPlanC{end};

% Create .mha file for base scan
baseScanUID = basePlanC{indexBaseS.scan}(baseScanNum).scanUID;
randPart = floor(rand*1000);
baseScanUniqName = [baseScanUID,num2str(randPart)];
baseScanFileName = fullfile(getCERRPath,'ImageRegistration','tmpFiles',['baseScan_',baseScanUniqName,'.mha']);
try
    delete(baseScanFileName);
end
success = createMhaScansFromCERR(baseScanNum, baseScanFileName, basePlanC);

% Create .mha file for moving scan
movScanUID = movPlanC{indexMovS.scan}(movScanNum).scanUID;
randPart = floor(rand*1000);
movScanUniqName = [movScanUID,num2str(randPart)];
movScanFileName = fullfile(getCERRPath,'ImageRegistration','tmpFiles',['movScan_',movScanUniqName,'.mha']);
try
    delete(movScanFileName);
end
success = createMhaScansFromCERR(movScanNum, movScanFileName, movPlanC);

% Create a command file for plastimatch
cmdFileName = fullfile(getCERRPath,'ImageRegistration','plastimatch_command',[baseScanUID,'_',movScanUID,'.txt']);
try
    delete(cmdFileName);
end

% Create a file name for storing bspline coefficients
bspFileName = fullfile(getCERRPath,'ImageRegistration','tmpFiles',['bsp_coeffs_',baseScanUID,'_',movScanUID,'.txt']);
try
    delete(bspFileName)
end

% Call appropriate command file based on algorithm
userCmdFile = fullfile(getCERRPath,'ImageRegistration','plastimatch_command','bspline_register_cmd.txt');
ursFileC = file2cell(userCmdFile);
cmdFileC{1,1} = '[GLOBAL]';
cmdFileC{2,1} = ['fixed=',escapeSlashes(baseScanFileName)];
cmdFileC{3,1} = ['moving=',escapeSlashes(movScanFileName)];
cmdFileC{4,1} = ['xform_out=',escapeSlashes(bspFileName)];
cmdFileC{5,1} = '';
cmdFileC(6:5+size(ursFileC,2),1) = ursFileC(:);
cell2file(cmdFileC,cmdFileName)

% Run plastimatch Registration
system(['plastimatch register ', cmdFileName]);

% Read bspline coefficients file
[bsp_img_origin,bsp_img_spacing,bsp_img_dim,bsp_roi_offset,bsp_roi_dim,bsp_vox_per_rgn,bsp_direction_cosines,bsp_coefficients] = read_bsplice_coeff_file(bspFileName);

% Create new deform object
deformS = initializeCERR('deform');
deformS(1).baseScanUID = baseScanUID;
deformS(1).movScanUID = movScanUID;
deformS(1).deformUID = createUID('deform');
deformS(1).bsp_img_origin = bsp_img_origin;
deformS(1).bsp_img_spacing = bsp_img_spacing;
deformS(1).bsp_img_dim = bsp_img_dim;
deformS(1).bsp_roi_offset = bsp_roi_offset;
deformS(1).bsp_roi_dim = bsp_roi_dim;
deformS(1).bsp_vox_per_rgn = bsp_vox_per_rgn;
deformS(1).bsp_coefficients = bsp_coefficients;
deformS(1).bsp_direction_cosines = bsp_direction_cosines;

% Add deform object to both base and moving planC's
baseDeformIndex = length(basePlanC{indexBaseS.deform}) + 1;
movDeformIndex  = length(movPlanC{indexMovS.deform}) + 1;
basePlanC{indexBaseS.deform}  = dissimilarInsert(basePlanC{indexBaseS.deform},deformS,baseDeformIndex);
movPlanC{indexMovS.deform}  = dissimilarInsert(movPlanC{indexMovS.deform},deformS,movDeformIndex);

movPlanC{indexMovS.deform}(movDeformIndex) = deformS;

% Cleanup
try
    delete(baseScanFileName);
    delete(movScanFileName);
    delete(cmdFileName);
    delete(bspFileName)
end
