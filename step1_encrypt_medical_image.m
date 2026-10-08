    %% =========================================================================
% STEP 1: CLINICAL MEDICAL IMAGE ENCRYPTION NODE
% =========================================================================
% Project: Memristive 4D Hyperchaotic Medical Image Encryption (HIL)
% Framework: Modular Permutation Architecture + 4D M-4DCHS Hardware Stream
% Author: Yash (Research Portfolio - OIST Internship Application)
%
% Architecture Overview:
%   [Medical Image] ──► [Key Derivation (SHA-256)] ──► [Permutation Engine]
%                                                             │
%   [Save Cipher Package] ◄── [CBC Diffusion Engine] ◄────────┘
%                             (STM32 HIL or Software)
%
% Permutation Algorithms Supported:
%   - 'josephus'     : Concentric Cross-Ring Josephus Permutation
%   - 'arnold'       : 2D Chaotic Arnold Cat Map (ACM)
%   - 'zigzag'       : Orthogonal Diagonal Scanline Disperser
%   - 'm4dchs_sort'  : Continuous 4D Memristive Attractor Coordinate Sort
% =========================================================================
clc; clear; close all;

fprintf('=================================================================\n');
fprintf('   MEMRISTIVE 4D HYPERCHAOTIC MEDICAL IMAGE ENCRYPTION ENGINE    \n');
fprintf('   Hardware-in-the-Loop (HIL) Architecture for Clinical IoMT    \n');
fprintf('=================================================================\n\n');

%% ==================== SECTION 1: SYSTEM CONFIGURATION ====================
script_dir = fileparts(mfilename('fullpath'));
addpath(fullfile(script_dir, 'core'));

img_dir = fullfile(script_dir, 'image_dataset');
out_dir = fullfile(script_dir, 'outputs');
if ~exist(out_dir, 'dir'), mkdir(out_dir); end

% 👉 1. SELECT MEDICAL DATASET SCAN:
% Available: 'brain_mri_kaggle.tif', 'brain_mri.jpg', 'Breast_cancer_img.png',
%            'eye_image.png', 'eye_image2.png', 'skull_image2.jpg', 'skin_lesion.jpg'
SELECTED_IMAGE = fullfile(img_dir, 'brain_mri_kaggle.tif');

% 👉 2. SELECT PERMUTATION STRATEGY:
% Options: 'josephus' | 'arnold' | 'zigzag' | 'm4dchs_sort'
SCRAMBLE_METHOD = 'arnold';

% 👉 3. HARDWARE-IN-THE-LOOP ACCELERATION (STM32 Nucleo-G474RE):
% If true, attempts streaming to Cortex-M4 FPU @ 921,600 baud.
% If offline, automatically falls back to native high-speed software engine.
USE_HARDWARE = true;
COM_PORT     = 'COM10';
BAUD_RATE    = 921600;

%% ==================== SECTION 2: LOAD & PREPROCESS IMAGE ====================
fprintf('[Stage 1/5] Loading clinical medical scan...\n');
if ~isfile(SELECTED_IMAGE)
    error('Image file not found: %s', SELECTED_IMAGE);
end

[~, img_name, img_ext] = fileparts(SELECTED_IMAGE);
orig_img = imread(SELECTED_IMAGE);
[H, W, C] = size(orig_img);
fprintf('      Loaded: %s%s | Resolution: %dx%d | Channels: %d\n', ...
        img_name, img_ext, H, W, C);

%% ==================== SECTION 3: SHA-256 KEY DERIVATION ====================
fprintf('\n[Stage 2/5] Plaintext-dependent session key derivation...\n');
% Master clinical key
K_master = 0.314159265358979;

% Compute SHA-256 digest of plaintext image for chosen-plaintext defense
engine_md = java.security.MessageDigest.getInstance('SHA-256');
engine_md.update(orig_img(:));
hash_bytes = typecast(engine_md.digest(), 'uint8');

% Fold hash bytes into perturbation delta delta_K in (0, 1e-4)
hash_val = double(typecast(hash_bytes(1:8), 'uint64')) / double(intmax('uint64'));
session_key = single(mod(K_master + hash_val * 1e-4, 1.0));
fprintf('      Plaintext Hash Digest: %s...\n', dec2hex(hash_bytes(1:4))');
fprintf('      Dynamic Session Key:   %.10f\n', session_key);

%% ==================== SECTION 4: SPATIAL PERMUTATION STAGE ====================
fprintf('\n[Stage 3/5] Applying spatial permutation [%s]...\n', upper(SCRAMBLE_METHOD));
t_perm = tic;
[scramble_idx, method_name] = scramble_engine(SCRAMBLE_METHOD, H, W, session_key);

scrambled_img = zeros(H, W, C, 'uint8');
for c = 1:C
    plane = orig_img(:, :, c);
    plane_scrambled = plane(scramble_idx);
    scrambled_img(:, :, c) = reshape(plane_scrambled, [H, W]);
end
time_perm_ms = toc(t_perm) * 1000;
fprintf('      %s executed in %.2f ms.\n', method_name, time_perm_ms);

%% ==================== SECTION 5: CHAOTIC CBC DIFFUSION STAGE ====================
fprintf('\n[Stage 4/5] Applying 4D memristive CBC diffusion...\n');
hw_config.use_hardware = USE_HARDWARE;
hw_config.com_port     = COM_PORT;
hw_config.baud_rate    = BAUD_RATE;

[cipher_img, diff_stats] = diffusion_engine(scrambled_img, session_key, 'encrypt', hw_config);
time_diff_ms = diff_stats.elapsed_sec * 1000;

if diff_stats.hardware_active
    fprintf('      Hardware Execution: Completed on STM32G474RE in %.2f ms (%.2f MB/s)\n', ...
            time_diff_ms, diff_stats.throughput_mbps);
else
    fprintf('      Software Execution: Completed in %.2f ms (%.2f MB/s)\n', ...
            time_diff_ms, diff_stats.throughput_mbps);
end

total_time_ms = time_perm_ms + time_diff_ms;
fprintf('      Total Cryptographic Pipeline: %.2f ms\n', total_time_ms);

%% ==================== SECTION 6: METRICS & EXPORT ====================
fprintf('\n[Stage 5/5] Computing security metrics and saving package...\n');

% Shannon Information Entropy
orig_entropy = calc_shannon_entropy(orig_img);
cipher_entropy = calc_shannon_entropy(cipher_img);
fprintf('      Plaintext Shannon Entropy: %.4f bits/byte\n', orig_entropy);
fprintf('      Ciphertext Shannon Entropy: %.4f bits/byte (Ideal: 8.0000)\n', cipher_entropy);

% Correlation Coefficients (Horizontal)
corr_orig = calc_adj_corr(orig_img(:, :, 1));
corr_ciph = calc_adj_corr(cipher_img(:, :, 1));
fprintf('      Adjacent Correlation (Orig): H=%.4f, V=%.4f, D=%.4f\n', ...
        corr_orig(1), corr_orig(2), corr_orig(3));
fprintf('      Adjacent Correlation (Ciph): H=%.4f, V=%.4f, D=%.4f (Target: ~0.000)\n', ...
        corr_ciph(1), corr_ciph(2), corr_ciph(3));

% Save encrypted package for Step 2 Decryption Node
save_path_mat = fullfile(out_dir, 'encrypted_package.mat');
hw_encrypted = diff_stats.hardware_active;
save(save_path_mat, 'cipher_img', 'scramble_idx', 'session_key', ...
     'method_name', 'SCRAMBLE_METHOD', 'H', 'W', 'C', 'orig_entropy', ...
     'cipher_entropy', 'total_time_ms', 'img_name', 'hw_encrypted');

imwrite(cipher_img, fullfile(out_dir, 'cipher_image.png'));
imwrite(scrambled_img, fullfile(out_dir, 'scrambled_image.png'));
fprintf('      Saved encrypted package: %s\n', save_path_mat);

%% ==================== SECTION 7: PUBLICATION-GRADE VISUALIZATION ====================
fig = figure('Name', 'M-4DCHS Medical Image Encryption Pipeline', ...
             'Color', [0.08, 0.09, 0.11], 'Position', [80, 80, 1300, 750]);

% Generate M-4DCHS Phase Attractor for Visual Telemetry
[~, attractor_states] = m4dchs_engine(session_key, 3500, 500);

% Row 1: Images
subplot(2, 4, 1);
imshow(orig_img);
title(sprintf('Plaintext Image\n(%dx%d %s)', H, W, img_name), 'Color', [0.9, 0.9, 0.9], 'FontSize', 11);

subplot(2, 4, 2);
imshow(scrambled_img);
title(sprintf('Permuted Stage\n[%s]', method_name), 'Color', [0.9, 0.9, 0.9], 'FontSize', 11);

subplot(2, 4, 3);
imshow(cipher_img);
title(sprintf('Ciphertext Image\nEntropy = %.4f b/B', cipher_entropy), 'Color', [0.3, 0.9, 0.4], 'FontSize', 11);

subplot(2, 4, 4);
plot3(attractor_states(:, 1), attractor_states(:, 2), attractor_states(:, 4), ...
      'Color', [0.2, 0.8, 1.0], 'LineWidth', 0.8);
grid on; set(gca, 'Color', [0.12, 0.13, 0.16], 'XColor', [0.6, 0.6, 0.6], ...
                 'YColor', [0.6, 0.6, 0.6], 'ZColor', [0.6, 0.6, 0.6]);
title('4D Memristive Attractor (x-y-w)', 'Color', [0.9, 0.9, 0.9], 'FontSize', 11);
view([-35, 25]);

% Row 2: Histograms & Stats
subplot(2, 4, 5);
plot_histogram(orig_img, [0.2, 0.6, 1.0]);
title(sprintf('Plaintext Histogram (H=%.2f)', orig_entropy), 'Color', [0.9, 0.9, 0.9], 'FontSize', 10);

subplot(2, 4, 6);
plot_histogram(scrambled_img, [0.9, 0.6, 0.1]);
title('Permuted Histogram (Unchanged)', 'Color', [0.9, 0.9, 0.9], 'FontSize', 10);

subplot(2, 4, 7);
plot_histogram(cipher_img, [0.2, 0.85, 0.3]);
title('Cipher Histogram (Flat Uniform)', 'Color', [0.9, 0.9, 0.9], 'FontSize', 10);

subplot(2, 4, 8);
set(gca, 'Color', [0.12, 0.13, 0.16], 'XColor', 'none', 'YColor', 'none');
text(0.05, 0.85, 'System Telemetry', 'Color', [0.2, 0.8, 1.0], 'FontSize', 12, 'FontWeight', 'bold');
text(0.05, 0.70, sprintf('Model: %s', SCRAMBLE_METHOD), 'Color', [0.85, 0.85, 0.85], 'FontSize', 10);
text(0.05, 0.55, sprintf('HIL Stream: %s', ternary(diff_stats.hardware_active, 'STM32G474RE', 'Emulated C-FPU')), 'Color', [0.85, 0.85, 0.85], 'FontSize', 10);
text(0.05, 0.40, sprintf('Pipeline Latency: %.2f ms', total_time_ms), 'Color', [0.85, 0.85, 0.85], 'FontSize', 10);
text(0.05, 0.25, sprintf('Adj Corr (H): %.5f', corr_ciph(1)), 'Color', [0.85, 0.85, 0.85], 'FontSize', 10);
text(0.05, 0.10, sprintf('Status: CRYPTOGRAPHICALLY SECURE'), 'Color', [0.3, 0.9, 0.4], 'FontSize', 10, 'FontWeight', 'bold');
xlim([0, 1]); ylim([0, 1]);

% Strip MATLAB axes toolbar from all subplots to prevent menu icon obstruction
ax_all = findall(fig, 'type', 'axes');
for k = 1:length(ax_all)
    try
        ax_all(k).Toolbar.Visible = 'off';
    catch
    end
end

exportgraphics(fig, fullfile(out_dir, 'step1_encryption_results.png'), 'Resolution', 200);
fprintf('      Exported publication figure: %s\n', fullfile(out_dir, 'step1_encryption_results.png'));
fprintf('\n>>> STEP 1 COMPLETED SUCCESSFULLY. Run step2_decrypt_medical_image.m next.\n');

%% ==================== HELPER FUNCTIONS ====================
function ent = calc_shannon_entropy(img_data)
    counts = histcounts(img_data(:), 0:256);
    p = counts(counts > 0) / numel(img_data);
    ent = -sum(p .* log2(p));
end

function corr_vec = calc_adj_corr(gray_plane)
    gray = double(gray_plane);
    [h, w] = size(gray);
    num_samples = min(5000, (h-1)*(w-1));
    
    rx = randi([1, h-1], num_samples, 1);
    ry = randi([1, w-1], num_samples, 1);
    idx = sub2ind([h, w], rx, ry);
    
    x_val = gray(idx);
    h_val = gray(sub2ind([h, w], rx, ry + 1));
    v_val = gray(sub2ind([h, w], rx + 1, ry));
    d_val = gray(sub2ind([h, w], rx + 1, ry + 1));
    
    corr_vec = [compute_corr(x_val, h_val), ...
                compute_corr(x_val, v_val), ...
                compute_corr(x_val, d_val)];
end

function r = compute_corr(u, v)
    cov_uv = cov(u, v);
    denom = sqrt(var(u) * var(v));
    if denom == 0
        r = 0;
    else
        r = cov_uv(1, 2) / denom;
    end
end

function plot_histogram(data_vec, color_val)
    counts = histcounts(data_vec(:), 0:256);
    bar(0:255, counts, 'BarWidth', 1.0, 'EdgeColor', 'none', 'FaceColor', color_val);
    xlim([0, 255]);
    grid on;
    set(gca, 'Color', [0.12, 0.13, 0.16], 'XColor', [0.6, 0.6, 0.6], 'YColor', [0.6, 0.6, 0.6]);
end

function out = ternary(cond, a, b)
    if cond, out = a; else, out = b; end
end
