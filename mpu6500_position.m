clear; clc; close all;

if ~exist('dataset', 'dir')
    mkdir('dataset');
end

counters = containers.Map('KeyType', 'char', 'ValueType', 'double');
labels = {'triangle', 'circle', 'rectangle', 'idle'};

recordFlag = false;
recordBuffer = zeros(400, 2); 
recordIndex = 0;
currentRecordPosition = ''; 

portName = 'COM6'; 
baudRate = 115200;
s = serialport(portName, baudRate);
configureTerminator(s, "CR/LF");
flush(s);

fig = figure('Name', 'Edge AI Data Acquisition', 'Position', [100, 100, 1200, 550]);

% UI Controls
uicontrol('Style', 'text', 'Position', [20, 10, 120, 20], 'String', 'Select Shape:', 'FontSize', 10, 'FontWeight', 'bold');
hPopup = uicontrol('Style', 'popupmenu', 'Position', [140, 12, 120, 20], 'String', labels, 'FontSize', 10);
hButton = uicontrol('Style', 'pushbutton', 'Position', [280, 8, 150, 30], 'String', 'RECORD (4 Sec)', 'FontSize', 10, 'FontWeight', 'bold', ...
    'Callback', 'recordFlag = true; recordIndex = 0; set(hStatus, ''String'', ''Status: RECORDING...'', ''ForegroundColor'', ''red'');');
hStatus = uicontrol('Style', 'text', 'Position', [450, 10, 400, 20], 'String', 'Status: Waiting...', 'FontSize', 10, 'FontWeight', 'bold', 'HorizontalAlignment', 'left', 'ForegroundColor', 'blue');
hPosition = uicontrol('Style', 'text', 'Position', [850, 10, 300, 20], 'String', 'Position: Waiting...', 'FontSize', 11, 'FontWeight', 'bold', 'ForegroundColor', '[0.8 0.4 0]');

% Left Plot: 3D Orientation
subplot(1, 2, 1);
h = hgtransform; 
[x, y, z] = cylinder([0.3 0.3]); 
z = z * 0.2;
patch(surf2patch(x, y, z), 'Parent', h, 'FaceColor', [0.2 0.6 0.8], 'FaceAlpha', 0.9);
view(3); grid on; axis equal;
xlim([-1 1]); ylim([-1 1]); zlim([-1 1]);
xlabel('X Axis'); ylabel('Y Axis'); zlabel('Z Axis');
title('Spatial Orientation (3D)');

% Right Plot: Magnitude
subplot(1, 2, 2);
hLineA = animatedline('Color', 'r', 'LineWidth', 2, 'DisplayName', 'A_{mag} (Accel Norm)');
hLineG = animatedline('Color', 'b', 'LineWidth', 1.5, 'DisplayName', 'G_{mag} (Gyro Norm)');
legend('Location','northeast'); grid on;
title('Orientation-Independent Signal Magnitude');
xlabel('Time (Samples)'); ylabel('Magnitude');
ylim([0 3]); 

roll = 0; pitch = 0; yaw = 0;
dt = 0.01; 
sample_count = 0;
disp('Data stream started. Use GUI to record.');

while ishandle(fig)
    try
        str = readline(s);
        veri = sscanf(str, '%f,%f,%f,%f,%f,%f');
        if length(veri) == 6
            ax = veri(1); ay = veri(2); az = veri(3);
            gx = veri(4); gy = veri(5); gz = veri(6);
            
            a_mag = sqrt(ax^2 + ay^2 + az^2);
            g_mag_true = sqrt(gx^2 + gy^2 + gz^2); 
            g_mag_plot = g_mag_true / 100;         
            
            % Orientation Detection
            if az > 0.7
                pos_str = 'Parallel to Surface';
                pos_key = 'parallel';
            elseif az < -0.7
                pos_str = 'Upside Down';
                pos_key = 'upside_down';
            else
                pos_str = 'Vertical';
                pos_key = 'vertical';
            end
            
            set(hPosition, 'String', ['Position: ' pos_str]);
            
            % Data Recording
            if recordFlag
                if recordIndex == 0
                    currentRecordPosition = pos_key;
                end
                
                recordIndex = recordIndex + 1;
                recordBuffer(recordIndex, 1) = a_mag;
                recordBuffer(recordIndex, 2) = g_mag_true;
                
                if recordIndex == 400
                    recordFlag = false; 
                    
                    selected_idx = get(hPopup, 'Value');
                    shapeName = labels{selected_idx};
                    
                    fileKey = sprintf('%s_%s', shapeName, currentRecordPosition);
                    
                    if isKey(counters, fileKey)
                        counter = counters(fileKey);
                    else
                        counter = 1;
                    end
                    
                    filename = sprintf('dataset/%s_%d.csv', fileKey, counter);
                    counters(fileKey) = counter + 1;
                    
                    fid = fopen(filename, 'w');
                    fprintf(fid, 'A_mag,G_mag\n');
                    for i = 1:400
                        fprintf(fid, '%.4f,%.4f\n', recordBuffer(i, 1), recordBuffer(i, 2));
                    end
                    fclose(fid);
                    
                    set(hStatus, 'String', sprintf('Status: SAVED! (%s)', filename), 'ForegroundColor', '[0 0.5 0]');
                    disp(['Successfully saved: ' filename]);
                end
            end
            
            % 3D Visualization Filter
            roll_acc = atan2(ay, az);
            pitch_acc = atan2(-ax, sqrt(ay^2 + az^2));
            roll = 0.98 * (roll - gx * 0.0174 * dt) + 0.02 * roll_acc;
            pitch = 0.98 * (pitch - gy * 0.0174 * dt) + 0.02 * pitch_acc;
            yaw = yaw + gz * 0.0174 * dt; 
            Rx = makehgtform('xrotate', roll);
            Ry = makehgtform('yrotate', pitch);
            Rz = makehgtform('zrotate', yaw);
            set(h, 'Matrix', Rz * Ry * Rx);
            
            sample_count = sample_count + 1;
            addpoints(hLineA, sample_count, a_mag);
            addpoints(hLineG, sample_count, g_mag_plot);
            
            if sample_count > 400
                xlim(gca, [sample_count - 400, sample_count]);
            end
            drawnow limitrate; 
        end
    catch
    end
end
clear s;
disp('Connection closed.');