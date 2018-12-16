function [status, exception] = start_nback(app, part, run)
% Copyright (C) 2018, Liang Zhang - All Rights Reserved.
% @author      Liang Zhang <psychelzh@outlook.com>
% @description This script is used to display stimuli in fMRI research
%              based on one-back paradigm, using Psychtoolbox as devtool.

% please mannually make sure Psychtoolbox is installed

% ---- check input arguments ----
% default to start practice part
if nargin < 2
    part = 'prac';
end
% default to use the first run
if nargin < 3
    run = 1;
end

% ---- set default output ----
status = 0;
exception = [];

% ---- prepare sequences ----
config = app.init_config(part);
run_active = config.runs(run);
num_trials_total = sum(cellfun(@length, {run_active.blocks.trials}));

% ----prepare data recording table ----
rec_vars = {'block', 'trial', 'stim', 'trial_start_time', 'stim_onset_time', 'stim_offset_time', 'type', 'cresp', 'resp', 'acc', 'rt'};
rec_dflt = {nan, nan, nan, nan, nan, nan, strings, strings, strings, -1, 0};
recordings = cell2table( ...
    repmat(rec_dflt, num_trials_total, 1), ...
    'VariableNames', rec_vars);

% ---- configure screen and window ----
% setup default level of 2
PsychDefaultSetup(2);
PsychDebugWindowConfiguration
% screen selection
screen_to_display = max(Screen('Screens'));
% set the start up screen to black
old_visdb = Screen('Preference', 'VisualDebugLevel', 1);
% do not skip synchronization test to make sure timing is accurate
old_sync = Screen('Preference', 'SkipSyncTests', 0);
% set priority to the top
old_pri = Priority(MaxPriority(screen_to_display));
% open a window and set its background color as gray
gray = WhiteIndex(screen_to_display) / 2;

try % error proof programming
    % ---- open window ----
    [window_ptr, window_rect] = PsychImaging('OpenWindow', screen_to_display, gray);
    [window_center_x, window_center_y] = RectCenter(window_rect);
    % disable character input and hide mouse cursor
    ListenChar(2);
    HideCursor;
    % set blending function
    Screen('BlendFunction', window_ptr, GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    % set default font name and size
    Screen('TextFont', window_ptr, 'SimHei');
    Screen('TextSize', window_ptr, 128);
    
    % ---- timing information ----
    % get inter flip interval
    ifi = Screen('GetFlipInterval', window_ptr);
    % task cue duration
    taskcue_secs = 4;
    taskcue_frames = round(taskcue_secs / ifi);
    % prestimulus fixation
    fix_secs = 0.5;
    fix_frames = round(fix_secs / ifi);
    % image presentation seconds
    image_secs = 1;
    image_frames = round(image_secs / ifi);
    % interstimulus interval seconds (participants' response is recorded)
    isi_secs = 1;
    isi_frames = round(isi_secs / ifi);
    % make a vector to store the content to show at each frame
    pres_vector = [repelem("fixation", fix_frames), ...
        repelem("stimulus", image_frames), ...
        repelem("isi", isi_frames)];
    n_frames_trial = length(pres_vector);
    
    % ---- keyboard settings ----
    start_key = KbName('s');
    exit_key = KbName('Escape');
    left_key = KbName('1!');
    right_key = KbName('4$');
    
    % ---- present stimuli ----
    % instruction
    instruction = ['下面我们玩一个游戏', ...
        '\n屏幕上会一个一个地出现数字'];
    DrawFormattedText(window_ptr, double(instruction), 'center', 'center', [0, 0, 1]);
    Screen('Flip', window_ptr);
    while true
        [~, resp_time, resp_code] = KbCheck(-1);
        if resp_code(start_key)
            start_time = resp_time;
            break
        end
    end
    % start stimuli presentation
    early_exit = false;
    % first loop through blocks
    for block = run_active.blocks
        % instruction for practice
        if strcmp(part, 'prac')
            switch block.name
                case "zero-back"
                    instruction_block = ['接下来你会先看到''back0''这样的符号', ...
                        '\n然后你需要判断后面出现的数字是不是偶数', ...
                        '\n如果是就按1，不是就按4'];
                case "one-back"
                    instruction_block = ['接下来你会先看到''back1''这样的符号', ...
                        '\n之后需要判断每次出现的数字是否跟前一个一样', ...
                        '\n如果一样就按1，不一样就按4'];
                case "two-back"
                    instruction_block = ['接下来你会先看到''back2''这样的符号', ...
                        '\n之后需要判断每次出现的数字是否跟倒数第二个数字一样', ...
                        '\n如果一样就按1，不一样就按4'];
            end
            DrawFormattedText(window_ptr, ...
                double(instruction_block), 'center', 'center', [0, 0, 1]);
            Screen('Flip', window_ptr);
            KbStrokeWait;
        end
        % task cue presentation
        for taskcue_frame = 1:taskcue_frames
            Screen('DrawText', window_ptr, double(block.disp_name), ...
                window_center_x, window_center_y, [0, 1, 0]);
            Screen('Flip', window_ptr);
            [~, ~, resp_code] = KbCheck(-1);
            if resp_code(exit_key)
                early_exit = true;
                break
            end
        end
        if early_exit
            break
        end
        % then loop through trials
        for trial = block.trials
            % initialize before presenting
            resp_made = false;
            frame_to_draw = 0;
            trial_start_time = nan;
            stim_onset_time = nan;
            stim_offset_time = nan;
            % stimulus presentation loop
            while frame_to_draw < n_frames_trial
                frame_to_draw = frame_to_draw + 1;
                % draw the corresponding content according to the vectors
                draw_what = pres_vector(frame_to_draw);
                switch draw_what
                    case "fixation"
                        Screen('DrawText', window_ptr, '+', ...
                            window_center_x, window_center_y, BlackIndex(window_ptr));
                    case "stimulus"
                        Screen('DrawText', window_ptr, num2str(trial.stim), ...
                                window_center_x, window_center_y, BlackIndex(window_ptr));
                    case "isi"
                        Screen('FillRect', window_ptr, gray);
                end
                if frame_to_draw == 1
                    vbl = Screen('Flip', window_ptr);
                    trial_start_time = vbl - start_time;
                else
                    % record the stimulus offset time
                    if draw_what == "isi" && isnan(stim_offset_time)
                        stim_offset_time = vbl - start_time;
                    end
                    vbl = Screen('Flip', window_ptr, vbl + 0.5 * ifi);
                    % record the stimulus onset time
                    if draw_what == "stimulus" && isnan(stim_onset_time)
                        stim_onset_time = vbl - start_time;
                    end
                end
                % check response
                [~, resp_time, resp_code] = KbCheck(-1);
                % if pressing exit key ('Esc' key)
                if resp_code(exit_key)
                    early_exit = true;
                    break
                end
                if draw_what ~= "fixation" && trial.type ~= "filler"
                    if resp_code(left_key) || resp_code(right_key)
                        resp_made = true;
                        resp_rt = resp_time - stim_onset_time - start_time;
                        if resp_code(left_key)
                            resp = "Left";
                        else
                            resp = "Right";
                        end
                        resp_acc = double(resp == trial.cresp);
                    end
                end
            end
            % if no response is made, store acc as -1 and rt as 0
            if ~resp_made
                resp = "";
                resp_acc = -1;
                resp_rt = 0;
            end
            if early_exit
                break
            end
            % if practice, give feedback
            if strcmp(part, 'prac') && trial.type ~= "filler"
                switch resp_acc
                    case -1
                        DrawFormattedText(window_ptr, double('请及时作答'), 'center', 'center', [1, 1, 1]);
                    case 0
                        DrawFormattedText(window_ptr, double('错了\n不要灰心'), 'center', 'center', [1, 0, 0]);
                    case 1
                        DrawFormattedText(window_ptr, double('对了\n真棒'), 'center', 'center', [0, 1, 0]);
                end
                Screen('Flip', window_ptr);
                WaitSecs(1);
            end
            % recording current response data
            trial_order = (block.id - 1) * app.NumberTrialsPerBlock + trial.id;
            recordings.block(trial_order) = block.id;
            recordings.trial(trial_order) = trial.id;
            recordings.stim(trial_order) = trial.stim;
            recordings.trial_start_time(trial_order) = trial_start_time;
            recordings.stim_onset_time(trial_order) = stim_onset_time;
            recordings.type(trial_order) = trial.type;
            recordings.cresp(trial_order) = trial.cresp;
            recordings.resp(trial_order) = resp;
            recordings.acc(trial_order) = resp_acc;
            recordings.rt(trial_order) = resp_rt;
        end
        if early_exit
            break
        end
    end
    % goodbye
    goodbye = ['已完成测验', ...
        '\n非常感谢您的配合！', ...
        '\n', ...
        '\n按任意键退出'];
    DrawFormattedText(window_ptr, double(goodbye), 'center', 'center', [0, 0, 1]);
    Screen('Flip', window_ptr);
    KbStrokeWait;
catch exception
    status = 1;
end
% clear jobs
Screen('Close');
sca;
% enable character input and show mouse cursor
ListenChar(1);
ShowCursor;
% restore preferences
if exist('old_visdb', 'var')
    Screen('Preference', 'VisualDebugLevel', old_visdb);
end
if exist('old_sync', 'var')
    Screen('Preference', 'SkipSyncTests', old_sync);
end
if exist('old_pri', 'var')
    Priority(old_pri);
end
% save recorded data
switch part
    case 'prac'
        data_store_name = sprintf('%s_rep%d', part, app.UserPracticedTimes);
    case 'test'
        data_store_name = sprintf('%s_run%d', part, run);
end
S.(data_store_name).config = config;
S.(data_store_name).recordings = recordings;
save(fullfile(app.LogFilePath, app.LogFileName), ...
    '-struct', 'S', '-append')
end
