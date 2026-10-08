function [out_data, stats] = diffusion_engine(in_data, session_key, mode, hw_config)
% DIFFUSION_ENGINE - Dual-Mode Chaotic CBC Diffusion Engine (HIL + Software)
%
% Implements forward and backward Cipher Block Chaining (CBC) diffusion
% coupled with the 4D Memristive Hyperchaotic System (M-4DCHS).
%
% Modes:
%   'encrypt' - Forward CBC Diffusion: C(i) = P(i) ^ K(i) ^ C(i-1)
%   'decrypt' - Inverse CBC Diffusion: P(i) = C(i) ^ K(i) ^ C(i-1)
%
% Hardware-in-the-Loop (HIL):
%   Bi-directional streaming with STM32G474RE Nucleo over UART (921,600 baud):
%   - Bit 31 of payload size = 0: Forward Encryption
%   - Bit 31 of payload size = 1: Inverse Decryption
%   Automatic zero-downtime fallback to native high-speed software engine.
%
% Author: Yash (OIST Research Portfolio)

    if nargin < 3 || isempty(mode)
        mode = 'encrypt';
    end
    if nargin < 4 || isempty(hw_config)
        hw_config.use_hardware = false;
        hw_config.com_port = 'COM10';
        hw_config.baud_rate = 921600;
    end

    [H, W, C] = size(in_data);
    total_bytes = H * W * C;
    line_bytes = W * C;

    out_data = zeros(H, W, C, 'uint8');
    stats.mode = mode;
    stats.hardware_active = false;
    stats.total_bytes = total_bytes;

    % Initial Vector (IV) for CBC diffusion
    IV = uint8(hex2dec('5A'));

    % Check hardware availability if requested
    s_obj = [];
    if hw_config.use_hardware
        try
            existing = serialportfind("Port", hw_config.com_port);
            if ~isempty(existing)
                delete(existing);
            end
            s_obj = serialport(hw_config.com_port, hw_config.baud_rate, "Timeout", 2.0);
            flush(s_obj);
            pause(0.15);
            stats.hardware_active = true;
            fprintf('   [HIL] Hardware link established on %s @ %d baud (Mode: %s).\n', ...
                    hw_config.com_port, hw_config.baud_rate, upper(mode));
        catch ME
            fprintf('   [HIL] Hardware offline (%s). Using high-speed software engine.\n', ME.message);
            stats.hardware_active = false;
        end
    end

    t_start = tic;

    if strcmpi(mode, 'encrypt')
        % ==================== FORWARD DIFFUSION (ENCRYPT) ====================
        for line_idx = 1:H
            if C == 1
                plain_line = in_data(line_idx, :);
            else
                slice = squeeze(in_data(line_idx, :, :));
                plain_line = reshape(slice', 1, line_bytes);
            end
            plain_line = uint8(plain_line(:));

            k_line = single(mod(session_key + double(line_idx - 1) * 0.001, 1.0));

            if stats.hardware_active
                try
                    % Header: 'M4DC' + line_bytes (bit 31 = 0) + k_line
                    header = [uint8(['M', '4', 'D', 'C']), ...
                              typecast(uint32(line_bytes), 'uint8'), ...
                              typecast(k_line, 'uint8')];
                    write(s_obj, header, "uint8");
                    ack = read(s_obj, 2, "uint8");
                    if length(ack) == 2 && isequal(char(ack), 'OK')
                        write(s_obj, plain_line, "uint8");
                        enc_line = uint8(read(s_obj, line_bytes, "uint8"));
                        if length(enc_line) ~= line_bytes
                            error('Truncated payload from STM32');
                        end
                    else
                        error('STM32 handshake mismatch');
                    end
                catch
                    stats.hardware_active = false;
                    enc_line = software_diffuse_scanline(plain_line, k_line, IV);
                end
            else
                enc_line = software_diffuse_scanline(plain_line, k_line, IV);
            end

            if C == 1
                out_data(line_idx, :) = enc_line;
            else
                out_slice = reshape(enc_line, [C, W])';
                out_data(line_idx, :, :) = out_slice;
            end
        end

    elseif strcmpi(mode, 'decrypt')
        % ==================== INVERSE DIFFUSION (DECRYPT) ====================
        for line_idx = 1:H
            if C == 1
                enc_line = in_data(line_idx, :);
            else
                slice = squeeze(in_data(line_idx, :, :));
                enc_line = reshape(slice', 1, line_bytes);
            end
            enc_line = uint8(enc_line(:));

            k_line = single(mod(session_key + double(line_idx - 1) * 0.001, 1.0));

            if stats.hardware_active
                try
                    % Header: 'M4DC' + line_bytes with bit 31 set (Decryption command) + k_line
                    dec_cmd = bitor(uint32(line_bytes), uint32(hex2dec('80000000')));
                    header = [uint8(['M', '4', 'D', 'C']), ...
                              typecast(dec_cmd, 'uint8'), ...
                              typecast(k_line, 'uint8')];
                    write(s_obj, header, "uint8");
                    ack = read(s_obj, 2, "uint8");
                    if length(ack) == 2 && isequal(char(ack), 'OK')
                        write(s_obj, enc_line, "uint8");
                        dec_line = uint8(read(s_obj, line_bytes, "uint8"));
                        if length(dec_line) ~= line_bytes
                            error('Truncated payload from STM32');
                        end
                    else
                        error('STM32 handshake mismatch');
                    end
                catch
                    stats.hardware_active = false;
                    dec_line = software_decrypt_scanline(enc_line, k_line, IV);
                end
            else
                dec_line = software_decrypt_scanline(enc_line, k_line, IV);
            end

            if C == 1
                out_data(line_idx, :) = dec_line;
            else
                out_slice = reshape(dec_line, [C, W])';
                out_data(line_idx, :, :) = out_slice;
            end
        end
    else
        error('Invalid mode: %s. Use ''encrypt'' or ''decrypt''.', mode);
    end

    if ~isempty(s_obj)
        delete(s_obj);
    end

    stats.elapsed_sec = toc(t_start);
    stats.throughput_mbps = (double(total_bytes) / max(1e-6, stats.elapsed_sec)) / 1e6;
end

function enc_line = software_diffuse_scanline(plain_line, k_line, iv)
    num_pts = length(plain_line);
    [ks, ~] = m4dchs_engine(k_line, num_pts, 500);
    enc_line = zeros(num_pts, 1, 'uint8');
    curr_prev = iv;

    for i = 1:num_pts
        c = bitxor(bitxor(plain_line(i), ks(i)), curr_prev);
        enc_line(i) = c;
        curr_prev = c;
    end
end

function dec_line = software_decrypt_scanline(enc_line, k_line, iv)
    num_pts = length(enc_line);
    [ks, ~] = m4dchs_engine(k_line, num_pts, 500);
    prev_vec = [iv; enc_line(1:end-1)];
    dec_line = bitxor(bitxor(enc_line, ks), prev_vec);
end
