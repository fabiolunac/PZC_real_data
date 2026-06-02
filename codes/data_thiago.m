clear all
close all

% Initial conditions
repetition = 200; % Number of repetition of data
name = "ATLAS_run520451_MD4_CH0_iter9.mat" % Name of the real data file to be loaded
%name = "ATLAS_run520451_MD4_CH2_iter9.mat" % Name of the real data file to be loaded
M_Factor = 454; % PZC Factor
pedestal_first_guess = 0; % Used to help pzc track the pedestal faster. It can be set as 0 w/o problem


% Loading the Bunch Train Pattern
load("bunch_train_520451.mat");
load("bunch_train.mat");

% Loading input data
load(name);

% Adjusting the data to match to the long gap region (it is different for
% every dataset provided by Fernando)
hg_adjusted = double(hg(3209-30:13900-30));

% Ajusting the bunch train pattern to match to data 
bt_520451_mask_rot = [bt_520451_mask(64:end);bt_520451_mask(1:63)];
bt_mask = bt_520451_mask';
%bt_mask = [bunch_pat,0];


% Extending the data output and the bunch train mask to test pzc pedestal
% tracking
hg_extended = repmat(hg_adjusted, 1, repetition);
bt_mask_extended = repmat(bt_mask, 1, repetition*3);

% Applying the PZC
[pzc_out,pedestal_vec,mean] = pzc_ped_track_matlab(hg_extended,M_Factor,bt_mask_extended,pedestal_first_guess);
pzc_out = fix(pzc_out);

% Plotting the data and pzc
plot(pzc_out); hold on; plot(hg_extended); plot(bcr*500); plot(pedestal_vec); hold off; legend('SINAL PZC','SINAL REAL','COMPENSAÇÃO DO PEDESTAL');

% Plotting the histogram

figure; hist(pzc_out(10^5:end), 273); hold on; hist(hg_extended(10^5:end), 275); hold off; xlim([-20,300])


% Plotting the data and pzc
figure; hold on; plot(hg); stem(bcr*500);  hold off; legend('HG OUT','BCR');


% Plotting the histogram

figure; hist(pzc_out(10^5:end)-1, 273); hold on; hist(hg_extended(10^5:end)-148, 275); hold off; xlim([-20,300])



edges = -20:1:300;

figure;
histogram(pzc_out(1e5:end)-2, edges, ...
    'FaceColor', [1.0 0.5 0.0], ...
    'FaceAlpha', 0.5);

hold on;

histogram(hg_extended(1e5:end)-148, edges, ...
    'FaceColor', [0.0 0.45 0.74], ...
    'FaceAlpha', 0.5);

xlim([-20,300]);
legend('pzc\_out','hg\_extended-148');



edges = -20:1:300;

figure;
histogram(pzc_out(1e5:end), edges, ...
    'FaceColor', [1.0 0.5 0.0], ...
    'FaceAlpha', 0.5);

hold on;

histogram(hg_extended(1e5:end), edges, ...
    'FaceColor', [0.0 0.45 0.74], ...
    'FaceAlpha', 0.5);

xlim([-20,300]);
legend('pzc\_out-2','hg\_extended');