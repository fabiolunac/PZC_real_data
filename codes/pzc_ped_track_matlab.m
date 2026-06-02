function [io_out, pedestal_vec, m_out_vec] = pzc_ped_track_matlab( ...
    snl, M_FACTOR, bt_mask, pedestal_init)

% ============================================================
% MATLAB emulation of FPGA module:
% pzc_ped_track
%
% This code tries to reproduce the RTL sequential behavior
% cycle-by-cycle.
%
% ============================================================

% ================= PARAMETERS =================

K_CORR  = 16;
PED_CORR = 32;
BT_NUM = 16;

N = length(snl);

% ================= OUTPUTS ====================

io_out       = zeros(1,N);
pedestal_vec = zeros(1,N);
m_out_vec    = zeros(1,N);

% ================= REGISTERS ==================

pedestal = pedestal_init;

out_delay = 0;

cont1 = 0;
cont2 = 0;
cont_bt = 0;

soma  = 0;
soma2 = 0;

m_out = 0;

ped_reg_out_corr = 0;

enable_acc_corr = 1;
enable_ped = 1;
enable_diverge = 1;

first_sample = 0;
diff_last = 0;

% ============================================================
% MAIN LOOP
% ============================================================

for i = 1:N

    % ========================================================
    % INPUT
    % ========================================================

    x = double(snl(i)) - pedestal;

    % ========================================================
    % FPGA OUTPUT EQUATION
    %
    % assign io_out =
    %   (in - pedestal)
    %   + out_delay
    %   + M_FACTOR*(in-pedestal)
    %
    % IMPORTANT:
    % Uses OLD out_delay
    % ========================================================

    io_out(i) = x + out_delay + M_FACTOR*x;

    % ========================================================
    % BUNCH TRAIN GAP COUNTER
    % ========================================================

    if bt_mask(i) == 0
        cont_bt = cont_bt + 1;
    else
        cont_bt = 0;
    end

    % ========================================================
    % LONG GAP REGION
    % ========================================================

    if cont_bt >= BT_NUM

        % ====================================================
        % SAVE FIRST SAMPLE
        % ====================================================

        if cont2 == 0
            first_sample = io_out(i);
        end

        % ====================================================
        % NEGATIVE VALUE ACCUMULATION
        % ====================================================

        if io_out(i) < 0

            cont1 = cont1 + 1;

            soma = soma + io_out(i);

        end

        % ====================================================
        % PEDESTAL CORRECTION ACCUMULATION
        % ====================================================

        if enable_ped

            cont2 = cont2 + 1;

            soma2 = soma2 + io_out(i);

        else

            cont2 = 0;
            soma2 = 0;

        end

        % ====================================================
        % ACCUMULATOR CORRECTION
        % ====================================================

        if enable_acc_corr

            if cont1 == K_CORR

                % Equivalent to >>> clog2(16)
                m_out = floor(soma / K_CORR);

                cont1 = 0;
                soma = 0;

                enable_ped = 0;
                enable_diverge = 0;

            else

                m_out = 0;
                enable_diverge = 1;

            end

        else

            m_out = 0;

        end

        % ====================================================
        % CHECK RAMP
        % ====================================================

        if cont2 == PED_CORR

            diff_last = io_out(i) - first_sample;

        else

            diff_last = 0;

        end

        % ====================================================
        % PEDESTAL TRACKING
        % ====================================================

        if (diff_last > PED_CORR*5) && (soma2 > 0)

            enable_acc_corr = 0;
            enable_ped = 0;
            enable_diverge = 0;

            pedestal = pedestal + 1;

            diff_last = 0;
            first_sample = 0;

            ped_reg_out_corr = floor(soma2 / PED_CORR);

        elseif (diff_last < -PED_CORR*5) && (soma2 < 0)

            enable_acc_corr = 0;
            enable_ped = 0;
            enable_diverge = 0;

            pedestal = pedestal - 1;

            diff_last = 0;
            first_sample = 0;

            ped_reg_out_corr = floor(soma2 / PED_CORR);

        else

            ped_reg_out_corr = 0;
            enable_diverge = 1;

        end

    % ========================================================
    % OUTSIDE GAP
    % ========================================================

    else

        cont1 = 0;
        cont2 = 0;

        soma = 0;
        soma2 = 0;

        m_out = 0;

        enable_acc_corr = 1;
        enable_ped = 1;
        enable_diverge = 1;

        ped_reg_out_corr = 0;

        first_sample = 0;
        diff_last = 0;

    end

    % ========================================================
    % FPGA REGISTER UPDATE
    %
    % out_delay <=
    %   (in-pedestal)
    %   + out_delay
    %   - m_out
    %   - ped_reg_out_corr;
    %
    % ========================================================

    out_delay = ...
        x + ...
        out_delay - ...
        m_out - ...
        ped_reg_out_corr;

    % ========================================================
    % SAVE DEBUG SIGNALS
    % ========================================================

    pedestal_vec(i) = pedestal;

    m_out_vec(i) = m_out;

end

% ============================================================
% REMOVE PZC GAIN
% ============================================================

io_out = io_out ./ (M_FACTOR + 1);

end